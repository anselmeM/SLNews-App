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

import 'package:slnews_mobile/core/utils/app_log.dart';

part 'sync_status.dart';

/// What the account surface shows about syncing.
///
/// Sealed so callers cannot construct an impossible combination (for example a
/// `failed` status without a [SyncFailure], or `synced` without a server clock).

final Provider<LocalSyncLedger> syncLedgerProvider = Provider<LocalSyncLedger>(
  (Ref ref) => LocalSyncLedger(
    ref.watch(preferencesStoreProvider),
    accountId: () => ref.read(activeAccountKeyProvider),
  ),
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
  Timer? _retryTimer;
  int _retryAttempt = 0;
  DateTime? _lastPushedAt;
  bool _merging = false;

  /// Bounded retry ladder for a failed push. A transient outage should not
  /// leave the account card stuck on `failed` until the next local edit.
  static const List<Duration> _retryDelays = <Duration>[
    Duration(seconds: 20),
    Duration(minutes: 2),
    Duration(minutes: 10),
  ];

  @override
  SyncStatus build() {
    // Resetting on identity changes keeps A's sync status and timers from
    // leaking into B or into the signed-out reader.
    ref.watch(activeAccountKeyProvider);
    ref.onDispose(() {
      _debounce?.cancel();
      _retryTimer?.cancel();
      _merging = false;
    });
    final SyncRepository repository = ref.watch(syncRepositoryProvider);
    return repository.isConfigured ? const SyncIdle() : const SyncDisabled();
  }

  /// Clears account-bound status immediately when the reader signs out.
  void onSignedOut() {
    _debounce?.cancel();
    _clearRetry();
    _lastPushedAt = null;
    _merging = false;
    final SyncRepository repository = ref.read(syncRepositoryProvider);
    state = repository.isConfigured ? const SyncIdle() : const SyncDisabled();
  }

  void _clearRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
  }

  void _scheduleRetry() {
    if (_retryTimer != null || _retryAttempt >= _retryDelays.length) return;
    final Duration delay = _retryDelays[_retryAttempt];
    _retryAttempt += 1;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      unawaited(pushLocalChanges());
    });
  }

  SyncStatus _completedStatus(SyncResult pushed, {required DateTime syncedAt}) {
    if (pushed.ok) {
      return SyncSynced(
        lastSyncedAt: syncedAt,
        applied: pushed.applied,
        rejected: pushed.rejected.length,
      );
    }
    return SyncFailed(
      failure: pushed.failure ?? const SyncUnavailable('Sync failed'),
      lastSyncedAt: syncedAt,
      applied: pushed.applied,
      rejected: pushed.rejected.length,
    );
  }

  /// Merge-on-first-sign-in: push what is here, pull what is there, keep the
  /// newer row per id, then make local storage match the merged result.
  ///
  /// Safe to call repeatedly (on every sign-in and on app start while signed in).
  Future<void> mergeOnSignIn() async {
    if (_merging) return;
    _merging = true;
    try {
      await _mergeOnSignIn();
    } finally {
      _merging = false;
    }
  }

  Future<void> _mergeOnSignIn() async {
    final SyncRepository repository = ref.read(syncRepositoryProvider);
    if (!repository.isConfigured) {
      _clearRetry();
      state = const SyncDisabled();
      return;
    }
    if (!ref.read(authControllerProvider).isSignedIn) {
      _clearRetry();
      state = SyncIdle(lastSyncedAt: state.lastSyncedAt);
      return;
    }

    state = state.asSyncing();
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
    state = _completedStatus(
      pushed,
      syncedAt: merged.serverTime ?? remote.serverTime ?? now,
    );
    if (pushed.ok) {
      _clearRetry();
    } else {
      _scheduleRetry();
    }
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

    state = state.asSyncing();
    final SyncResult pushed = await repository.push(delta);
    if (pushed.ok) {
      _lastPushedAt = delta.latestUpdatedAt ?? _lastPushedAt;
      await recordLedger(pushed.state);
    }
    state = _completedStatus(
      pushed,
      syncedAt: state.lastSyncedAt ?? DateTime.now().toUtc(),
    );
    if (pushed.ok) {
      _clearRetry();
    } else {
      _scheduleRetry();
    }
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
      await bookmarks.toggle(id, recordEngagement: false);
    }
    for (final String id in desiredBookmarks.difference(
      ref.read(bookmarksControllerProvider),
    )) {
      await bookmarks.toggle(id, recordEngagement: false);
    }
    for (final String id
        in ref.read(likesControllerProvider).difference(desiredLikes)) {
      await likes.toggle(id, recordEngagement: false);
    }
    for (final String id in desiredLikes.difference(
      ref.read(likesControllerProvider),
    )) {
      await likes.toggle(id, recordEngagement: false);
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
      AppLog.debug('SyncController: article $id unavailable for sync ($error)');
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

  /// Kind for a followed id the catalogue no longer lists (an older seed, a
  /// target that was retired). The API accepts a fixed vocabulary
  /// (`team|league|location|topic|publisher`), so the raw id prefix — which can be
  /// `city` or `district` — must be mapped rather than forwarded: an unmapped
  /// prefix is a `400` that rejects the whole push.
  static String _kindFromId(String id) {
    final int separator = id.indexOf(':');
    final String prefix = separator > 0 ? id.substring(0, separator) : '';
    return switch (prefix) {
      'team' => 'team',
      'league' || 'competition' => 'league',
      'city' ||
      'region' ||
      'district' ||
      'province' ||
      'location' => 'location',
      'publisher' => 'publisher',
      _ => 'topic',
    };
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
