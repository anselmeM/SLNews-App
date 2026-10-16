import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sync/local_sync_ledger.dart';
import '../domain/models/article.dart';
import '../domain/models/follow_models.dart';
import '../domain/sync/sync_repository.dart';
import 'app_providers.dart';
import 'auth_providers.dart';
import 'controllers.dart';
import 'sync_repository_provider.dart';

/// What the account surface shows about syncing.
enum SyncPhase {
  /// This build has no sync endpoint (`SLNEWS_SYNC_URL` empty).
  disabled,

  /// Configured and signed out, or idle between runs.
  idle,

  syncing,
  synced,

  /// The last run failed; [SyncStatus.failure] says why.
  failed,
}

/// Observable outcome of the last sync run.
@immutable
class SyncStatus {
  /// Creates a status.
  const SyncStatus({
    this.phase = SyncPhase.disabled,
    this.lastSyncedAt,
    this.applied = SyncApplied.none,
    this.rejected = 0,
    this.failure,
  });

  final SyncPhase phase;

  /// Server clock at the last successful run, when known.
  final DateTime? lastSyncedAt;

  /// Rows the server applied in the last push.
  final SyncApplied applied;

  /// Rows the server refused as stale in the last push (not an error).
  final int rejected;

  final SyncFailure? failure;

  /// True while a run is in flight.
  bool get isBusy => phase == SyncPhase.syncing;

  /// One-line description for the account card.
  String get label => switch (phase) {
    SyncPhase.disabled => 'Sync unavailable in this build',
    SyncPhase.idle => 'Signed in — not synced yet',
    SyncPhase.syncing => 'Syncing…',
    SyncPhase.synced => 'Synced ${_relative(lastSyncedAt)}',
    SyncPhase.failed => 'Sync failed — ${failure?.kind ?? 'unknown'}',
  };

  static String _relative(DateTime? at) {
    if (at == null) return 'just now';
    final Duration delta = DateTime.now().toUtc().difference(at.toUtc());
    if (delta.inMinutes < 1) return 'just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    return '${delta.inDays}d ago';
  }

  /// Copy with the given fields replaced.
  SyncStatus copyWith({
    SyncPhase? phase,
    DateTime? lastSyncedAt,
    SyncApplied? applied,
    int? rejected,
    SyncFailure? failure,
    bool clearFailure = false,
  }) => SyncStatus(
    phase: phase ?? this.phase,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    applied: applied ?? this.applied,
    rejected: rejected ?? this.rejected,
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

/// Change-time ledger backing last-write-wins.
final Provider<LocalSyncLedger> syncLedgerProvider = Provider<LocalSyncLedger>(
  (Ref ref) => LocalSyncLedger(ref.watch(preferencesStoreProvider)),
  name: 'syncLedger',
);

/// Coordinates the reader's local state with the mobile sync API.
final NotifierProvider<SyncController, SyncStatus> syncControllerProvider =
    NotifierProvider<SyncController, SyncStatus>(
      SyncController.new,
      name: 'syncController',
    );

/// Push coalescing window: a reader tapping "save" on three stories should make
/// one request, not three.
const Duration syncPushDebounce = Duration(seconds: 3);

class SyncController extends Notifier<SyncStatus> {
  Timer? _debounce;
  DateTime? _lastPushedAt;

  @override
  SyncStatus build() {
    ref.onDispose(() => _debounce?.cancel());
    final SyncRepository repository = ref.watch(syncRepositoryProvider);
    return SyncStatus(
      phase: repository.isConfigured ? SyncPhase.idle : SyncPhase.disabled,
    );
  }

  /// Merge-on-first-sign-in: push what is here, pull what is there, keep the
  /// newer row per id, then make local storage match the merged result.
  ///
  /// Safe to call repeatedly (on every sign-in and on app start while signed in).
  Future<void> mergeOnSignIn() async {
    final SyncRepository repository = ref.read(syncRepositoryProvider);
    if (!repository.isConfigured) {
      state = const SyncStatus(phase: SyncPhase.disabled);
      return;
    }
    if (!ref.read(authControllerProvider).isSignedIn) {
      state = SyncStatus(
        phase: SyncPhase.idle,
        lastSyncedAt: state.lastSyncedAt,
      );
      return;
    }

    state = state.copyWith(phase: SyncPhase.syncing, clearFailure: true);
    // Rows that pre-date sync have no recorded instant: this run is the moment
    // they are known to be held locally, which is what the contract's
    // "local wins on first sign-in" rule needs.
    final DateTime now = DateTime.now().toUtc();
    final SyncState local = await collectLocalState(assumeChangedAt: now);
    final SyncResult pushed = await repository.push(local);
    final SyncState remote = await repository.pull();
    final SyncState server = pushed.state.mergedWith(remote);
    final SyncState merged = local.mergedWith(server);

    await applyMergedState(merged);
    await recordLedger(merged);
    _lastPushedAt = merged.latestUpdatedAt;
    state = SyncStatus(
      phase: pushed.ok ? SyncPhase.synced : SyncPhase.failed,
      lastSyncedAt: merged.serverTime ?? remote.serverTime ?? now,
      applied: pushed.applied,
      rejected: pushed.rejected.length,
      failure: pushed.failure,
    );
  }

  /// Coalesced push of local changes; called by the bookmark/like/follow
  /// controllers so a change reaches the server without blocking the UI.
  void schedulePush() {
    if (!ref.read(syncRepositoryProvider).isConfigured) return;
    _debounce?.cancel();
    _debounce = Timer(syncPushDebounce, () => unawaited(pushLocalChanges()));
  }

  /// Pushes every row changed since the last successful push, then folds the
  /// server's answer back into local storage.
  Future<void> pushLocalChanges() async {
    final SyncRepository repository = ref.read(syncRepositoryProvider);
    if (!repository.isConfigured) return;
    if (!ref.read(authControllerProvider).isSignedIn) return;

    final SyncState local = await collectLocalState(
      assumeChangedAt: DateTime.now().toUtc(),
    );
    final DateTime? since = _lastPushedAt;
    final SyncState delta = since == null
        ? local
        : (local.deltaSince(since) ?? const SyncState.empty());
    if (delta.isEmpty) return;

    state = state.copyWith(phase: SyncPhase.syncing, clearFailure: true);
    final SyncResult pushed = await repository.push(delta);
    if (pushed.ok) {
      _lastPushedAt = delta.latestUpdatedAt ?? _lastPushedAt;
      await recordLedger(pushed.state);
    }
    state = SyncStatus(
      phase: pushed.ok ? SyncPhase.synced : SyncPhase.failed,
      lastSyncedAt: state.lastSyncedAt ?? DateTime.now().toUtc(),
      applied: pushed.applied,
      rejected: pushed.rejected.length,
      failure: pushed.failure,
    );
  }

  /// Records that the reader changed a row, so the next push carries the right
  /// instant and a delete is not resurrected by a pull.
  Future<void> recordLocalChange(
    String collection,
    String id, {
    bool deleted = false,
  }) async {
    await ref
        .read(syncLedgerProvider)
        .record(collection, id, DateTime.now().toUtc(), deleted: deleted);
    schedulePush();
  }

  /// Builds the local reader state as sync rows.
  ///
  /// Ids without a recorded instant are stamped with [assumeChangedAt]; metadata
  /// is resolved from the article cache and is best-effort by design (the API
  /// only requires a non-empty title, so an evicted article degrades to its id).
  Future<SyncState> collectLocalState({
    required DateTime assumeChangedAt,
  }) async {
    final LocalSyncLedger ledger = ref.read(syncLedgerProvider);
    final UserStateRepositoryState local = _localState(ref);

    final Set<String> bookmarkIds = <String>{
      ...local.bookmarkedIds,
      ...ledger.updatedAt(SyncCollections.bookmarks).keys,
    };
    final Set<String> reactionIds = <String>{
      ...local.likedIds,
      ...ledger.updatedAt(SyncCollections.reactions).keys,
    };
    final Map<String, FollowTarget> catalogue = _followCatalogue(ref);
    final Set<String> followIds = <String>{
      ...local.followedIds,
      ...ledger.updatedAt(SyncCollections.follows).keys,
    };

    final List<SyncBookmark> bookmarks = <SyncBookmark>[];
    for (final String id in bookmarkIds) {
      final DateTime at =
          ledger.at(SyncCollections.bookmarks, id) ?? assumeChangedAt;
      final bool deleted = ledger.isDeleted(SyncCollections.bookmarks, id);
      if (deleted) {
        bookmarks.add(SyncBookmark.deleted(itemId: id, updatedAt: at));
        continue;
      }
      final Article? article = await _article(ref, id);
      bookmarks.add(
        SyncBookmark(
          itemId: id,
          title: article?.title ?? id,
          sourceUrl: article?.sourceUrl,
          imageUrl: article?.imageUrl,
          publisher: article?.publisher.name,
          publishedAt: article?.publishedAt,
          // `savedAt` is when the reader saved it (the ledger instant), not when
          // the story was published.
          savedAt: at,
          updatedAt: at,
        ),
      );
    }

    final List<SyncReaction> reactions = <SyncReaction>[
      for (final String id in reactionIds)
        ledger.isDeleted(SyncCollections.reactions, id)
            ? SyncReaction.deleted(
                itemId: id,
                updatedAt:
                    ledger.at(SyncCollections.reactions, id) ?? assumeChangedAt,
              )
            : SyncReaction(
                itemId: id,
                updatedAt:
                    ledger.at(SyncCollections.reactions, id) ?? assumeChangedAt,
              ),
    ];

    final List<SyncFollow> follows = <SyncFollow>[
      for (final String id in followIds)
        if (ledger.isDeleted(SyncCollections.follows, id))
          SyncFollow.deleted(
            targetId: id,
            kind: catalogue[id]?.kind.wireValue ?? 'topic',
            updatedAt:
                ledger.at(SyncCollections.follows, id) ?? assumeChangedAt,
          )
        else
          SyncFollow(
            targetId: id,
            kind: catalogue[id]?.kind.wireValue ?? _kindFromId(id),
            label: catalogue[id]?.label ?? id,
            updatedAt:
                ledger.at(SyncCollections.follows, id) ?? assumeChangedAt,
          ),
    ];

    return SyncState(
      bookmarks: bookmarks,
      reactions: reactions,
      follows: follows,
    );
  }

  /// Makes local storage match [merged].
  ///
  /// Diffs rather than replaces, because the local repositories expose toggles
  /// (each is one Hive write) and a diff touches only the rows that changed.
  Future<void> applyMergedState(SyncState merged) async {
    final Set<String> desiredBookmarks = <String>{
      for (final SyncBookmark row in merged.activeBookmarks) row.itemId,
    };
    final Set<String> desiredLikes = <String>{
      for (final SyncReaction row in merged.activeReactions) row.itemId,
    };
    final Set<String> desiredFollows = <String>{
      for (final SyncFollow row in merged.activeFollows) row.targetId,
    };

    final BookmarksController bookmarks = ref.read(
      bookmarksControllerProvider.notifier,
    );
    final LikesController likes = ref.read(likesControllerProvider.notifier);
    final FollowingController following = ref.read(
      followingControllerProvider.notifier,
    );

    for (final String id
        in ref.read(bookmarksControllerProvider).difference(desiredBookmarks)) {
      await bookmarks.toggle(id);
    }
    for (final String id in desiredBookmarks.difference(
      ref.read(bookmarksControllerProvider),
    )) {
      await bookmarks.toggle(id);
    }
    for (final String id
        in ref.read(likesControllerProvider).difference(desiredLikes)) {
      await likes.toggle(id);
    }
    for (final String id in desiredLikes.difference(
      ref.read(likesControllerProvider),
    )) {
      await likes.toggle(id);
    }

    final Map<String, FollowTarget> catalogue = _followCatalogue(ref);
    final FollowingSnapshot current = ref.read(followingControllerProvider);
    for (final FollowTarget target in current.followed) {
      if (!desiredFollows.contains(target.id)) {
        await following.unfollow(target.id);
      }
    }
    for (final SyncFollow row in merged.activeFollows) {
      if (!ref.read(followingControllerProvider).isFollowed(row.targetId)) {
        await following.follow(
          catalogue[row.targetId] ??
              FollowTarget(
                id: row.targetId,
                kind: FollowKind.fromWire(row.kind),
                label: row.label ?? row.targetId,
              ),
        );
      }
    }
  }

  /// Records the merged rows' instants so later deltas are exact.
  Future<void> recordLedger(SyncState merged) async {
    final LocalSyncLedger ledger = ref.read(syncLedgerProvider);
    await ledger.recordBatch(
      SyncCollections.bookmarks,
      <String, DateTime>{
        for (final SyncBookmark row in merged.bookmarks)
          row.itemId: row.updatedAt,
      },
      tombstones: <String>{
        for (final SyncBookmark row in merged.bookmarks)
          if (row.deleted) row.itemId,
      },
    );
    await ledger.recordBatch(
      SyncCollections.reactions,
      <String, DateTime>{
        for (final SyncReaction row in merged.reactions)
          row.itemId: row.updatedAt,
      },
      tombstones: <String>{
        for (final SyncReaction row in merged.reactions)
          if (row.deleted) row.itemId,
      },
    );
    await ledger.recordBatch(
      SyncCollections.follows,
      <String, DateTime>{
        for (final SyncFollow row in merged.follows)
          row.targetId: row.updatedAt,
      },
      tombstones: <String>{
        for (final SyncFollow row in merged.follows)
          if (row.deleted) row.targetId,
      },
    );
  }

  Future<Article?> _article(Ref ref, String id) async {
    try {
      return await ref.read(articleRepositoryProvider).byId(id);
    } catch (error) {
      debugPrint('SyncController: article $id unavailable for sync ($error)');
      return null;
    }
  }

  static UserStateRepositoryState _localState(Ref ref) {
    final data = ref.read(userStateProvider);
    final FollowingSnapshot following = ref
        .read(followingRepositoryProvider)
        .load();
    return UserStateRepositoryState(
      bookmarkedIds: data.bookmarkedIds,
      likedIds: data.likedIds,
      followedIds: <String>{
        for (final FollowTarget target in following.followed) target.id,
      },
    );
  }

  static Map<String, FollowTarget> _followCatalogue(Ref ref) {
    final FollowingSnapshot snapshot = ref
        .read(followingRepositoryProvider)
        .load();
    return <String, FollowTarget>{
      for (final FollowTarget target in <FollowTarget>[
        ...snapshot.followed,
        ...snapshot.sports,
        ...snapshot.locations,
        ...snapshot.topics,
        ...snapshot.publishers,
        ...snapshot.suggested,
      ])
        target.id: target,
    };
  }

  static String _kindFromId(String id) {
    final int separator = id.indexOf(':');
    return separator > 0 ? id.substring(0, separator) : 'topic';
  }
}

/// Snapshot of the reader's local state, read once per collection set.
@immutable
class UserStateRepositoryState {
  /// Wraps the three id sets.
  const UserStateRepositoryState({
    required this.bookmarkedIds,
    required this.likedIds,
    required this.followedIds,
  });

  final Set<String> bookmarkedIds;
  final Set<String> likedIds;
  final Set<String> followedIds;
}
