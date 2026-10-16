import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../local/preferences_store.dart';
import '../../domain/sync/sync_repository.dart';

/// Remembers **when** each piece of local reader state changed.
///
/// Last-write-wins needs a per-row timestamp, and the app's existing local state
/// is only a set of ids: without this ledger every push would have to claim
/// "changed just now", which would let an old phone overwrite a change made on
/// the web five minutes ago. The ledger also keeps local tombstones so a delete
/// performed offline is not undone by the next pull.
///
/// Stored as one JSON document under a single preferences key: it is small (three
/// maps of id → instant), and a single key means a partial write cannot leave the
/// three collections disagreeing about their version.
class LocalSyncLedger {
  /// Creates a ledger over [store].
  LocalSyncLedger(this._store);

  /// Preferences key holding the whole document.
  static const String storageKey = 'sync.ledger.v1';

  final PreferencesStore _store;

  /// Change instants per collection, tombstoned rows included.
  Map<String, DateTime> updatedAt(String collection) {
    final Map<String, dynamic> section = _read()[collection] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return <String, DateTime>{
      for (final MapEntry<String, dynamic> entry in section.entries)
        if (parseSyncTimestamp(entry.value) case final DateTime at) entry.key: at,
    };
  }

  /// Ids deleted locally and not yet acknowledged by the server.
  Set<String> deleted(String collection) {
    final Map<String, dynamic> section = _read()['deleted'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final Map<String, dynamic> forCollection = section[collection] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return forCollection.keys.toSet();
  }

  /// Records that [id] changed at [at]; a tombstone is recorded when [deleted].
  Future<void> record(
    String collection,
    String id,
    DateTime at, {
    bool deleted = false,
  }) async {
    final Map<String, dynamic> document = _read();
    final Map<String, dynamic> rows = _section(document, collection);
    rows[id] = at.toUtc().toIso8601String();
    if (deleted) {
      _section(_section(document, 'deleted'), collection)[id] = true;
    } else {
      _tombstonesOf(document, collection).remove(id);
    }
    await _write(document);
  }

  /// Records the same instant for many ids at once, used when local rows are
  /// first merged and their real change time is unknown.
  Future<void> recordAll(
    String collection,
    Iterable<String> ids,
    DateTime at, {
    Set<String> tombstones = const <String>{},
  }) async {
    final Map<String, dynamic> document = _read();
    final Map<String, dynamic> rows = _section(document, collection);
    final String iso = at.toUtc().toIso8601String();
    for (final String id in ids) {
      rows[id] = iso;
    }
    final Map<String, dynamic> deletedSection = _section(document, 'deleted');
    final Map<String, dynamic> collectionTombstones = _section(deletedSection, collection);
    for (final String id in ids) {
      if (tombstones.contains(id)) {
        collectionTombstones[id] = true;
      } else {
        collectionTombstones.remove(id);
      }
    }
    await _write(document);
  }

  /// Records many ids with individual instants in one write.
  ///
  /// Used after a merge, where each row carries the server's own `updatedAt`;
  /// writing per row would mean one JSON encode per bookmark.
  Future<void> recordBatch(
    String collection,
    Map<String, DateTime> instants, {
    Set<String> tombstones = const <String>{},
  }) async {
    if (instants.isEmpty && tombstones.isEmpty) return;
    final Map<String, dynamic> document = _read();
    final Map<String, dynamic> rows = _section(document, collection);
    for (final MapEntry<String, DateTime> entry in instants.entries) {
      rows[entry.key] = entry.value.toUtc().toIso8601String();
    }
    final Map<String, dynamic> collectionTombstones = _section(_section(document, 'deleted'), collection);
    for (final String id in tombstones) {
      collectionTombstones[id] = true;
    }
    for (final String id in instants.keys) {
      if (!tombstones.contains(id)) collectionTombstones.remove(id);
    }
    await _write(document);
  }

  /// Drops every recorded row for [collection] (used by tests and sign-out).
  Future<void> clear(String collection) async {
    final Map<String, dynamic> document = _read();
    document.remove(collection);
    _section(document, 'deleted').remove(collection);
    await _write(document);
  }

  /// The instant recorded for [id], or `null` when it was never recorded.
  DateTime? at(String collection, String id) => updatedAt(collection)[id];

  /// True when [id] is locally deleted.
  bool isDeleted(String collection, String id) => deleted(collection).contains(id);

  Map<String, dynamic> _read() {
    final String? raw = _store.string(storageKey);
    if (raw == null || raw.trim().isEmpty) return <String, dynamic>{};
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on FormatException catch (error) {
      // A corrupt ledger must never block the reader; losing timestamps makes
      // the next merge treat local rows as "just changed", which is the same
      // behaviour as a first merge.
      debugPrint('LocalSyncLedger: ignoring corrupt ledger ($error)');
      return <String, dynamic>{};
    }
  }

  Future<void> _write(Map<String, dynamic> document) async {
    await _store.putString(storageKey, jsonEncode(document));
  }

  static Map<String, dynamic> _section(Map<String, dynamic> document, String key) {
    final Object? existing = document[key];
    if (existing is Map<String, dynamic>) return existing;
    final Map<String, dynamic> created = <String, dynamic>{};
    document[key] = created;
    return created;
  }

  static Map<String, dynamic> _tombstonesOf(Map<String, dynamic> document, String collection) =>
      _section(_section(document, 'deleted'), collection);
}
