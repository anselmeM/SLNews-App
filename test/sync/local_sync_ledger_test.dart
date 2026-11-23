import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/data/sync/local_sync_ledger.dart';

/// The ledger is what makes last-write-wins safe: without a per-row instant an
/// old phone would claim "changed just now" on every push and clobber the web.
/// These cases pin the storage contract, the tombstones and the corrupt-ledger
/// fallback that keeps a bad document from blocking the reader.
void main() {
  final DateTime at1 = DateTime.utc(2026, 10, 16, 4);
  final DateTime at2 = DateTime.utc(2026, 10, 16, 5, 30);

  late InMemoryPreferencesStore store;
  late LocalSyncLedger ledger;

  setUp(() {
    store = InMemoryPreferencesStore();
    ledger = LocalSyncLedger(store);
  });

  test('an empty or missing document reads as empty', () {
    expect(ledger.updatedAt('bookmarks'), isEmpty);
    expect(ledger.deleted('bookmarks'), isEmpty);
    expect(ledger.at('bookmarks', 'b1'), isNull);
    expect(ledger.isDeleted('bookmarks', 'b1'), isFalse);
  });

  test('record stores the instant in UTC and reads it back', () async {
    await ledger.record('bookmarks', 'b1', at1.toLocal());

    expect(ledger.at('bookmarks', 'b1'), at1);
    expect(ledger.updatedAt('bookmarks').keys, <String>['b1']);
    // Stored as an ISO string under one document key.
    final Map<String, dynamic> document = jsonDecode(
      store.string(LocalSyncLedger.storageKeyFor('anonymous'))!,
    ) as Map<String, dynamic>;
    expect(document['bookmarks'], <String, dynamic>{
      'b1': '2026-10-16T04:00:00.000Z',
    });
  });

  test(
    'a tombstone is recorded for a delete and cleared by a re-add',
    () async {
      await ledger.record('bookmarks', 'b1', at1, deleted: true);
      expect(ledger.isDeleted('bookmarks', 'b1'), isTrue);
      expect(ledger.deleted('bookmarks'), <String>{'b1'});

      await ledger.record('bookmarks', 'b1', at2);
      expect(ledger.isDeleted('bookmarks', 'b1'), isFalse);
      expect(ledger.at('bookmarks', 'b1'), at2);
    },
  );

  test('recordAll applies one instant and the given tombstones', () async {
    await ledger.recordAll(
      'follows',
      <String>['f1', 'f2', 'f3'],
      at1,
      tombstones: <String>{'f2'},
    );

    expect(ledger.updatedAt('follows').keys.toSet(), <String>{
      'f1',
      'f2',
      'f3',
    });
    expect(ledger.at('follows', 'f1'), at1);
    expect(ledger.deleted('follows'), <String>{'f2'});

    // A later recordAll without the tombstone clears it for the ids it names,
    // and leaves untouched ids alone.
    await ledger.recordAll('follows', <String>['f2'], at2);
    expect(ledger.isDeleted('follows', 'f2'), isFalse);
    expect(ledger.at('follows', 'f2'), at2);
    expect(ledger.at('follows', 'f1'), at1);
  });

  test('recordBatch keeps each row its own instant', () async {
    await ledger.recordBatch(
      'reactions',
      <String, DateTime>{'r1': at1, 'r2': at2},
      tombstones: <String>{'r2'},
    );

    expect(ledger.at('reactions', 'r1'), at1);
    expect(ledger.at('reactions', 'r2'), at2);
    expect(ledger.deleted('reactions'), <String>{'r2'});

    // An empty batch is a no-op: no document is written for nothing.
    final String? before = store.string(
      LocalSyncLedger.storageKeyFor('anonymous'),
    );
    await ledger.recordBatch('reactions', const <String, DateTime>{});
    expect(store.string(LocalSyncLedger.storageKeyFor('anonymous')), before);
  });

  test('clear removes one collection and leaves the others', () async {
    await ledger.record('bookmarks', 'b1', at1, deleted: true);
    await ledger.record('follows', 'f1', at1);

    await ledger.clear('bookmarks');

    expect(ledger.updatedAt('bookmarks'), isEmpty);
    expect(ledger.deleted('bookmarks'), isEmpty);
    expect(ledger.at('follows', 'f1'), at1);
  });

  test('writes survive a new ledger over the same store', () async {
    await ledger.record('bookmarks', 'b1', at1);
    final LocalSyncLedger reopened = LocalSyncLedger(store);
    expect(reopened.at('bookmarks', 'b1'), at1);
  });

  test('a corrupt document is ignored and the next write recovers', () async {
    await store.putString(LocalSyncLedger.storageKey, '{not json');

    expect(ledger.updatedAt('bookmarks'), isEmpty);
    expect(ledger.deleted('bookmarks'), isEmpty);

    await ledger.record('bookmarks', 'b1', at1);
    expect(ledger.at('bookmarks', 'b1'), at1);
  });

  test('a non-map JSON document is treated as empty', () async {
    await store.putString(LocalSyncLedger.storageKey, '[1, 2, 3]');
    expect(ledger.updatedAt('bookmarks'), isEmpty);
  });

  test('unparseable row values are skipped, not fatal', () async {
    await store.putString(
      LocalSyncLedger.storageKey,
      jsonEncode(<String, dynamic>{
        'bookmarks': <String, dynamic>{
          'good': at1.toIso8601String(),
          'bad': true,
          'junk': 'not-a-date',
        },
      }),
    );

    expect(ledger.updatedAt('bookmarks'), <String, DateTime>{'good': at1});
  });

  test('epoch row values are accepted as seconds or milliseconds', () async {
    // The wire accepts both (magnitude separates them) and the ledger reuses
    // that parser, so a hand-written or migrated document still loads.
    final int seconds = at1.millisecondsSinceEpoch ~/ 1000;
    await store.putString(
      LocalSyncLedger.storageKey,
      jsonEncode(<String, dynamic>{
        'bookmarks': <String, dynamic>{
          's': seconds,
          'ms': at2.millisecondsSinceEpoch,
        },
      }),
    );

    expect(ledger.at('bookmarks', 's'), at1);
    expect(ledger.at('bookmarks', 'ms'), at2);
  });
}
