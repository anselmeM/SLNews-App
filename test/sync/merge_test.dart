import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/sync/merge.dart';
import 'package:slnews_mobile/core/domain/sync/sync_repository.dart';

import 'support/fakes.dart';

/// Ids of the merged bookmarks, in the order the merge produced them.
List<String> idsOf(Iterable<SyncRow> rows) =>
    rows.map((SyncRow row) => row.id).toList(growable: false);

void main() {
  group('mergeBookmarks — union', () {
    test('keeps rows that exist on only one side', () {
      final List<SyncBookmark> merged = mergeBookmarks(
        <SyncBookmark>[bookmark('slnews-api:1', updatedAt: t(10))],
        <SyncBookmark>[bookmark('rss:aa', updatedAt: t(20))],
      );

      expect(idsOf(merged), <String>['rss:aa', 'slnews-api:1']);
    });

    test('de-duplicates by identity key, not by value', () {
      final List<SyncBookmark> merged = mergeBookmarks(
        <SyncBookmark>[
          bookmark('slnews-api:1', updatedAt: t(1), title: 'Local title'),
        ],
        <SyncBookmark>[
          // Same id, older payload: still one row, and the newer one wins.
          bookmark('slnews-api:1', updatedAt: t(2), title: 'Remote title'),
        ],
      );

      expect(merged, hasLength(1));
      expect(merged.single.title, 'Remote title');
    });

    test('two empty sides merge to nothing', () {
      expect(
        mergeBookmarks(const <SyncBookmark>[], const <SyncBookmark>[]),
        isEmpty,
      );
    });

    test('an empty local side is the remote side, newest first', () {
      final List<SyncBookmark> remote = <SyncBookmark>[
        bookmark('a', updatedAt: t(1)),
        bookmark('b', updatedAt: t(5)),
      ];

      expect(idsOf(mergeBookmarks(const <SyncBookmark>[], remote)), <String>[
        'b',
        'a',
      ]);
    });

    test('an empty remote side is the local side, newest first', () {
      final List<SyncBookmark> local = <SyncBookmark>[
        bookmark('a', updatedAt: t(1)),
        bookmark('b', updatedAt: t(5)),
      ];

      expect(idsOf(mergeBookmarks(local, const <SyncBookmark>[])), <String>[
        'b',
        'a',
      ]);
    });
  });

  group('mergeBookmarks — last write wins', () {
    test('remote wins when its updatedAt is newer', () {
      final List<SyncBookmark> merged = mergeBookmarks(
        <SyncBookmark>[
          bookmark('slnews-api:4821', updatedAt: t(10), title: 'Phone copy'),
        ],
        <SyncBookmark>[
          bookmark('slnews-api:4821', updatedAt: t(15), title: 'Web copy'),
        ],
      );

      expect(merged.single.title, 'Web copy');
      expect(merged.single.updatedAt, t(15));
    });

    test('local wins when its updatedAt is newer', () {
      final List<SyncBookmark> merged = mergeBookmarks(
        <SyncBookmark>[
          bookmark('slnews-api:4821', updatedAt: t(30), title: 'Phone copy'),
        ],
        <SyncBookmark>[
          bookmark('slnews-api:4821', updatedAt: t(15), title: 'Web copy'),
        ],
      );

      expect(merged.single.title, 'Phone copy');
      expect(merged.single.updatedAt, t(30));
    });

    test('compares instants, not rendered strings', () {
      // The same instant written with and without a Z suffix: the later-stamped
      // row must win on the instant even though the strings differ.
      final DateTime instant = DateTime.parse('2026-10-16T05:00:00.000Z');
      final List<SyncBookmark> merged = mergeBookmarks(
        <SyncBookmark>[
          bookmark('x', updatedAt: instant, title: 'earlier-suffix'),
        ],
        <SyncBookmark>[
          bookmark(
            'x',
            updatedAt: instant.add(const Duration(milliseconds: 1)),
            title: 'later',
          ),
        ],
      );

      expect(merged.single.title, 'later');
    });

    test('equal timestamps keep the local row and stay idempotent', () {
      final SyncState local = SyncState(
        bookmarks: <SyncBookmark>[
          bookmark('x', updatedAt: t(10), title: 'Local'),
        ],
        reactions: <SyncReaction>[reaction('x', updatedAt: t(10))],
        follows: <SyncFollow>[follow('team:lal', updatedAt: t(10))],
      );
      final SyncState remote = SyncState(
        bookmarks: <SyncBookmark>[
          bookmark('x', updatedAt: t(10), title: 'Remote'),
        ],
        reactions: <SyncReaction>[reaction('x', updatedAt: t(10))],
        follows: <SyncFollow>[follow('team:lal', updatedAt: t(10))],
      );

      final SyncState once = mergeSyncStates(local, remote);
      final SyncState twice = mergeSyncStates(once, remote);

      expect(once.bookmarks.single.title, 'Local');
      expect(idsOf(twice.bookmarks), idsOf(once.bookmarks));
      expect(twice.bookmarks.single.title, 'Local');
    });

    test('equal timestamps prefer a deletion over a live row', () {
      final List<SyncBookmark> merged = mergeBookmarks(
        <SyncBookmark>[bookmark('x', updatedAt: t(10))],
        <SyncBookmark>[deletedBookmark('x', updatedAt: t(10))],
      );

      expect(merged.single.deleted, isTrue);
    });
  });

  group('mergeBookmarks — tombstones', () {
    test('a newer tombstone beats an older non-deleted row', () {
      final List<SyncBookmark> merged = mergeBookmarks(
        <SyncBookmark>[
          bookmark('slnews-api:4821', updatedAt: t(10), title: 'Saved on web'),
        ],
        <SyncBookmark>[deletedBookmark('slnews-api:4821', updatedAt: t(20))],
      );

      expect(merged.single.deleted, isTrue);
      expect(merged.single.updatedAt, t(20));
      expect(merged.single.title, isEmpty);
    });

    test('an older tombstone does not beat a newer live row', () {
      final List<SyncBookmark> merged = mergeBookmarks(
        <SyncBookmark>[
          bookmark('slnews-api:4821', updatedAt: t(30), title: 'Re-saved'),
        ],
        <SyncBookmark>[deletedBookmark('slnews-api:4821', updatedAt: t(20))],
      );

      expect(merged.single.deleted, isFalse);
      expect(merged.single.title, 'Re-saved');
    });

    test(
      'a tombstone is never resurrected by a merge, only by a newer save',
      () {
        final SyncState server = SyncState(
          bookmarks: <SyncBookmark>[
            deletedBookmark('slnews-api:4821', updatedAt: t(20)),
          ],
        );
        final SyncState staleDevice = SyncState(
          bookmarks: <SyncBookmark>[
            bookmark('slnews-api:4821', updatedAt: t(10), title: 'Stale'),
          ],
        );

        final SyncState merged = mergeSyncStates(staleDevice, server);

        expect(merged.bookmarks.single.deleted, isTrue);
      },
    );

    test('tombstones survive a state merge alongside live rows', () {
      final SyncState local = SyncState(
        bookmarks: <SyncBookmark>[
          bookmark('a', updatedAt: t(10)),
          deletedBookmark('b', updatedAt: t(12)),
        ],
      );
      final SyncState remote = SyncState(
        bookmarks: <SyncBookmark>[bookmark('c', updatedAt: t(5))],
      );

      final SyncState merged = mergeSyncStates(local, remote);

      expect(idsOf(merged.bookmarks), <String>['b', 'a', 'c']);
      expect(merged.bookmarks.first.deleted, isTrue);
      expect(idsOf(merged.activeBookmarks), <String>['a', 'c']);
    });
  });

  group('mergeBookmarks — ordering', () {
    test('newest first, with the id as a stable tie-break', () {
      final List<SyncBookmark> merged = mergeBookmarks(
        <SyncBookmark>[
          bookmark('m', updatedAt: t(1)),
          bookmark('b', updatedAt: t(9)),
          bookmark('c', updatedAt: t(9)),
        ],
        <SyncBookmark>[bookmark('a', updatedAt: t(5))],
      );

      expect(idsOf(merged), <String>['b', 'c', 'a', 'm']);
    });

    test('merging a state with itself keeps the same order', () {
      final SyncState state = SyncState(
        bookmarks: <SyncBookmark>[
          bookmark('a', updatedAt: t(1)),
          bookmark('b', updatedAt: t(1)),
          bookmark('c', updatedAt: t(7)),
        ],
      );

      // Merging re-orders by `updatedAt` (newest first, id as the tie-break),
      // so the invariant is that a second merge changes nothing.
      final SyncState once = mergeSyncStates(state, state);
      final SyncState twice = mergeSyncStates(once, state);

      expect(idsOf(once.bookmarks), <String>['c', 'a', 'b']);
      expect(idsOf(twice.bookmarks), idsOf(once.bookmarks));
    });

    test('the result is unmodifiable', () {
      final List<SyncBookmark> merged = mergeBookmarks(<SyncBookmark>[
        bookmark('a', updatedAt: t(1)),
      ], const <SyncBookmark>[]);

      expect(
        () => merged.add(bookmark('b', updatedAt: t(2))),
        throwsUnsupportedError,
      );
    });
  });

  group('mergeSyncStates', () {
    test('merges all three collections independently', () {
      final SyncState local = SyncState(
        bookmarks: <SyncBookmark>[
          bookmark('slnews-api:4821', updatedAt: t(10), title: 'Phone'),
        ],
        reactions: <SyncReaction>[
          reaction('slnews-api:4821', updatedAt: t(10)),
        ],
        follows: <SyncFollow>[follow('team:lal', updatedAt: t(10))],
      );
      final SyncState remote = SyncState(
        bookmarks: <SyncBookmark>[
          bookmark('slnews-api:4821', updatedAt: t(20), title: 'Web'),
          bookmark('rss:aa', updatedAt: t(21), title: 'Wire story'),
        ],
        reactions: <SyncReaction>[
          reaction('slnews-api:4821', updatedAt: t(5), deleted: true),
        ],
        follows: <SyncFollow>[
          follow('city:freetown', updatedAt: t(30), kind: 'location'),
        ],
      );

      final SyncState merged = mergeSyncStates(local, remote);

      expect(merged.bookmarks.map((SyncBookmark r) => r.title), <String>[
        'Wire story',
        'Web',
      ]);
      expect(merged.reactions.single.deleted, isFalse);
      expect(idsOf(merged.follows), <String>['city:freetown', 'team:lal']);
    });

    test('takes the server clock from the remote side, else the local one', () {
      final DateTime serverClock = DateTime.utc(2026, 10, 16, 5);
      final DateTime localClock = DateTime.utc(2026, 10, 16, 4);

      expect(
        mergeSyncStates(
          SyncState(serverTime: localClock),
          SyncState(serverTime: serverClock),
        ).serverTime,
        serverClock,
      );
      expect(
        mergeSyncStates(
          SyncState(serverTime: localClock),
          const SyncState.empty(),
        ).serverTime,
        localClock,
      );
    });

    test('merging is commutative for identity and timestamps', () {
      final SyncState local = SyncState(
        bookmarks: <SyncBookmark>[
          bookmark('a', updatedAt: t(10)),
          bookmark('b', updatedAt: t(4)),
        ],
      );
      final SyncState remote = SyncState(
        bookmarks: <SyncBookmark>[
          bookmark('a', updatedAt: t(6)),
          bookmark('c', updatedAt: t(20)),
        ],
      );

      final SyncState forward = mergeSyncStates(local, remote);
      final SyncState backward = mergeSyncStates(remote, local);

      expect(idsOf(forward.bookmarks), idsOf(backward.bookmarks));
      expect(
        forward.bookmarks.map((SyncBookmark r) => r.updatedAt),
        backward.bookmarks.map((SyncBookmark r) => r.updatedAt),
      );
    });

    test('both sides empty merges to empty', () {
      final SyncState merged = mergeSyncStates(
        const SyncState.empty(),
        const SyncState.empty(),
      );

      expect(merged.isEmpty, isTrue);
      expect(merged.latestUpdatedAt, isNull);
    });
  });

  group('SyncState delta helpers', () {
    test('deltaSince keeps only strictly newer rows', () {
      final SyncState state = SyncState(
        bookmarks: <SyncBookmark>[
          bookmark('old', updatedAt: t(1)),
          bookmark('boundary', updatedAt: t(10)),
          bookmark('new', updatedAt: t(11)),
        ],
        reactions: <SyncReaction>[
          reaction('old', updatedAt: t(1)),
          reaction('new', updatedAt: t(30)),
        ],
        follows: <SyncFollow>[follow('team:lal', updatedAt: t(11))],
      );

      final SyncState? delta = state.deltaSince(t(10));

      expect(delta, isNotNull);
      expect(idsOf(delta!.bookmarks), <String>['new']);
      expect(idsOf(delta.reactions), <String>['new']);
      expect(idsOf(delta.follows), <String>['team:lal']);
    });

    test('deltaSince is null when nothing changed', () {
      final SyncState state = SyncState(
        bookmarks: <SyncBookmark>[bookmark('a', updatedAt: t(5))],
      );

      expect(state.deltaSince(t(5)), isNull);
      expect(state.deltaSince(t(50)), isNull);
    });

    test('deltaSince carries a tombstone like any other row', () {
      final SyncState state = SyncState(
        bookmarks: <SyncBookmark>[deletedBookmark('a', updatedAt: t(20))],
      );

      final SyncState delta = state.deltaSince(t(10))!;

      expect(delta.bookmarks.single.deleted, isTrue);
    });

    test('deltaSince keeps tombstones out of the active views', () {
      final SyncState state = SyncState(
        bookmarks: <SyncBookmark>[
          bookmark('a', updatedAt: t(20)),
          deletedBookmark('b', updatedAt: t(20)),
        ],
        reactions: <SyncReaction>[
          reaction('a', updatedAt: t(20)),
          deletedReaction('b', updatedAt: t(20)),
        ],
        follows: <SyncFollow>[
          follow('team:lal', updatedAt: t(20)),
          deletedFollow('league:spl', updatedAt: t(20)),
        ],
      );

      expect(idsOf(state.activeBookmarks), <String>['a']);
      expect(idsOf(state.activeReactions), <String>['a']);
      expect(idsOf(state.activeFollows), <String>['team:lal']);
      expect(idsOf(state.tombstones), <String>['b', 'b', 'league:spl']);
      expect(state.isEmpty, isFalse);
    });

    test('latestUpdatedAt spans every collection and ignores order', () {
      final SyncState state = SyncState(
        bookmarks: <SyncBookmark>[bookmark('a', updatedAt: t(3))],
        reactions: <SyncReaction>[reaction('a', updatedAt: t(40))],
        follows: <SyncFollow>[follow('team:lal', updatedAt: t(7))],
      );

      expect(state.latestUpdatedAt, t(40));
    });

    test('rowsWhere filters any row list by instant', () {
      final List<SyncRow> rows = <SyncRow>[
        bookmark('a', updatedAt: t(1)),
        reaction('b', updatedAt: t(50)),
        follow('team:lal', updatedAt: t(50)),
      ];

      expect(idsOf(SyncState.rowsWhere<SyncRow>(rows, t(10))), <String>[
        'b',
        'team:lal',
      ]);
    });

    test('withoutRows drops rejected rows by collection and id', () {
      final SyncState state = SyncState(
        bookmarks: <SyncBookmark>[
          bookmark('a', updatedAt: t(1)),
          bookmark('b', updatedAt: t(2)),
        ],
        reactions: <SyncReaction>[reaction('a', updatedAt: t(1))],
        follows: <SyncFollow>[follow('team:lal', updatedAt: t(1))],
      );

      final SyncState narrowed = state.withoutRows(const <SyncRejection>[
        SyncRejection(collection: 'bookmarks', id: 'a', reason: 'stale'),
        SyncRejection(collection: 'follows', id: 'team:lal', reason: 'stale'),
        SyncRejection(collection: 'reactions', id: 'nope', reason: 'stale'),
      ]);

      expect(idsOf(narrowed.bookmarks), <String>['b']);
      expect(idsOf(narrowed.reactions), <String>['a']);
      expect(narrowed.follows, isEmpty);
    });

    test('deltaSince keeps the collection order of the parent state', () {
      final SyncState state = SyncState(
        bookmarks: <SyncBookmark>[
          bookmark('newer', updatedAt: t(20)),
          bookmark('older', updatedAt: t(1)),
        ],
      );

      expect(idsOf(state.deltaSince(t(10))!.bookmarks), <String>['newer']);
    });
  });

  group('mergeRows', () {
    test('returns the newer row for either argument order', () {
      final SyncBookmark older = bookmark('a', updatedAt: t(1));
      final SyncBookmark newer = bookmark('a', updatedAt: t(2));

      expect(mergeRows(older, newer).updatedAt, t(2));
      expect(mergeRows(newer, older).updatedAt, t(2));
    });

    test('returns the local row on a tie', () {
      final SyncBookmark local = bookmark('a', updatedAt: t(1), title: 'Local');
      final SyncBookmark remote = bookmark(
        'a',
        updatedAt: t(1),
        title: 'Remote',
      );

      expect(mergeRows(local, remote).title, 'Local');
    });
  });
}
