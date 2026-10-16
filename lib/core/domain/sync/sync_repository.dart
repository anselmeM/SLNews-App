import 'package:flutter/foundation.dart';

import 'merge.dart';

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
String? syncTimestamp(DateTime? value) => value?.toUtc().toIso8601String();

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

/// A saved story as the sync API stores it.
///
/// This is a row about a *mobile item*, not a pointer to a PWA content row: the
/// API treats `itemId` as an opaque string and never resolves it.
@immutable
class SyncBookmark implements SyncRow {
  /// Creates a bookmark row.
  const SyncBookmark({
    required this.itemId,
    required this.title,
    required this.updatedAt,
    this.sourceUrl,
    this.imageUrl,
    this.publisher,
    this.publishedAt,
    this.savedAt,
    this.deleted = false,
  });

  /// Creates a tombstone for [itemId]; only the identity and the instant matter.
  const SyncBookmark.deleted({required this.itemId, required this.updatedAt})
    : title = '',
      sourceUrl = null,
      imageUrl = null,
      publisher = null,
      publishedAt = null,
      savedAt = null,
      deleted = true;

  /// Opaque mobile item id (`slnews-api:4821`, `rss:<hex>`, `web:<cuid>`).
  final String itemId;

  /// Headline shown in the saved list. Defaults to the id when the server has
  /// none, because the API requires the field on every bookmark push.
  final String title;

  /// Canonical link to the story, also the future join key with the PWA.
  final String? sourceUrl;

  final String? imageUrl;
  final String? publisher;

  /// When the story was published (not when it was saved).
  final DateTime? publishedAt;

  /// When the reader saved it, or `null` when neither the server nor the row
  /// supplied one — the API defaults `savedAt` to `updatedAt`, and [toJson]
  /// sends that default explicitly so a retry is byte-for-byte stable.
  ///
  /// [fromJson] resolves the same default, because parsing must not produce a
  /// bookmark with no save time at all.
  final DateTime? savedAt;

  @override
  final DateTime updatedAt;

  @override
  final bool deleted;

  @override
  String get id => itemId;

  @override
  String get collection => SyncCollections.bookmarks;

  /// Copy of this row with the given fields replaced.
  SyncBookmark copyWith({
    String? title,
    String? sourceUrl,
    String? imageUrl,
    String? publisher,
    DateTime? publishedAt,
    DateTime? savedAt,
    DateTime? updatedAt,
    bool? deleted,
  }) => SyncBookmark(
    itemId: itemId,
    title: title ?? this.title,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    imageUrl: imageUrl ?? this.imageUrl,
    publisher: publisher ?? this.publisher,
    publishedAt: publishedAt ?? this.publishedAt,
    savedAt: savedAt ?? this.savedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
  );

  /// Wire shape for `POST /sync`. Always ISO-8601 UTC with milliseconds.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'itemId': itemId,
    'title': title,
    'sourceUrl': sourceUrl,
    'imageUrl': imageUrl,
    'publisher': publisher,
    'publishedAt': syncTimestamp(publishedAt),
    // The API defaults `savedAt` to `updatedAt`; sending it explicitly keeps
    // the request body identical on every retry of the same row.
    'savedAt': syncTimestamp(savedAt ?? updatedAt),
    'updatedAt': syncTimestamp(updatedAt),
    'deleted': deleted,
  };

  /// Parses a wire row. Throws [FormatException] when `itemId` is absent, so a
  /// malformed row is skipped instead of poisoning the whole response.
  factory SyncBookmark.fromJson(Map<String, dynamic> json) {
    final String itemId = _requiredString(json['itemId'], 'itemId');
    final DateTime? updatedAt = parseSyncTimestamp(json['updatedAt']);
    final DateTime? savedAt = parseSyncTimestamp(json['savedAt']);
    return SyncBookmark(
      itemId: itemId,
      // The API requires a non-empty title on push, so fall back to the id
      // rather than write back a value the server would reject as 400.
      title: _optionalString(json['title']) ?? itemId,
      sourceUrl: _optionalString(json['sourceUrl']),
      imageUrl: _optionalString(json['imageUrl']),
      publisher: _optionalString(json['publisher']),
      publishedAt: parseSyncTimestamp(json['publishedAt']),
      // The API's documented default: `savedAt` falls back to `updatedAt`.
      savedAt: savedAt ?? updatedAt,
      updatedAt: updatedAt ?? syncEpoch,
      deleted: _flag(json['deleted']),
    );
  }

  /// Equality is the identity key: an `updatedAt` bump must not make the row a
  /// different entry in a map keyed by id.
  @override
  bool operator ==(Object other) =>
      other is SyncBookmark && other.itemId == itemId;

  @override
  int get hashCode => itemId.hashCode;

  @override
  String toString() =>
      'SyncBookmark($itemId, updatedAt: ${syncTimestamp(updatedAt)}'
      '${deleted ? ', deleted' : ''})';
}

/// A like (reaction) on a mobile item.
@immutable
class SyncReaction implements SyncRow {
  /// Creates a reaction row.
  const SyncReaction({
    required this.itemId,
    required this.updatedAt,
    this.kind = 'like',
    this.deleted = false,
  });

  /// Creates a tombstone for [itemId].
  const SyncReaction.deleted({
    required this.itemId,
    required this.updatedAt,
    this.kind = 'like',
  }) : deleted = true;

  /// Opaque mobile item id the reader reacted to.
  final String itemId;

  /// Reaction kind; `like` is the only value the app produces today.
  final String kind;

  @override
  final DateTime updatedAt;

  @override
  final bool deleted;

  @override
  String get id => itemId;

  @override
  String get collection => SyncCollections.reactions;

  /// Copy of this row with the given fields replaced.
  SyncReaction copyWith({String? kind, DateTime? updatedAt, bool? deleted}) =>
      SyncReaction(
        itemId: itemId,
        kind: kind ?? this.kind,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'itemId': itemId,
    'kind': kind,
    'updatedAt': syncTimestamp(updatedAt),
    'deleted': deleted,
  };

  factory SyncReaction.fromJson(Map<String, dynamic> json) => SyncReaction(
    itemId: _requiredString(json['itemId'], 'itemId'),
    kind: _optionalString(json['kind'])?.toLowerCase() ?? 'like',
    updatedAt: parseSyncTimestamp(json['updatedAt']) ?? syncEpoch,
    deleted: _flag(json['deleted']),
  );

  @override
  bool operator ==(Object other) =>
      other is SyncReaction && other.itemId == itemId;

  @override
  int get hashCode => itemId.hashCode;

  @override
  String toString() =>
      'SyncReaction($itemId, $kind, updatedAt: ${syncTimestamp(updatedAt)}'
      '${deleted ? ', deleted' : ''})';
}

/// A subscription to a team, league, city, topic or publisher.
@immutable
class SyncFollow implements SyncRow {
  /// Creates a follow row.
  const SyncFollow({
    required this.targetId,
    required this.kind,
    required this.updatedAt,
    this.label,
    this.deleted = false,
  });

  /// Creates a tombstone for [targetId]; `kind` is still sent because the API
  /// requires it on every follow row.
  const SyncFollow.deleted({
    required this.targetId,
    required this.updatedAt,
    this.kind = 'topic',
  }) : label = null,
       deleted = true;

  /// Follow target id (`team:lal`, `league:spl`, `city:freetown`, ...).
  final String targetId;

  /// `team`, `league`, `location`, `topic` or `publisher`.
  final String kind;

  /// Display label, e.g. `Los Angeles Lakers`.
  final String? label;

  @override
  final DateTime updatedAt;

  @override
  final bool deleted;

  @override
  String get id => targetId;

  @override
  String get collection => SyncCollections.follows;

  /// Copy of this row with the given fields replaced.
  SyncFollow copyWith({
    String? kind,
    String? label,
    DateTime? updatedAt,
    bool? deleted,
  }) => SyncFollow(
    targetId: targetId,
    kind: kind ?? this.kind,
    label: label ?? this.label,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'targetId': targetId,
    'kind': kind,
    'label': label,
    'updatedAt': syncTimestamp(updatedAt),
    'deleted': deleted,
  };

  factory SyncFollow.fromJson(Map<String, dynamic> json) => SyncFollow(
    targetId: _requiredString(json['targetId'], 'targetId'),
    kind: _optionalString(json['kind'])?.toLowerCase() ?? 'topic',
    label: _optionalString(json['label']),
    updatedAt: parseSyncTimestamp(json['updatedAt']) ?? syncEpoch,
    deleted: _flag(json['deleted']),
  );

  @override
  bool operator ==(Object other) =>
      other is SyncFollow && other.targetId == targetId;

  @override
  int get hashCode => targetId.hashCode;

  @override
  String toString() =>
      'SyncFollow($targetId, $kind, updatedAt: ${syncTimestamp(updatedAt)}'
      '${deleted ? ', deleted' : ''})';
}

/// The reader's synchronised state: three collections plus the server clock.
///
/// A tombstone stays in the collection — `bookmarks` holding a deleted row is
/// meaningful, so [activeBookmarks] is what a UI renders while the full list is
/// what gets pushed and pulled.
@immutable
class SyncState {
  /// Wraps the three collections (unmodifiable copies are taken).
  SyncState({
    List<SyncBookmark> bookmarks = const <SyncBookmark>[],
    List<SyncReaction> reactions = const <SyncReaction>[],
    List<SyncFollow> follows = const <SyncFollow>[],
    this.serverTime,
    this.hasMore = false,
  }) : bookmarks = List<SyncBookmark>.unmodifiable(bookmarks),
       reactions = List<SyncReaction>.unmodifiable(reactions),
       follows = List<SyncFollow>.unmodifiable(follows);

  /// Nothing synced and no server clock.
  const SyncState.empty()
    : bookmarks = const <SyncBookmark>[],
      reactions = const <SyncReaction>[],
      follows = const <SyncFollow>[],
      serverTime = null,
      hasMore = false;

  /// Saved stories, tombstones included.
  final List<SyncBookmark> bookmarks;

  /// Likes, tombstones included.
  final List<SyncReaction> reactions;

  /// Subscriptions, tombstones included.
  final List<SyncFollow> follows;

  /// Server clock at the moment the response was produced.
  ///
  /// Kept for skew diagnostics: it is the server's own `updatedAt` values, not
  /// this, that decide last-write-wins.
  final DateTime? serverTime;

  /// Whether the server truncated at least one collection.
  ///
  /// Only a `GET` sets this; it tells the caller to re-issue the pull with
  /// `since = latestUpdatedAt`.
  final bool hasMore;

  /// Bookmarks a UI should render (tombstones filtered out), newest first.
  List<SyncBookmark> get activeBookmarks => <SyncBookmark>[
    for (final SyncBookmark row in bookmarks)
      if (!row.deleted) row,
  ];

  /// Likes a UI should render.
  List<SyncReaction> get activeReactions => <SyncReaction>[
    for (final SyncReaction row in reactions)
      if (!row.deleted) row,
  ];

  /// Subscriptions a UI should render.
  List<SyncFollow> get activeFollows => <SyncFollow>[
    for (final SyncFollow row in follows)
      if (!row.deleted) row,
  ];

  /// Tombstones only, oldest first.
  List<SyncRow> get tombstones => <SyncRow>[
    for (final SyncRow row in _allRows)
      if (row.deleted) row,
  ];

  /// True when all three collections are empty.
  bool get isEmpty => bookmarks.isEmpty && reactions.isEmpty && follows.isEmpty;

  /// Bookmarks keyed by item id, tombstones included.
  Map<String, SyncBookmark> get bookmarksById => <String, SyncBookmark>{
    for (final SyncBookmark row in bookmarks) row.itemId: row,
  };

  /// Reactions keyed by item id, tombstones included.
  Map<String, SyncReaction> get reactionsById => <String, SyncReaction>{
    for (final SyncReaction row in reactions) row.itemId: row,
  };

  /// Follows keyed by target id, tombstones included.
  Map<String, SyncFollow> get followsById => <String, SyncFollow>{
    for (final SyncFollow row in follows) row.targetId: row,
  };

  /// Newest `updatedAt` across every row, tombstones included.
  ///
  /// This is the value a follow-up delta pull passes as `since` when the server
  /// reported `hasMore`.
  DateTime? get latestUpdatedAt {
    DateTime? latest;
    for (final SyncRow row in _allRows) {
      if (latest == null || row.updatedAt.isAfter(latest)) {
        latest = row.updatedAt;
      }
    }
    return latest;
  }

  /// Every row, in collection order.
  List<SyncRow> get rows => _allRows;

  /// Bookmarks with `updatedAt` strictly after [since].
  List<SyncBookmark> bookmarksSince(DateTime since) => <SyncBookmark>[
    for (final SyncBookmark row in bookmarks)
      if (row.updatedAt.isAfter(since)) row,
  ];

  /// Reactions with `updatedAt` strictly after [since].
  List<SyncReaction> reactionsSince(DateTime since) => <SyncReaction>[
    for (final SyncReaction row in reactions)
      if (row.updatedAt.isAfter(since)) row,
  ];

  /// Follows with `updatedAt` strictly after [since].
  List<SyncFollow> followsSince(DateTime since) => <SyncFollow>[
    for (final SyncFollow row in follows)
      if (row.updatedAt.isAfter(since)) row,
  ];

  /// Delta against [since], or `null` when nothing changed after it.
  ///
  /// `null` (rather than an empty state) is the signal the API contract needs:
  /// "no rows to push". The comparison is on instants, never on the rendered
  /// strings, so `...Z` and `...+00:00` sort identically.
  SyncState? deltaSince(DateTime since) {
    final List<SyncBookmark> changedBookmarks = bookmarksSince(since);
    final List<SyncReaction> changedReactions = reactionsSince(since);
    final List<SyncFollow> changedFollows = followsSince(since);
    if (changedBookmarks.isEmpty &&
        changedReactions.isEmpty &&
        changedFollows.isEmpty) {
      return null;
    }
    return SyncState(
      bookmarks: changedBookmarks,
      reactions: changedReactions,
      follows: changedFollows,
      serverTime: serverTime,
      hasMore: hasMore,
    );
  }

  /// Delta of arbitrary rows against [since]; empty when nothing is newer.
  static List<T> rowsWhere<T extends SyncRow>(
    Iterable<T> rows,
    DateTime since,
  ) => <T>[
    for (final T row in rows)
      if (row.updatedAt.isAfter(since)) row,
  ];

  /// Copy with the given collections replaced.
  SyncState copyWith({
    List<SyncBookmark>? bookmarks,
    List<SyncReaction>? reactions,
    List<SyncFollow>? follows,
    DateTime? serverTime,
    bool? hasMore,
  }) => SyncState(
    bookmarks: bookmarks ?? this.bookmarks,
    reactions: reactions ?? this.reactions,
    follows: follows ?? this.follows,
    serverTime: serverTime ?? this.serverTime,
    hasMore: hasMore ?? this.hasMore,
  );

  /// Drops the rows named by [rejections] from this state.
  ///
  /// Used to build the state returned by a push whose server response carried
  /// no `state` object: a rejected row did not apply, so it must not be
  /// reported as the converged value.
  SyncState withoutRows(Iterable<SyncRowRef> rejected) {
    final Set<String> bookmarkIds = <String>{};
    final Set<String> reactionIds = <String>{};
    final Set<String> followIds = <String>{};
    for (final SyncRowRef row in rejected) {
      switch (row.collection) {
        case SyncCollections.bookmarks:
          bookmarkIds.add(row.id);
        case SyncCollections.reactions:
          reactionIds.add(row.id);
        case SyncCollections.follows:
          followIds.add(row.id);
      }
    }
    if (bookmarkIds.isEmpty && reactionIds.isEmpty && followIds.isEmpty) {
      return this;
    }
    return SyncState(
      bookmarks: <SyncBookmark>[
        for (final SyncBookmark row in bookmarks)
          if (!bookmarkIds.contains(row.itemId)) row,
      ],
      reactions: <SyncReaction>[
        for (final SyncReaction row in reactions)
          if (!reactionIds.contains(row.itemId)) row,
      ],
      follows: <SyncFollow>[
        for (final SyncFollow row in follows)
          if (!followIds.contains(row.targetId)) row,
      ],
      serverTime: serverTime,
      hasMore: hasMore,
    );
  }

  /// Union of this state and [remote] under the merge-on-first-sign-in rule
  /// (newer `updatedAt` wins per identity key, ties keep this state's row).
  ///
  /// Delegates to the pure function in `merge.dart` so the rule has exactly one
  /// implementation.
  SyncState mergedWith(SyncState remote) => mergeSyncStates(this, remote);

  /// All rows in collection order.
  List<SyncRow> get _allRows => <SyncRow>[
    ...bookmarks,
    ...reactions,
    ...follows,
  ];

  @override
  String toString() =>
      'SyncState(bookmarks: ${bookmarks.length}, reactions: ${reactions.length}, '
      'follows: ${follows.length}, serverTime: ${syncTimestamp(serverTime)})';
}

/// One row the server refused to apply.
///
/// Rejections are *not* failures: the rest of the batch still applies and the
/// client simply keeps the server's value for that row.
@immutable
class SyncRejection implements SyncRowRef {
  /// Creates a rejection of [id] in [collection] with [reason].
  const SyncRejection({
    required this.collection,
    required this.id,
    required this.reason,
  });

  /// `bookmarks`, `reactions` or `follows`.
  @override
  final String collection;

  /// Identity key of the rejected row (`itemId` or `targetId`).
  @override
  final String id;

  /// Server-provided reason, e.g. `stale`.
  final String reason;

  /// Parses one `rejected[]` entry.
  ///
  /// The contract labels the identity `itemId`; `targetId` and a bare `id` are
  /// accepted too so a follows rejection is not silently dropped.
  factory SyncRejection.fromJson(Map<String, dynamic> json) => SyncRejection(
    collection: _optionalString(json['collection']) ?? '',
    id:
        _optionalString(json['itemId']) ??
        _optionalString(json['targetId']) ??
        _optionalString(json['id']) ??
        '',
    reason: _optionalString(json['reason']) ?? 'rejected',
  );

  @override
  bool operator ==(Object other) =>
      other is SyncRejection &&
      other.collection == collection &&
      other.id == id &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(collection, id, reason);

  @override
  String toString() => 'SyncRejection($collection/$id: $reason)';
}

/// A row addressed by collection and id, the pair a rejection reports.
abstract interface class SyncRowRef {
  /// `bookmarks`, `reactions` or `follows`.
  String get collection;

  /// Identity key within [collection].
  String get id;
}

/// Per-collection count of rows the server applied.
@immutable
class SyncApplied {
  /// Wraps the three counts.
  const SyncApplied({this.bookmarks = 0, this.reactions = 0, this.follows = 0});

  /// Nothing applied.
  static const SyncApplied none = SyncApplied();

  final int bookmarks;
  final int reactions;
  final int follows;

  /// Total rows applied across the batch.
  int get total => bookmarks + reactions + follows;

  /// Count for [collection].
  int forCollection(String collection) => switch (collection) {
    SyncCollections.bookmarks => bookmarks,
    SyncCollections.reactions => reactions,
    SyncCollections.follows => follows,
    _ => 0,
  };

  /// Parses the `applied` object; a missing collection counts as zero.
  factory SyncApplied.fromJson(Map<String, dynamic> json) => SyncApplied(
    bookmarks: _count(json[SyncCollections.bookmarks]),
    reactions: _count(json[SyncCollections.reactions]),
    follows: _count(json[SyncCollections.follows]),
  );

  @override
  bool operator ==(Object other) =>
      other is SyncApplied &&
      other.bookmarks == bookmarks &&
      other.reactions == reactions &&
      other.follows == follows;

  @override
  int get hashCode => Object.hash(bookmarks, reactions, follows);

  @override
  String toString() =>
      'SyncApplied(bookmarks: $bookmarks, reactions: $reactions, follows: $follows)';

  static int _count(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }
}

/// Outcome of a push: what applied, what was refused, and the converged state.
@immutable
class SyncResult {
  /// Wraps a push outcome.
  ///
  /// [state] is optional here but the [state] field is not: a push that never
  /// reached the server still reports the rows the caller sent, so a caller
  /// never has to handle "no state at all".
  const SyncResult({
    this.applied = SyncApplied.none,
    this.rejected = const <SyncRejection>[],
    SyncState? state,
    this.failure,
  }) : state = state ?? const SyncState.empty();

  /// A push that never reached the server.
  factory SyncResult.failed(SyncFailure failure, {SyncState? local}) =>
      SyncResult(state: local, failure: failure);

  /// Per-collection applied counts.
  final SyncApplied applied;

  /// Rows the server refused; each carries its own reason. Not an error.
  final List<SyncRejection> rejected;

  /// `true` when the batch reached the server and was answered with `200`.
  ///
  /// A run with rejections is still successful — the contract is explicit that
  /// rejections are reported per row and are not failures.
  bool get ok => failure == null;

  /// Why the push did not apply, or `null` on success.
  final SyncFailure? failure;

  /// Best available server view after the push; never `null`.
  ///
  /// When the server omitted `state`, this is the rows that were sent minus the
  /// rejected ones, which is the converged value the client can act on.
  final SyncState state;

  /// Copy with the given fields replaced.
  SyncResult copyWith({
    SyncApplied? applied,
    List<SyncRejection>? rejected,
    SyncState? state,
    SyncFailure? failure,
  }) => SyncResult(
    applied: applied ?? this.applied,
    rejected: rejected ?? this.rejected,
    state: state ?? this.state,
    failure: failure ?? this.failure,
  );

  @override
  String toString() =>
      'SyncResult(applied: $applied, rejected: ${rejected.length}, '
      'failure: $failure)';
}

/// Why a sync request did not apply, as a typed value rather than an exception.
///
/// The API contract's status codes map one-to-one onto these cases so callers
/// never branch on an int, and so nothing has to be thrown at the UI.
@immutable
sealed class SyncFailure {
  /// Const base for the sealed hierarchy.
  const SyncFailure(this.message);

  /// Human-readable cause. Never contains credentials.
  final String message;

  /// Explains the failure in one line for a caller's log.
  String get kind;

  /// The session token was missing, expired or unverifiable (`401`).
  static SyncFailure unauthorized(String message) => SyncUnauthorized(message);

  /// Per-user rate limit hit (`429`); [retryAfter] is the server's hint.
  static SyncFailure rateLimited({Duration? retryAfter, String? message}) =>
      SyncRateLimited(retryAfter: retryAfter, message: message);

  /// Request refused as malformed or oversized (`400`/`413`) — retrying the
  /// same payload unchanged cannot succeed.
  static SyncFailure rejected({int? statusCode, String? message}) =>
      SyncRejected(statusCode: statusCode, message: message);

  /// Transport, timeout, TLS or server fault (`5xx`): retry later.
  static SyncFailure unavailable(String message, {int? statusCode}) =>
      SyncUnavailable(message, statusCode: statusCode);

  @override
  String toString() => 'SyncFailure.$kind: $message';
}

/// `401` — the client is not usable until the session is refreshed.
final class SyncUnauthorized extends SyncFailure {
  /// Creates an unauthorized failure.
  const SyncUnauthorized(super.message);

  @override
  String get kind => 'unauthorized';
}

/// `429` — back off; [retryAfter] is the parsed `Retry-After` header.
final class SyncRateLimited extends SyncFailure {
  /// Creates a rate-limit failure.
  const SyncRateLimited({this.retryAfter, String? message})
    : super(message ?? 'rate limited');

  /// Server-suggested wait, when the header was present and parseable.
  final Duration? retryAfter;

  @override
  String get kind => 'rateLimited';

  @override
  String toString() =>
      'SyncFailure.rateLimited: $message'
      '${retryAfter == null ? '' : ' (retry after ${retryAfter!.inSeconds}s)'}';
}

/// `400`/`413` — the payload itself is wrong.
final class SyncRejected extends SyncFailure {
  /// Creates a payload-rejection failure.
  const SyncRejected({this.statusCode, String? message})
    : super(message ?? 'payload rejected');

  /// HTTP status that produced this failure, when known.
  final int? statusCode;

  @override
  String get kind => 'rejected';
}

/// Transport fault, timeout, or `5xx`.
final class SyncUnavailable extends SyncFailure {
  /// Creates an availability failure.
  const SyncUnavailable(super.message, {this.statusCode});

  /// HTTP status when the server answered with a fault; `null` for timeouts.
  final int? statusCode;

  @override
  String get kind => 'unavailable';
}

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
