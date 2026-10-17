import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/sync/remote_sync_source.dart';
import 'package:slnews_mobile/core/domain/sync/sync_repository.dart';

/// The server's accepted timestamp shape, copied from
/// `SLNews/src/lib/mobile-sync/validation.ts` (`parseIsoInstant`).
final RegExp contractTimestamp = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?(?:Z|[+-]\d{2}:?\d{2})$',
);

void main() {
  group('wire timestamps', () {
    test('a microsecond instant is quantised to milliseconds', () {
      // `DateTime.now()` on Android carries microseconds; this is the exact shape
      // that made every sync request a 400 and surfaced as "rejected" on device.
      final DateTime instant = DateTime.utc(2026, 10, 16, 22, 8, 0, 123, 456);

      expect(syncTimestamp(instant), '2026-10-16T22:08:00.123Z');
    });

    test('every serialised instant matches the server contract', () {
      final List<DateTime> instants = <DateTime>[
        DateTime.utc(2026, 10, 16, 22, 8, 0, 123, 456),
        DateTime.utc(2026, 10, 16, 22, 8, 0, 123, 0),
        DateTime.utc(2026, 10, 16, 22, 8, 0, 0, 0),
        DateTime.utc(2026, 1, 2, 3, 4, 5, 6, 789),
      ];

      for (final DateTime instant in instants) {
        final String? wire = syncTimestamp(instant);
        expect(wire, isNotNull);
        expect(
          contractTimestamp.hasMatch(wire!),
          isTrue,
          reason:
              '$wire is not the ISO-8601 milliseconds shape the API accepts',
        );
      }
    });

    test('a local instant is converted to UTC', () {
      final DateTime local = DateTime(2026, 10, 16, 22, 8, 0, 123, 456);
      final String? wire = syncTimestamp(local);

      expect(wire, isNotNull);
      expect(wire!.endsWith('Z'), isTrue);
      expect(
        wire,
        endsWith('.123Z'),
        reason: 'the millisecond must survive, the microseconds must not',
      );

      // Truncating sub-millisecond precision is the point; it must not move the
      // instant by a whole millisecond or more.
      final Duration delta = parseSyncTimestamp(wire)!
          .difference(local.toUtc())
          .abs();
      expect(delta, lessThan(const Duration(milliseconds: 1)));
    });

    test('null stays null', () {
      expect(syncTimestamp(null), isNull);
    });

    test('a full push body carries no microsecond fractions', () {
      // End-to-end through the encoder that actually produces the POST body.
      final DateTime saved = DateTime.utc(2026, 10, 16, 22, 8, 0, 500, 999);
      final Map<String, dynamic> body = RemoteSyncSource.encodeState(
        SyncState(
          bookmarks: <SyncBookmark>[
            SyncBookmark(
              itemId: 'slnews-api:1',
              title: 'Story',
              savedAt: saved,
              updatedAt: saved,
            ),
          ],
          reactions: <SyncReaction>[
            SyncReaction(itemId: 'slnews-api:1', updatedAt: saved),
          ],
          follows: <SyncFollow>[
            SyncFollow(targetId: 'team:lal', kind: 'team', updatedAt: saved),
          ],
        ),
      );

      final String encoded = body.toString();
      expect(encoded, contains('2026-10-16T22:08:00.500Z'));
      expect(
        encoded,
        isNot(matches(RegExp(r'\.\d{4,}Z'))),
        reason: 'four or more fractional digits are rejected by the API',
      );
    });
  });
}
