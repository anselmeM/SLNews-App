import 'package:flutter/foundation.dart';

import 'merge.dart';

part 'sync_bookmark.dart';
part 'sync_reaction.dart';
part 'sync_follow.dart';
part 'sync_state.dart';
part 'sync_result.dart';

/// The three reader-owned collections the mobile sync API carries.
///
/// The wire names are frozen by `docs/SYNC-API.md`; every request/response key
/// and every `rejected[].collection` value comes from here so a rename cannot
/// drift between the source and the contract.
abstract final class SyncCollections {
  /// Saved stories: keyed by `itemId`, carrying enough metadata to render a
  /// saved list offline.
  static const String bookmarks = 'bookmarks';

  /// Likes: keyed by `itemId`, `kind` is `like` today.
  static const String reactions = 'reactions';

  /// Subscriptions: keyed by `targetId` (`team:lal`, `city:freetown`, ...).
  static const String follows = 'follows';

  /// All three, in the order the API documents them.
  static const List<String> all = <String>[bookmarks, reactions, follows];
}

/// One row of synchronised reader state.
///
/// Rows are identified by [id] and ordered by [updatedAt]; everything else is a
/// snapshot for rendering offline. Deletions are not removals — they are the
/// same row with `deleted: true` (a tombstone) so a stale device cannot
/// resurrect it.
abstract interface class SyncRow {
  /// Concurrency key: the instant the reader acted, in UTC.
  DateTime get updatedAt;

  /// `true` for a tombstone. Tombstones are pushed and pulled like live rows.
  bool get deleted;

  /// Stable identity within its collection (`itemId` or `targetId`).
  String get id;

  /// Wire name of the collection this row belongs to.
  String get collection;
}

/// Timestamp used when a row arrives without a parseable `updatedAt`.
///
/// Epoch zero rather than `now()`: a malformed timestamp must never be able to
/// win last-write-wins against a real one, and the value is obvious in logs.
final DateTime syncEpoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// Serialises [value] as ISO-8601 UTC with milliseconds — the only timestamp
/// shape the API accepts (`2026-10-16T05:00:00.000Z`).
///
/// Dart's `toIso8601String()` appends **six** fractional digits whenever the
/// instant carries microseconds, which an Android clock routinely does. The
/// API's validator accepts one to three digits, so an untruncated value is a
/// `400` on every push and every delta pull — which is how a device showed
/// "Sync failed — rejected" while the server-side suite passed: that suite builds
/// its timestamps with JavaScript's `toISOString()`, which is milliseconds.
String? syncTimestamp(DateTime? value) {
  if (value == null) return null;
  final DateTime utc = value.toUtc();
  if (utc.microsecond == 0) return utc.toIso8601String();
  return DateTime.utc(
    utc.year,
    utc.month,
    utc.day,
    utc.hour,
    utc.minute,
    utc.second,
    utc.millisecond,
  ).toIso8601String();
}

/// Parses a wire timestamp tolerantly.
///
/// Accepts ISO-8601 (any offset, including none — assumed UTC), `DateTime`, and
/// epoch seconds or milliseconds. Returns `null` when nothing parses; callers
/// decide whether that is a missing value or a degraded default.
DateTime? parseSyncTimestamp(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  if (value is num) return _fromEpoch(value);
  if (value is! String) return null;
  final String raw = value.trim();
  if (raw.isEmpty) return null;
  final int? epoch = int.tryParse(raw);
  if (epoch != null) return _fromEpoch(epoch);
  return DateTime.tryParse(raw)?.toUtc();
}

/// Epoch seconds and milliseconds are both seen in the wild; the magnitude
/// separates them (1e11 ms is 1973, 1e11 s is year 5138).
DateTime _fromEpoch(num value) {
  final int raw = value.toInt();
  final int millis = raw.abs() < 100000000000 ? raw * 1000 : raw;
  return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
}

/// Reads a string field, returning `null` for blank or non-string values.
String? _optionalString(Object? value) {
  if (value is String) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is num) return '$value';
  return null;
}

/// Reads a required identity field. Throws [FormatException] when absent, which
/// callers turn into "skip this row" rather than a failed request.
String _requiredString(Object? value, String field) {
  final String? text = _optionalString(value);
  if (text == null) {
    throw FormatException('sync row is missing "$field"');
  }
  return text;
}

/// `true` only for a literal boolean `true`; a missing flag means "live row".
bool _flag(Object? value) => value is bool && value;

/// Reader-state synchronisation with the SLNews mobile sync API.
///
/// A build with no `SLNEWS_SYNC_URL` reports [isConfigured] `false` and behaves
/// exactly like today's local-only app: [pull] and [push] are inert.
abstract interface class SyncRepository {
  /// Whether a sync endpoint is configured for this build.
  bool get isConfigured;

  /// Restores any state the implementation needs. Must not throw.
  ///
  /// A no-op for the HTTP implementation — it exists for symmetry with the
  /// other repositories, whose state is hydrated from local storage.
  Future<void> initialize();

  /// Reads the server state, or only the rows newer than [since].
  ///
  /// Never throws: an outage degrades to an empty state and the caller keeps
  /// serving local content. [SyncState.latestUpdatedAt] is the `since` to pass
  /// on the next call when the response was truncated (`hasMore`).
  Future<SyncState> pull({DateTime? since});

  /// Sends [local] to the server and returns what applied.
  ///
  /// Never throws: a failure comes back as [SyncResult.failure], and the rows
  /// that did not make it are retried on the next call.
  Future<SyncResult> push(SyncState local);
}
