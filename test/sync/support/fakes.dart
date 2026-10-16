import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/sync/default_sync_repository.dart';
import 'package:slnews_mobile/core/data/sync/remote_sync_source.dart';
import 'package:slnews_mobile/core/data/sync/sync_api_config.dart';
import 'package:slnews_mobile/core/data/sources/api_client.dart';
import 'package:slnews_mobile/core/domain/sync/sync_repository.dart';

/// Base URL every test uses; asserted against the wire path.
const String testSyncOrigin = 'https://sync.test';

/// A config pointing at [testSyncOrigin].
const SyncApiConfig testSyncConfig = SyncApiConfig(baseUrl: testSyncOrigin);

/// A config with no origin: the "sync disabled" build.
const SyncApiConfig unconfiguredSyncConfig = SyncApiConfig(baseUrl: '');

/// A fixed instant used by every fixture, so comparisons are exact.
final DateTime t0 = DateTime.utc(2026, 10, 16, 4, 0, 0);

/// `t0` plus [minutes].
DateTime t(int minutes) => t0.add(Duration(minutes: minutes));

/// A [HttpClientAdapter] that answers from [responder] and records requests.
///
/// Hand-written on purpose: the project does not depend on a mocking package,
/// and a recorded [RequestOptions] is the only way to assert the wire contract
/// (method, path, query and body) that the sync API actually sees.
class RecordingAdapter implements HttpClientAdapter {
  /// Creates an adapter driven by [responder].
  RecordingAdapter(this.responder);

  /// Produces the response for each request. Throwing is how transport faults
  /// are simulated.
  final Future<ResponseBody> Function(RequestOptions options) responder;

  /// Every request the client made, in order.
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

/// A real [RemoteSyncSource] over a recording adapter.
class SyncHarness {
  /// Wires [responder] into a real [Dio] and a configured source.
  SyncHarness(
    Future<ResponseBody> Function(RequestOptions) responder, {
    SyncApiConfig? config,
    Future<String?> Function()? authTokenProvider,
    Set<String> authTokenHosts = const <String>{},
  }) : adapter = RecordingAdapter(responder) {
    final Dio dio = Dio()..httpClientAdapter = adapter;
    client = ApiClient(
      dio: dio,
      authTokenProvider: authTokenProvider,
      authTokenHosts: authTokenHosts,
    );
    source = RemoteSyncSource(config: config ?? testSyncConfig, api: client);
  }

  /// The recording adapter.
  final RecordingAdapter adapter;

  /// The client under test.
  late final ApiClient client;

  /// The source under test.
  late final RemoteSyncSource source;

  /// The single request the source made.
  RequestOptions get request => adapter.requests.single;

  /// Decoded JSON body of the single request.
  Map<String, dynamic> get body =>
      Map<String, dynamic>.from(request.data as Map<dynamic, dynamic>);

  /// Query parameters of the single request.
  Map<String, dynamic> get query =>
      Map<String, dynamic>.from(request.queryParameters);

  /// Builds a successful JSON response.
  static ResponseBody json(
    Object? payload, {
    int statusCode = 200,
    Map<String, String> headers = const <String, String>{},
  }) => ResponseBody.fromString(
    jsonEncode(payload),
    statusCode,
    headers: <String, List<String>>{
      'content-type': <String>['application/json; charset=utf-8'],
      for (final MapEntry<String, String> entry in headers.entries)
        entry.key: <String>[entry.value],
    },
  );

  /// Builds a successful response whose body is not valid JSON.
  static ResponseBody malformed({int statusCode = 200}) =>
      ResponseBody.fromString(
        '<html>not json</html>',
        statusCode,
        headers: <String, List<String>>{
          'content-type': <String>['text/html'],
        },
      );

  /// Builds an error response carrying a JSON error object.
  static ResponseBody error(
    int statusCode, {
    Map<String, String> headers = const <String, String>{},
  }) => json(
    <String, dynamic>{'error': 'nope'},
    statusCode: statusCode,
    headers: headers,
  );

  /// Builds a transport fault the way Dio raises one for [options].
  static DioException timeout(RequestOptions options) => DioException(
    requestOptions: options,
    type: DioExceptionType.receiveTimeout,
    message: 'no response',
  );
}

/// A hand-written [SyncApiSource] for repository tests.
///
/// It records every batch it was handed, so a test can assert what a retry
/// actually sent, and it can be told to fail a given number of times.
class FakeSyncApiSource implements SyncApiSource {
  /// Creates a source that succeeds (echoing the batch) by default.
  FakeSyncApiSource({
    this.isConfigured = true,
    this.nextPullRows = const SyncState.empty(),
  });

  @override
  bool isConfigured;

  /// Rows the next [pull] reports.
  SyncState nextPullRows;

  /// Result a scripted failure returns; `null` means a plain unavailable one.
  SyncResult? failWith;

  /// Number of upcoming [push] calls that should fail.
  int failuresRemaining = 0;

  /// Every batch handed to [push], in order.
  final List<SyncState> pushed = <SyncState>[];

  /// Every `since` handed to [pull], in order.
  final List<DateTime?> pulled = <DateTime?>[];

  /// When set, [push] throws this instead of returning a result (once).
  Object? throwOnPush;

  /// When set, the next successful [push] returns this result (once).
  SyncResult? nextResult;

  @override
  Future<SyncState> pull({DateTime? since}) async {
    pulled.add(since);
    return nextPullRows;
  }

  @override
  Future<SyncResult> push(SyncState local) async {
    pushed.add(local);
    final Object? thrown = throwOnPush;
    if (thrown != null) {
      throwOnPush = null;
      throw thrown;
    }
    if (failuresRemaining > 0) {
      failuresRemaining -= 1;
      return failWith ??
          SyncResult.failed(SyncFailure.unavailable('offline'), local: local);
    }
    final SyncResult? scripted = nextResult;
    nextResult = null;
    return scripted ?? SyncResult(state: local);
  }

  /// Rows sent in the most recent push.
  SyncState get lastPush => pushed.last;
}

/// A bookmark row; [savedAt] defaults to [updatedAt].
SyncBookmark bookmark(
  String itemId, {
  required DateTime updatedAt,
  String? title,
  bool deleted = false,
}) => SyncBookmark(
  itemId: itemId,
  title: title ?? 'Story $itemId',
  updatedAt: updatedAt,
  savedAt: updatedAt,
  sourceUrl: 'https://example.test/$itemId',
  publishedAt: updatedAt.subtract(const Duration(hours: 2)),
  deleted: deleted,
);

/// A bookmark tombstone.
SyncBookmark deletedBookmark(String itemId, {required DateTime updatedAt}) =>
    SyncBookmark.deleted(itemId: itemId, updatedAt: updatedAt);

/// A like row.
SyncReaction reaction(
  String itemId, {
  required DateTime updatedAt,
  bool deleted = false,
}) => SyncReaction(itemId: itemId, updatedAt: updatedAt, deleted: deleted);

/// A like tombstone.
SyncReaction deletedReaction(String itemId, {required DateTime updatedAt}) =>
    SyncReaction.deleted(itemId: itemId, updatedAt: updatedAt);

/// A follow row.
SyncFollow follow(
  String targetId, {
  required DateTime updatedAt,
  String kind = 'team',
  String? label,
  bool deleted = false,
}) => SyncFollow(
  targetId: targetId,
  kind: kind,
  label: label ?? targetId,
  updatedAt: updatedAt,
  deleted: deleted,
);

/// A follow tombstone.
SyncFollow deletedFollow(
  String targetId, {
  required DateTime updatedAt,
  String kind = 'team',
}) => SyncFollow.deleted(targetId: targetId, updatedAt: updatedAt, kind: kind);

/// A `GET /sync` response body with every collection overridable.
Map<String, dynamic> pullEnvelope({
  List<Map<String, dynamic>> bookmarks = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> reactions = const <Map<String, dynamic>>[],
  List<Map<String, dynamic>> follows = const <Map<String, dynamic>>[],
  String? serverTime = '2026-10-16T05:00:00.000Z',
  bool hasMore = false,
  bool includeServerTime = true,
}) => <String, dynamic>{
  if (includeServerTime) 'serverTime': serverTime,
  'hasMore': hasMore,
  'bookmarks': bookmarks,
  'reactions': reactions,
  'follows': follows,
};

/// A wire bookmark row.
Map<String, dynamic> bookmarkRow(
  String itemId, {
  required String updatedAt,
  String title = 'Leone Stars level with Guinea',
  String? savedAt,
  String? publishedAt = '2026-10-15T20:12:00.000Z',
  bool deleted = false,
}) => <String, dynamic>{
  'itemId': itemId,
  'title': title,
  'sourceUrl': 'https://example.test/$itemId',
  'imageUrl': null,
  'publisher': 'The Sierra Leone Telegraph',
  'publishedAt': publishedAt,
  'savedAt': savedAt ?? updatedAt,
  'updatedAt': updatedAt,
  'deleted': deleted,
};

/// A wire reaction row.
Map<String, dynamic> reactionRow(
  String itemId, {
  required String updatedAt,
  String kind = 'like',
  bool deleted = false,
}) => <String, dynamic>{
  'itemId': itemId,
  'kind': kind,
  'updatedAt': updatedAt,
  'deleted': deleted,
};

/// A wire follow row.
Map<String, dynamic> followRow(
  String targetId, {
  required String updatedAt,
  String kind = 'team',
  String? label = 'Los Angeles Lakers',
  bool deleted = false,
}) => <String, dynamic>{
  'targetId': targetId,
  'kind': kind,
  'label': label,
  'updatedAt': updatedAt,
  'deleted': deleted,
};

/// A `POST /sync` response body.
Map<String, dynamic> pushEnvelope({
  Map<String, dynamic> applied = const <String, dynamic>{
    'bookmarks': 1,
    'reactions': 0,
    'follows': 0,
  },
  List<Map<String, dynamic>> rejected = const <Map<String, dynamic>>[],
  Map<String, dynamic>? state,
  String? serverTime = '2026-10-16T05:00:00.000Z',
}) => <String, dynamic>{
  'serverTime': serverTime,
  'applied': applied,
  'rejected': rejected,
  'state': ?state,
};

/// Runs [body] and fails the test if the sync endpoint was called at all.
Future<void> expectNoRequest(
  SyncHarness harness,
  Future<void> Function() body,
) async {
  await body();
  expect(
    harness.adapter.requests,
    isEmpty,
    reason: 'an unconfigured build must not touch the network',
  );
}
