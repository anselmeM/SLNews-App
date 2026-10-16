import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/sync/default_sync_repository.dart';
import 'package:slnews_mobile/core/domain/sync/sync_repository.dart';

import 'support/fakes.dart';

/// A repository over [source].
DefaultSyncRepository repositoryOver(FakeSyncApiSource source) =>
    DefaultSyncRepository(source: source);

void main() {
  group('unconfigured build', () {
    test('reports itself unconfigured', () {
      final FakeSyncApiSource source = FakeSyncApiSource(isConfigured: false);

      expect(repositoryOver(source).isConfigured, isFalse);
    });

    test(
      'push is inert: no request, a typed failure, nothing queued',
      () async {
        final FakeSyncApiSource source = FakeSyncApiSource(isConfigured: false);
        final DefaultSyncRepository repository = repositoryOver(source);

        final SyncResult result = await repository.push(
          SyncState(
            bookmarks: <SyncBookmark>[
              bookmark('a', updatedAt: DateTime.utc(2026, 10, 16, 4)),
            ],
          ),
        );

        expect(source.pushed, isEmpty);
        expect(result.ok, isFalse);
        expect(result.failure, isA<SyncUnavailable>());
        // The row the caller tried to send is still reported back to it.
        expect(result.state.bookmarks, hasLength(1));
        expect(repository.hasPendingPush, isFalse);
        expect(repository.pendingRowCount, 0);
      },
    );

    test('pull is inert: no request and an empty state', () async {
      final FakeSyncApiSource source = FakeSyncApiSource(isConfigured: false);
      final DefaultSyncRepository repository = repositoryOver(source);

      final SyncState state = await repository.pull();

      expect(state.isEmpty, isTrue);
      expect(source.pulled, isEmpty);
    });

    test('initialize is a no-op that completes', () async {
      final FakeSyncApiSource source = FakeSyncApiSource(isConfigured: false);

      await expectLater(repositoryOver(source).initialize(), completes);
    });
  });

  group('queue and retry', () {
    test('a failed push is remembered, not lost', () async {
      final FakeSyncApiSource source = FakeSyncApiSource()
        ..failuresRemaining = 1;
      final DefaultSyncRepository repository = repositoryOver(source);
      final SyncState local = SyncState(
        bookmarks: <SyncBookmark>[
          bookmark('a', updatedAt: DateTime.utc(2026, 10, 16, 4)),
        ],
      );

      final SyncResult first = await repository.push(local);

      expect(first.ok, isFalse);
      expect(repository.hasPendingPush, isTrue);
      expect(repository.pendingRowCount, 1);
      expect(repository.pending.bookmarks.single.itemId, 'a');
    });

    test(
      'the next push retries the queued rows and clears the queue',
      () async {
        final FakeSyncApiSource source = FakeSyncApiSource()
          ..failuresRemaining = 1;
        final DefaultSyncRepository repository = repositoryOver(source);

        await repository.push(
          SyncState(
            bookmarks: <SyncBookmark>[
              bookmark('a', updatedAt: DateTime.utc(2026, 10, 16, 4)),
            ],
          ),
        );
        final SyncResult retried = await repository.push(
          SyncState(
            bookmarks: <SyncBookmark>[
              bookmark('b', updatedAt: DateTime.utc(2026, 10, 16, 5)),
            ],
          ),
        );

        expect(retried.ok, isTrue);
        expect(repository.hasPendingPush, isFalse);
        expect(repository.pendingRowCount, 0);
        // The retry carried both rows: the queued one and the new one.
        expect(source.pushed, hasLength(2));
        expect(
          source.lastPush.bookmarks.map((SyncBookmark row) => row.itemId),
          <String>['b', 'a'],
        );
      },
    );

    test('a queued row survives later pushes until one succeeds', () async {
      final FakeSyncApiSource source = FakeSyncApiSource()
        ..failuresRemaining = 2;
      final DefaultSyncRepository repository = repositoryOver(source);

      await repository.push(
        SyncState(
          bookmarks: <SyncBookmark>[
            bookmark('a', updatedAt: DateTime.utc(2026, 10, 16, 4)),
          ],
        ),
      );
      await repository.push(const SyncState.empty());
      expect(repository.pendingRowCount, 1);

      final SyncResult third = await repository.push(const SyncState.empty());

      expect(third.ok, isTrue);
      expect(repository.hasPendingPush, isFalse);
      expect(source.lastPush.bookmarks.single.itemId, 'a');
    });

    test('the retry keeps the newest version of a conflicting row', () async {
      final FakeSyncApiSource source = FakeSyncApiSource()
        ..failuresRemaining = 1;
      final DefaultSyncRepository repository = repositoryOver(source);
      final DateTime stale = DateTime.utc(2026, 10, 16, 4);
      final DateTime fresh = DateTime.utc(2026, 10, 16, 6);

      await repository.push(
        SyncState(
          bookmarks: <SyncBookmark>[
            SyncBookmark(itemId: 'a', title: 'Stale title', updatedAt: stale),
          ],
        ),
      );
      await repository.push(
        SyncState(
          bookmarks: <SyncBookmark>[
            SyncBookmark(itemId: 'a', title: 'Fresh title', updatedAt: fresh),
          ],
        ),
      );

      final SyncBookmark sent = source.lastPush.bookmarks.single;
      expect(sent.title, 'Fresh title');
      expect(sent.updatedAt, fresh);
    });

    test('a retry carries a tombstone that the queue held', () async {
      final FakeSyncApiSource source = FakeSyncApiSource()
        ..failuresRemaining = 1;
      final DefaultSyncRepository repository = repositoryOver(source);

      await repository.push(
        SyncState(
          bookmarks: <SyncBookmark>[
            deletedBookmark('a', updatedAt: DateTime.utc(2026, 10, 16, 4)),
          ],
        ),
      );
      await repository.push(const SyncState.empty());

      expect(source.lastPush.bookmarks.single.deleted, isTrue);
    });

    test('a successful push never queues anything', () async {
      final FakeSyncApiSource source = FakeSyncApiSource();
      final DefaultSyncRepository repository = repositoryOver(source);

      final SyncResult result = await repository.push(
        SyncState(
          bookmarks: <SyncBookmark>[
            bookmark('a', updatedAt: DateTime.utc(2026, 10, 16, 4)),
          ],
        ),
      );

      expect(result.ok, isTrue);
      expect(repository.hasPendingPush, isFalse);
      expect(source.pushed, hasLength(1));
    });

    test('a push with rejections still clears the queue', () async {
      final FakeSyncApiSource source = FakeSyncApiSource()
        ..failuresRemaining = 1
        ..failWith = SyncResult.failed(SyncFailure.unavailable('offline'));
      final DefaultSyncRepository repository = repositoryOver(source);

      await repository.push(
        SyncState(
          bookmarks: <SyncBookmark>[
            bookmark('a', updatedAt: DateTime.utc(2026, 10, 16, 4)),
          ],
        ),
      );
      expect(repository.hasPendingPush, isTrue);

      // A 200 with a per-row rejection is a success, not a failure.
      final SyncResult result = await repository.push(const SyncState.empty());

      expect(result.ok, isTrue);
      expect(repository.hasPendingPush, isFalse);
    });
  });

  group('pull retries the queue first', () {
    test('a queued push is attempted before the pull', () async {
      final FakeSyncApiSource source = FakeSyncApiSource()
        ..failuresRemaining = 1;
      final DefaultSyncRepository repository = repositoryOver(source);

      await repository.push(
        SyncState(
          bookmarks: <SyncBookmark>[
            bookmark('a', updatedAt: DateTime.utc(2026, 10, 16, 4)),
          ],
        ),
      );
      final SyncState pulled = await repository.pull(
        since: DateTime.utc(2026, 10, 16, 3),
      );

      expect(source.pushed, hasLength(2));
      expect(source.pulled.single, DateTime.utc(2026, 10, 16, 3));
      expect(repository.hasPendingPush, isFalse);
      expect(pulled, source.nextPullRows);
    });

    test(
      'a still-failing retry keeps the queue and the pull still runs',
      () async {
        final FakeSyncApiSource source = FakeSyncApiSource()
          ..failuresRemaining = 2;
        final DefaultSyncRepository repository = repositoryOver(source);
        source.nextPullRows = SyncState(
          bookmarks: <SyncBookmark>[
            bookmark('remote', updatedAt: DateTime.utc(2026, 10, 16, 9)),
          ],
        );

        await repository.push(
          SyncState(
            bookmarks: <SyncBookmark>[
              bookmark('a', updatedAt: DateTime.utc(2026, 10, 16, 4)),
            ],
          ),
        );
        final SyncState pulled = await repository.pull();

        expect(repository.hasPendingPush, isTrue);
        expect(repository.pendingRowCount, 1);
        expect(pulled.bookmarks.single.itemId, 'remote');
        expect(source.pulled, hasLength(1));
      },
    );

    test('a pull with nothing queued does not push at all', () async {
      final FakeSyncApiSource source = FakeSyncApiSource();
      final DefaultSyncRepository repository = repositoryOver(source);

      await repository.pull();

      expect(source.pushed, isEmpty);
      expect(source.pulled, hasLength(1));
    });
  });

  group('failure containment', () {
    test(
      'a throwing source becomes a typed failure, not an exception',
      () async {
        final FakeSyncApiSource source = FakeSyncApiSource()
          ..throwOnPush = StateError('boom');
        final DefaultSyncRepository repository = repositoryOver(source);

        final SyncResult result = await repository.push(
          const SyncState.empty(),
        );

        expect(result.ok, isFalse);
        expect(result.failure, isA<SyncUnavailable>());
        expect(result.failure!.message, contains('boom'));
        // The batch was empty, so there is nothing to retry.
        expect(repository.pendingRowCount, 0);
      },
    );
  });
}
