import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/sync/sync_repository.dart';
import '../sources/api_client.dart';
import 'default_sync_repository.dart';
import 'sync_api_config.dart';

/// `GET`/`POST /api/mobile/v1/sync` over [ApiClient].
///
/// Nothing here throws. Every transport, status and parse problem becomes a
/// typed [SyncFailure] (or an empty [SyncState] on a pull) plus a `debugPrint`,
/// exactly like the other sources in this layer: a sync outage must never be
/// able to break the reader.
///
/// Authentication is not this class's job. The session token is attached by
/// [ApiClient] to allow-listed hosts only, so the composition root must list
/// [SyncApiConfig.host] in `authTokenHosts`; without that the request is
/// anonymous and the API answers `401`.
class RemoteSyncSource implements SyncApiSource {
  /// Creates a source over the injected config and HTTP client.
  ///
  /// Both are held privately: the config carries the origin and the client
  /// carries the session token, and neither is useful to a caller that only
  /// wants to sync.
  RemoteSyncSource({required this._config, required this._api});

  /// Header the API sets on a `429`, e.g. `Retry-After: 540`.
  static const String retryAfterHeader = 'retry-after';

  final SyncApiConfig _config;
  final ApiClient _api;

  SyncFailure? _lastFailure;

  @override
  bool get isConfigured => _config.isConfigured;

  /// Why the most recent `pull` or `push` degraded, or `null` after a success.
  ///
  /// A pull reports an empty state rather than throwing, so this is how a caller
  /// (or the composition root's diagnostics) can tell "nothing to sync" from
  /// "the server answered 429": data is a value, the reason is state.
  SyncFailure? get lastFailure => _lastFailure;

  /// Reads the full server state, or only the rows with `updatedAt > since`.
  ///
  /// Returns `SyncState.empty()` — with [SyncState.hasMore] `false` — on every
  /// degraded path, so a caller can always render local content.
  @override
  Future<SyncState> pull({DateTime? since}) async {
    if (!_config.isConfigured) {
      // An unconfigured build must not touch the network at all.
      _lastFailure = SyncFailure.unavailable(
        'sync is not configured for this build',
      );
      return const SyncState.empty();
    }

    final Map<String, dynamic> query = <String, dynamic>{
      'limit': _config.limit,
      if (since != null) 'since': syncTimestamp(since),
    };

    try {
      final ApiResponse response = await _api.get(
        _config.endpoint,
        query: query,
      );
      final int? status = response.statusCode;
      if (status != null && status != 200) {
        // Only reachable when a caller tunes `validateStatus` to stop throwing
        // on non-2xx; the default Dio configuration raises instead.
        return _degraded(failureForResponse(response));
      }
      if (!_isJson(response.data)) {
        return _degraded(SyncFailure.unavailable('sync response was not JSON'));
      }
      _lastFailure = null;
      return parseState(_map(response.data));
    } catch (error) {
      return _degraded(failureFor(error));
    }
  }

  /// Sends the batched push and returns what the server applied.
  ///
  /// Rejections are reported in [SyncResult.rejected] and are **not** failures:
  /// `ok` stays `true` and the rest of the batch still applied.
  @override
  Future<SyncResult> push(SyncState local) async {
    if (!_config.isConfigured) {
      return SyncResult.failed(
        _remember(
          SyncFailure.unavailable('sync is not configured for this build'),
        ),
        local: local,
      );
    }

    try {
      // `postJson` is the client's contract for a JSON body; a non-2xx answer
      // arrives as an `ApiException` carrying the status, and is mapped below.
      final Object? payload = await _api.postJson(
        _config.endpoint,
        encodeState(local),
      );
      if (!_isJson(payload)) {
        return SyncResult.failed(
          _remember(SyncFailure.unavailable('sync response was not JSON')),
          local: local,
        );
      }
      _lastFailure = null;
      return parseResult(_map(payload), sent: local);
    } catch (error) {
      return SyncResult.failed(_remember(failureFor(error)), local: local);
    }
  }

  /// The request body for a push.
  ///
  /// Always carries all three collections (empty arrays included): the API
  /// defaults a missing array to empty, but sending them explicitly keeps the
  /// request shape identical to the contract's example and keeps the body
  /// byte-for-byte stable for a retry.
  static Map<String, dynamic> encodeState(SyncState state) => <String, dynamic>{
    SyncCollections.bookmarks: state.bookmarks
        .map((SyncBookmark row) => row.toJson())
        .toList(growable: false),
    SyncCollections.reactions: state.reactions
        .map((SyncReaction row) => row.toJson())
        .toList(growable: false),
    SyncCollections.follows: state.follows
        .map((SyncFollow row) => row.toJson())
        .toList(growable: false),
  };

  /// Parses the `GET` response body.
  ///
  /// A collection that is absent, `null` or not a list is empty; a row missing
  /// its identity key is skipped with a log rather than failing the response.
  /// A missing `serverTime` falls back to [fallbackServerTime], then to the
  /// newest `updatedAt` received, then to the local clock, so a caller always
  /// has a cursor it can store.
  static SyncState parseState(
    Map<String, dynamic> json, {
    DateTime? fallbackServerTime,
  }) {
    final SyncState parsed = SyncState(
      bookmarks: _rows(json[SyncCollections.bookmarks], _bookmark),
      reactions: _rows(json[SyncCollections.reactions], _reaction),
      follows: _rows(json[SyncCollections.follows], _follow),
      serverTime: parseSyncTimestamp(json['serverTime']),
      hasMore: _bool(json['hasMore']),
    );
    if (parsed.serverTime != null) return parsed;
    return parsed.copyWith(
      serverTime:
          fallbackServerTime ??
          parsed.latestUpdatedAt ??
          DateTime.now().toUtc(),
    );
  }

  /// Parses the `POST` response body into a [SyncResult].
  ///
  /// [sent] is the state that was pushed. It is only used when the server omits
  /// `state`: the response is then the sent rows minus the rejected ones, which
  /// is still the best available converged view and never a lie.
  static SyncResult parseResult(
    Map<String, dynamic> json, {
    SyncState sent = const SyncState.empty(),
  }) {
    final List<SyncRejection> rejected = <SyncRejection>[
      for (final Map<String, dynamic> row in _objects(json['rejected']))
        SyncRejection.fromJson(row),
    ];

    final Object? rawState = json['state'];
    // `serverTime` sits outside `state` in the push response; keep the clock the
    // caller already had when the response carries none, so the cursor a caller
    // stores never moves backwards.
    final DateTime? serverTime =
        parseSyncTimestamp(json['serverTime']) ?? sent.serverTime;
    final SyncState? serverState = rawState is Map
        ? parseState(_map(rawState), fallbackServerTime: serverTime)
        : null;
    SyncState state = serverState ?? sent.withoutRows(rejected);
    if (serverState == null && state.serverTime == null && serverTime != null) {
      state = state.copyWith(serverTime: serverTime);
    }
    if (rawState != null && serverState == null) {
      debugPrint(
        'RemoteSyncSource: "state" was not an object, using the sent rows',
      );
    }

    return SyncResult(
      applied: SyncApplied.fromJson(_map(json['applied'])),
      rejected: rejected,
      state: state,
    );
  }

  /// Maps a thrown fault onto the contract's status codes.
  ///
  /// Kept public and static so a caller (or test) can assert the mapping without
  /// standing up a socket. [retryAfter] is the raw `Retry-After` header of the
  /// failing response, when one was available: that header is what turns "retry
  /// later" into a concrete back-off.
  static SyncFailure failureFor(Object error, {String? retryAfter}) {
    if (error is SyncFailure) return error;
    if (error is ApiException) {
      final int? status = error.statusCode;
      return switch (status) {
        401 => SyncFailure.unauthorized(error.message),
        429 => SyncFailure.rateLimited(
          // The header rides on the exception when the failure was thrown, so a
          // live 429 yields a real back-off and not just "rate limited".
          retryAfter: parseRetryAfter(
            retryAfter ?? error.responseHeaders?[retryAfterHeader],
          ),
        ),
        // 400 and 413 are the payload's fault: retrying it unchanged cannot
        // succeed, which is exactly what distinguishes them from `unavailable`.
        400 ||
        413 => SyncFailure.rejected(statusCode: status, message: error.message),
        _ => SyncFailure.unavailable(error.message, statusCode: status),
      };
    }
    return SyncFailure.unavailable('$error');
  }

  /// Maps a response that arrived without throwing (a tuned `validateStatus`).
  static SyncFailure failureForResponse(ApiResponse response) {
    final int? status = response.statusCode;
    return switch (status) {
      401 => SyncFailure.unauthorized('session token rejected'),
      429 => SyncFailure.rateLimited(
        retryAfter: parseRetryAfter(response.headers[retryAfterHeader]),
      ),
      400 ||
      413 => SyncFailure.rejected(statusCode: status, message: 'HTTP $status'),
      _ => SyncFailure.unavailable(
        'HTTP ${status ?? 'no response'}',
        statusCode: status,
      ),
    };
  }

  /// Parses a `Retry-After` value: delta-seconds today, an HTTP-date tolerated.
  ///
  /// Exposed because `ApiClient` surfaces response headers only on its own
  /// typed response: a `429` that arrives as a thrown `ApiException` carries the
  /// status but not the header, so a caller that wants a concrete back-off must
  /// read it from the response it can still see (or from the `DioException`),
  /// then parse it here.
  static Duration? parseRetryAfter(String? raw) {
    if (raw == null) return null;
    final String value = raw.trim();
    if (value.isEmpty) return null;
    final int? seconds = int.tryParse(value);
    if (seconds != null) {
      return Duration(seconds: seconds < 0 ? 0 : seconds);
    }
    final DateTime? when = DateTime.tryParse(value);
    if (when == null) return null;
    final Duration wait = when.toUtc().difference(DateTime.now().toUtc());
    return wait.isNegative ? Duration.zero : wait;
  }

  /// Logs [failure], remembers it, and reports the empty state a pull must
  /// return instead of throwing.
  SyncState _degraded(SyncFailure failure) {
    debugPrint(
      'RemoteSyncSource: pull degraded (${failure.kind}: ${failure.message})',
    );
    _lastFailure = failure;
    return const SyncState.empty();
  }

  /// Logs [failure] and remembers it for [lastFailure].
  SyncFailure _remember(SyncFailure failure) {
    debugPrint(
      'RemoteSyncSource: push degraded (${failure.kind}: ${failure.message})',
    );
    _lastFailure = failure;
    return failure;
  }

  /// A JSON object response is either a decoded map or a JSON-encoded string
  /// (the server did not advertise a JSON content type).
  static bool _isJson(Object? data) {
    if (data is Map) return true;
    if (data is String && data.trim().isNotEmpty) {
      try {
        return jsonDecode(data) is Map;
      } on FormatException {
        return false;
      }
    }
    return false;
  }

  static List<T> _rows<T>(
    Object? raw,
    T? Function(Map<String, dynamic> json) build,
  ) {
    final List<T> rows = <T>[];
    for (final Map<String, dynamic> json in _objects(raw)) {
      final T? row = build(json);
      if (row != null) rows.add(row);
    }
    return rows;
  }

  static List<Map<String, dynamic>> _objects(Object? raw) =>
      <Map<String, dynamic>>[
        for (final Object? entry in _list(raw))
          if (entry is Map) _map(entry),
      ];

  static List<Object?> _list(Object? raw) =>
      raw is List ? raw : const <Object?>[];

  static Map<String, dynamic> _map(Object? raw) {
    if (raw is String) {
      try {
        return _map(jsonDecode(raw));
      } on FormatException {
        return <String, dynamic>{};
      }
    }
    if (raw is! Map) return <String, dynamic>{};
    final Map<String, dynamic> json = <String, dynamic>{};
    raw.forEach((Object? key, Object? value) {
      if (key is String) json[key] = value;
    });
    return json;
  }

  static bool _bool(Object? raw) => raw is bool && raw;

  static SyncBookmark? _bookmark(Map<String, dynamic> json) =>
      _tryParse(() => SyncBookmark.fromJson(json), SyncCollections.bookmarks);

  static SyncReaction? _reaction(Map<String, dynamic> json) =>
      _tryParse(() => SyncReaction.fromJson(json), SyncCollections.reactions);

  static SyncFollow? _follow(Map<String, dynamic> json) =>
      _tryParse(() => SyncFollow.fromJson(json), SyncCollections.follows);

  /// Drops a row that cannot be parsed instead of failing the whole response.
  static T? _tryParse<T>(T Function() build, String collection) {
    try {
      return build();
    } catch (error) {
      debugPrint(
        'RemoteSyncSource: skipping malformed $collection row ($error)',
      );
      return null;
    }
  }
}
