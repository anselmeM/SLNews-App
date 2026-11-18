import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/data/sync/local_sync_ledger.dart';
import 'package:slnews_mobile/core/domain/auth/auth_repository.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/domain/sync/sync_repository.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/auth_providers.dart';
import 'package:slnews_mobile/core/providers/sync_controller.dart';
import 'package:slnews_mobile/core/providers/sync_repository_provider.dart';
import 'package:slnews_mobile/core/push/push_service.dart';

import '../features/feed/support/fakes.dart';

/// In-memory identity with a controllable session state.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.status = AuthStatus.signedIn});

  @override
  AuthStatus status;

  final StreamController<AuthStatus> _statuses =
      StreamController<AuthStatus>.broadcast();

  @override
  AuthUser? get currentUser => status.isSignedIn
      ? const AuthUser(id: 'user_1', displayName: 'Kadiatu')
      : null;

  @override
  Stream<AuthStatus> get statusChanges => _statuses.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> sessionToken({bool forceRefresh = false}) async =>
      status.isSignedIn ? 'session-token' : null;

  @override
  Future<void> signOut() async {
    status = AuthStatus.signedOut;
    _statuses.add(status);
  }
}

/// Configurable sync endpoint: records every push/pull and answers from fields.
class FakeSyncRepository implements SyncRepository {
  FakeSyncRepository({
    this.isConfigured = true,
    this.pullState = const SyncState.empty(),
    this.pushResult,
  });

  @override
  final bool isConfigured;

  SyncState pullState;
  SyncResult? pushResult;

  final List<SyncState> pushed = <SyncState>[];
  int pullCount = 0;

  /// Optional per-push answer; falls back to [pushResult] then to echoing the
  /// sent rows so a test that does not care about the answer stays simple.
  SyncResult Function(SyncState local)? onPush;

  @override
  Future<void> initialize() async {}

  @override
  Future<SyncState> pull({DateTime? since}) async {
    pullCount += 1;
    return pullState;
  }

  @override
  Future<SyncResult> push(SyncState local) async {
    pushed.add(local);
    final SyncResult Function(SyncState local)? handler = onPush;
    if (handler != null) return handler(local);
    return pushResult ?? SyncResult(state: local);
  }
}

void main() {
  final DateTime t0 = DateTime.utc(2026, 11, 12, 8);
  DateTime t(int minutes) => t0.add(Duration(minutes: minutes));

  late InMemoryPreferencesStore store;
  late FakeAuthRepository auth;
  late FakeSyncRepository sync;
  late FakeUserStateRepository userState;
  late FakeFollowingRepository following;
  late ProviderContainer container;

  const FollowTarget lakers = FollowTarget(
    id: 'team:lal',
    kind: FollowKind.team,
    label: 'Los Angeles Lakers',
  );

  void build({
    bool signedIn = true,
    bool configured = true,
    Set<String> bookmarks = const <String>{},
    Set<String> likes = const <String>{},
    List<FollowTarget> catalogue = const <FollowTarget>[],
  }) {
    store = InMemoryPreferencesStore();
    auth = FakeAuthRepository(
      status: signedIn ? AuthStatus.signedIn : AuthStatus.signedOut,
    );
    sync = FakeSyncRepository(isConfigured: configured);
    userState = FakeUserStateRepository(
      bookmarkedIds: bookmarks,
      likedIds: likes,
    );
    following = FakeFollowingRepository(catalogue: catalogue);
    container = ProviderContainer(
      overrides: [
        preferencesStoreProvider.overrideWithValue(store),
        authRepositoryProvider.overrideWithValue(auth),
        syncRepositoryProvider.overrideWithValue(sync),
        userStateProvider.overrideWithValue(userState),
        followingRepositoryProvider.overrideWithValue(following),
        articleRepositoryProvider.overrideWithValue(FakeArticleRepository()),
        pushServiceProvider.overrideWithValue(
          PushService.forTransports(
            register: (_, _) async => null,
            unregister: (_, _) async => null,
            token: () async => null,
            requestPermission: () async => false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  }

  test('a build with no sync endpoint is disabled', () async {
    build(configured: false);

    expect(container.read(syncControllerProvider), isA<SyncDisabled>());
    await container.read(syncControllerProvider.notifier).mergeOnSignIn();
    expect(container.read(syncControllerProvider), isA<SyncDisabled>());
    expect(sync.pushed, isEmpty);
    expect(sync.pullCount, isZero);
  });

  test('mergeOnSignIn stays idle and does no I/O while signed out', () async {
    build(signedIn: false, bookmarks: <String>{'b1'});

    await container.read(syncControllerProvider.notifier).mergeOnSignIn();

    expect(container.read(syncControllerProvider), isA<SyncIdle>());
    expect(sync.pushed, isEmpty);
    expect(sync.pullCount, isZero);
  });

  test(
    'mergeOnSignIn pushes local rows, pulls remote rows and applies the merge',
    () async {
      build(bookmarks: <String>{'b1'});
      final SyncState remote = SyncState(
        bookmarks: <SyncBookmark>[
          SyncBookmark(itemId: 'b2', title: 'Remote story', updatedAt: t(5)),
        ],
        serverTime: t(6),
      );
      sync.pullState = remote;
      sync.onPush = (SyncState local) =>
          SyncResult(applied: const SyncApplied(bookmarks: 1), state: local);

      await container.read(syncControllerProvider.notifier).mergeOnSignIn();

      expect(sync.pushed, hasLength(1));
      expect(
        sync.pushed.single.bookmarks.map((SyncBookmark row) => row.itemId),
        <String>['b1'],
      );
      expect(sync.pullCount, 1);

      final SyncStatus state = container.read(syncControllerProvider);
      expect(state, isA<SyncSynced>());
      expect(state.applied.bookmarks, 1);
      expect(state.lastSyncedAt, isNotNull);

      // Both rows are local now: the pushed one and the pulled one.
      expect(userState.bookmarkedIds, <String>{'b1', 'b2'});
      // The pulled row's instant is recorded so the next delta is exact.
      final LocalSyncLedger ledger = container.read(syncLedgerProvider);
      expect(ledger.at(SyncCollections.bookmarks, 'b2'), t(5));
    },
  );

  test(
    'pushLocalChanges sends only the rows changed since the last push',
    () async {
      build(bookmarks: <String>{'b1'});
      sync.pullState = SyncState(
        bookmarks: <SyncBookmark>[
          SyncBookmark(itemId: 'b2', title: 'Remote', updatedAt: t(5)),
        ],
        serverTime: t(6),
      );

      final SyncController controller = container.read(
        syncControllerProvider.notifier,
      );
      await controller.mergeOnSignIn();
      sync.pushed.clear();

      // A new local save after the merge.
      await userState.toggleBookmark('b3');
      await container
          .read(syncLedgerProvider)
          .record(
            SyncCollections.bookmarks,
            'b3',
            DateTime.now().toUtc().add(const Duration(minutes: 1)),
          );

      await controller.pushLocalChanges();

      expect(sync.pushed, hasLength(1));
      expect(
        sync.pushed.single.bookmarks.map((SyncBookmark row) => row.itemId),
        <String>['b3'],
      );
      expect(container.read(syncControllerProvider), isA<SyncSynced>());
    },
  );

  test(
    'a failed push surfaces the typed failure and keeps local state',
    () async {
      build(bookmarks: <String>{'b1'});
      sync.onPush = (SyncState local) => SyncResult.failed(
        const SyncUnavailable('transport down'),
        local: local,
      );

      await container.read(syncControllerProvider.notifier).mergeOnSignIn();

      final SyncStatus state = container.read(syncControllerProvider);
      expect(state, isA<SyncFailed>());
      expect((state as SyncFailed).failure, isA<SyncUnavailable>());
      expect(state.label, contains('unavailable'));
      // Local rows were not dropped by the failure.
      expect(userState.bookmarkedIds, contains('b1'));
    },
  );

  test(
    'collectLocalState stamps unknown instants, tombstones and follow kinds',
    () async {
      build(
        bookmarks: <String>{'b1'},
        likes: <String>{'l1'},
        catalogue: <FollowTarget>[lakers],
      );
      await following.follow(lakers);
      final LocalSyncLedger ledger = container.read(syncLedgerProvider);
      await ledger.record(
        SyncCollections.bookmarks,
        'gone',
        t(2),
        deleted: true,
      );
      await ledger.record(SyncCollections.follows, 'team:lal', t(3));

      final SyncState rows = await container
          .read(syncControllerProvider.notifier)
          .collectLocalState(assumeChangedAt: t(20));

      final Map<String, SyncBookmark> bookmarks = <String, SyncBookmark>{
        for (final SyncBookmark row in rows.bookmarks) row.itemId: row,
      };
      expect(bookmarks['b1']?.updatedAt, t(20));
      expect(bookmarks['b1']?.title, 'b1', reason: 'no article cache entry');
      expect(bookmarks['gone']?.deleted, isTrue);
      expect(bookmarks['gone']?.updatedAt, t(2));

      expect(rows.reactions.single.itemId, 'l1');
      expect(rows.reactions.single.updatedAt, t(20));

      final SyncFollow follow = rows.follows.single;
      expect(follow.targetId, 'team:lal');
      expect(follow.kind, 'team');
      expect(follow.label, 'Los Angeles Lakers');
      expect(follow.updatedAt, t(3));
    },
  );

  test(
    'applyMergedState adds and removes local rows to match the server',
    () async {
      build(bookmarks: <String>{'local-only'}, likes: <String>{'liked'});

      await container
          .read(syncControllerProvider.notifier)
          .applyMergedState(
            SyncState(
              bookmarks: <SyncBookmark>[
                SyncBookmark(
                  itemId: 'remote',
                  title: 'Remote',
                  updatedAt: t(4),
                ),
              ],
              reactions: const <SyncReaction>[],
              follows: <SyncFollow>[
                SyncFollow(
                  targetId: 'team:lal',
                  kind: 'team',
                  label: 'Los Angeles Lakers',
                  updatedAt: t(4),
                ),
              ],
            ),
          );

      expect(userState.bookmarkedIds, <String>{'remote'});
      expect(userState.likedIds, isEmpty);
      expect(following.isFollowed('team:lal'), isTrue);
    },
  );

  test('recordLocalChange writes the ledger and schedules a push', () async {
    build(bookmarks: <String>{'b1'});

    await container
        .read(syncControllerProvider.notifier)
        .recordLocalChange(SyncCollections.bookmarks, 'b1');

    final LocalSyncLedger ledger = container.read(syncLedgerProvider);
    expect(ledger.at(SyncCollections.bookmarks, 'b1'), isNotNull);
  });

  test('status labels describe the state for the account card', () {
    expect(const SyncDisabled().label, contains('unavailable'));
    expect(const SyncIdle().label, 'Signed in — not synced yet');
    expect(const SyncSyncing().isBusy, isTrue);
    expect(
      const SyncFailed(failure: SyncUnauthorized('401')).label,
      contains('unauthorized'),
    );
  });
}
