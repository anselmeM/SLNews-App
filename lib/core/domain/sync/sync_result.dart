part of 'sync_repository.dart';

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
