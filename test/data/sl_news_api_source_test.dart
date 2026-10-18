import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/sources/api_client.dart';
import 'package:slnews_mobile/core/data/sources/feed_source.dart';
import 'package:slnews_mobile/core/data/sources/sl_news_api_source.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/publisher.dart';

/// A [HttpClientAdapter] that answers from [responder] and records requests.
///
/// Hand-written on purpose: the project does not depend on a mocking package,
/// and a recorded [RequestOptions] is the only way to assert the wire contract
/// (path, query parameters and headers) that the scraper API actually sees.
class RecordingAdapter implements HttpClientAdapter {
  /// Creates an adapter driven by [responder].
  RecordingAdapter(this.responder);

  /// Produces the response for each request. Returning a [Future] that throws
  /// is how transport faults are simulated.
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

const String testBaseUrl = 'https://api.test';

/// The scraper key a configured test uses; asserted against the wire value.
const String testApiKey = 'test-key-123';

/// A configured source, plus the request log behind it.
class Harness {
  /// Wires [responder] into a real [Dio] and a configured source.
  Harness(
    Future<ResponseBody> Function(RequestOptions) responder, {
    SlNewsApiConfig? config,
    Map<String, String> defaultHeaders = const <String, String>{},
    Future<String?> Function()? authTokenProvider,
    Set<String> authTokenHosts = const <String>{'api.test'},
  }) : adapter = RecordingAdapter(responder),
       _config =
           config ??
           const SlNewsApiConfig(baseUrl: testBaseUrl, apiKey: testApiKey) {
    final Dio dio = Dio()..httpClientAdapter = adapter;
    client = ApiClient(
      dio: dio,
      defaultHeaders: defaultHeaders,
      authTokenProvider: authTokenProvider,
      authTokenHosts: authTokenHosts,
    );
    source = SlNewsApiSource(config: _config, client: client);
  }

  /// The recording adapter.
  final RecordingAdapter adapter;

  /// The client under test.
  late final ApiClient client;

  /// The source under test.
  late final SlNewsApiSource source;

  final SlNewsApiConfig _config;

  /// Request paths in order, e.g. `['/v1/news', '/api/news']`.
  List<String> get paths => adapter.requests
      .map((RequestOptions options) => options.uri.path)
      .toList();

  /// Query parameters of the request at [index].
  Map<String, dynamic> queryAt(int index) => queryOf(adapter.requests[index]);

  /// Header value (case-insensitive) of the request at [index].
  String? headerAt(int index, String name) =>
      headerOf(adapter.requests[index], name);

  /// Builds a successful JSON response.
  static ResponseBody json(
    Object? body, {
    int statusCode = 200,
    Map<String, String> headers = const <String, String>{},
  }) => ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      'content-type': <String>['application/json; charset=utf-8'],
      for (final MapEntry<String, String> entry in headers.entries)
        entry.key: <String>[entry.value],
    },
  );

  /// Builds a response body that is not valid JSON.
  static ResponseBody malformed({int statusCode = 200}) =>
      ResponseBody.fromString(
        '<html>not json</html>',
        statusCode,
        headers: <String, List<String>>{
          'content-type': <String>['text/html'],
        },
      );

  /// Builds an error response carrying a JSON error object.
  static ResponseBody error(int statusCode) =>
      json(<String, dynamic>{'error': 'nope'}, statusCode: statusCode);
}

/// Query parameters Dio resolved for [options].
Map<String, dynamic> queryOf(RequestOptions options) =>
    Map<String, dynamic>.from(options.queryParameters);

/// Header [name] (case-insensitive) as sent on the wire, or `null`.
String? headerOf(RequestOptions options, String name) {
  final String needle = name.toLowerCase();
  for (final MapEntry<String, dynamic> entry in options.headers.entries) {
    if (entry.key.toLowerCase() == needle) return entry.value?.toString();
  }
  return null;
}

/// A `/v1/news` envelope with one default row and [extra] merged into it.
Map<String, dynamic> v1Envelope({
  Map<String, dynamic> row = const <String, dynamic>{},
  int page = 1,
  int pageSize = 20,
  int total = 1,
  bool hasMore = false,
}) => <String, dynamic>{
  'data': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 123,
      'title': 'Bo district clinic reopens',
      'summary': 'Health workers return after refurbishment.',
      'source': 'The Sierra Leone Telegraph',
      'category': <String>['Politics', 'Business'],
      'url': 'https://example.test/story/123',
      'published_at': '2026-10-15T09:12:00.000Z',
      ...row,
    },
  ],
  'meta': <String, dynamic>{
    'page': page,
    'page_size': pageSize,
    'total': total,
    'has_more': hasMore,
  },
};

/// A bare `/api/news` row with [extra] merged in.
Map<String, dynamic> legacyRow([
  Map<String, dynamic> extra = const <String, dynamic>{},
]) => <String, dynamic>{
  'id': 7,
  'title': 'Freetown market traders strike',
  'link': 'https://example.test/story/7',
  'author': 'A. Kamara',
  'description': '<p>Trade halted for a second day.</p>',
  'category': <String>['Business'],
  'imageUrl': 'https://example.test/img/7.jpg',
  'paragraphs': <String>['Ignored body paragraph.'],
  'pubDate': 'Tue, 13 Oct 2026 13:30:25 +0000',
  'source': 'Awoko Newspaper',
  'createdAt': '2026-10-13T13:30:25.000Z',
  ...extra,
};

void main() {
  group('SlNewsApiConfig', () {
    test('is unconfigured without a key and never prints the key', () {
      const SlNewsApiConfig missing = SlNewsApiConfig(
        baseUrl: testBaseUrl,
        apiKey: '',
      );
      const SlNewsApiConfig blankHost = SlNewsApiConfig(
        baseUrl: '   ',
        apiKey: 'secret',
      );

      expect(missing.isConfigured, isFalse);
      expect(blankHost.isConfigured, isFalse);

      final String rendered = const SlNewsApiConfig(
        baseUrl: testBaseUrl,
        apiKey: 'super-secret-key',
      ).toString();
      expect(rendered, contains('api.test'));
      expect(rendered, contains('pageSize: 20'));
      expect(rendered, isNot(contains('super-secret-key')));
    });

    test('fromEnvironment supplies the deployed host and an empty key', () {
      final SlNewsApiConfig config = SlNewsApiConfig.fromEnvironment();

      // No --dart-define is present when this suite runs.
      expect(config.baseUrl, SlNewsApiConfig.defaultBaseUrl);
      expect(config.apiKey, isEmpty);
      expect(config.isConfigured, isFalse);
      expect(config.pageSize, SlNewsApiConfig.defaultPageSize);
    });

    test('copyWith clamps the page size into the API range', () {
      const SlNewsApiConfig base = SlNewsApiConfig(
        baseUrl: testBaseUrl,
        apiKey: testApiKey,
      );

      expect(base.copyWith(pageSize: 0).pageSize, 1);
      expect(base.copyWith(pageSize: 500).pageSize, 100);
      expect(base.copyWith(apiKey: 'next').apiKey, 'next');
      expect(base.copyWith(preferVersioned: false).preferVersioned, isFalse);
    });
  });

  group('SlNewsApiSource.config', () {
    test('describes the synthetic aggregate feed', () {
      final Harness harness = Harness(
        (RequestOptions options) async => Harness.json(v1Envelope()),
      );

      expect(harness.source.config.id, 'slnews-api');
      expect(harness.source.config.outlet, 'SLNews');
      expect(harness.source.config.wordmark, 'SLNEWS');
      expect(harness.source.config.kind.wireValue, 'restJson');
      expect(harness.source.config.categoryId, 'top');
      expect(harness.source.config.url, 'https://api.test/v1/news');
      // The source is usable through the FeedSource seam the registry holds.
      expect(harness.source, isA<FeedSource>());
      expect(harness.source.config.kind, FeedSourceKind.restJson);
    });
  });

  group('/v1/news mapping', () {
    test('maps an envelope row to a namespaced, attributed Article', () async {
      final Harness harness = Harness(
        (RequestOptions options) async => Harness.json(v1Envelope()),
      );

      final SlNewsApiPage page = await harness.source.fetchPage();

      expect(page.articles, hasLength(1));
      final Article article = page.articles.single;
      expect(article.id, 'slnews-api:123');
      expect(article.title, 'Bo district clinic reopens');
      expect(article.summary, 'Health workers return after refurbishment.');
      expect(article.bodyHtml, isEmpty);
      expect(article.sourceUrl, 'https://example.test/story/123');
      expect(article.publishedAt, DateTime.utc(2026, 10, 15, 9, 12));
      expect(article.tags, <String>['Politics', 'Business']);
      expect(article.categoryId, 'politics');
      expect(article.publisher.name, 'The Sierra Leone Telegraph');
      expect(article.publisher.id, 'publisher:the-sierra-leone-telegraph');
      expect(article.publisher.wordmark, 'TSLT');
      expect(article.isBreaking, isFalse);
      expect(article.isLive, isFalse);
      expect(article.author, isNull);
      expect(article.imageUrl, isNull);
    });

    test('carries meta totals into the page', () async {
      final Harness harness = Harness(
        (RequestOptions options) async => Harness.json(
          v1Envelope(page: 2, pageSize: 10, total: 1234, hasMore: true),
        ),
      );

      final SlNewsApiPage page = await harness.source.fetchPage(
        page: 2,
        pageSize: 10,
      );

      expect(page.page, 2);
      expect(page.pageSize, 10);
      expect(page.total, 1234);
      expect(page.hasMore, isTrue);
    });

    test('derives has_more from total when meta omits it', () async {
      final Harness harness = Harness(
        (RequestOptions options) async => Harness.json(<String, dynamic>{
          'data': <Map<String, dynamic>>[],
          'meta': <String, dynamic>{'page': 1, 'page_size': 20, 'total': 40},
        }),
      );

      final SlNewsApiPage page = await harness.source.fetchPage();

      expect(page.hasMore, isTrue);
      expect(page.articles, isEmpty);
      expect(page.total, 40);
    });

    test('strips HTML and collapses whitespace in title and summary', () async {
      final Harness harness = Harness(
        (RequestOptions options) async => Harness.json(
          v1Envelope(
            row: <String, dynamic>{
              'title': '  <b>Roads</b>\n\t flooded   again ',
              'summary': '<p>Freetown &amp; Waterloo</p>\n affected.',
            },
          ),
        ),
      );

      final Article article =
          (await harness.source.fetchPage()).articles.single;

      expect(article.title, 'Roads flooded again');
      expect(article.summary, 'Freetown & Waterloo affected.');
    });

    test('accepts epoch seconds and epoch millis for published_at', () async {
      const int epochSeconds = 1791537600;
      const int epochMillis = epochSeconds * 1000;
      final Harness harness = Harness(
        (RequestOptions options) async => Harness.json(<String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'title': 'Seconds',
              'summary': 's',
              'source': 'Awoko',
              'url': 'https://example.test/1',
              'published_at': epochSeconds,
            },
            <String, dynamic>{
              'id': 2,
              'title': 'Millis',
              'summary': 'm',
              'source': 'Awoko',
              'url': 'https://example.test/2',
              'published_at': epochMillis,
            },
          ],
          'meta': <String, dynamic>{'total': 2},
        }),
      );

      final SlNewsApiPage page = await harness.source.fetchPage();

      final DateTime expected = DateTime.fromMillisecondsSinceEpoch(
        epochMillis,
        isUtc: true,
      );
      expect(page.articles[0].publishedAt, expected);
      expect(page.articles[1].publishedAt, expected);
    });

    test(
      'falls back to now() for an unparseable date instead of throwing',
      () async {
        final Harness harness = Harness(
          (RequestOptions options) async => Harness.json(
            v1Envelope(row: <String, dynamic>{'published_at': 'not-a-date'}),
          ),
        );
        final DateTime before = DateTime.now();

        final SlNewsApiPage page = await harness.source.fetchPage();

        expect(page.articles, hasLength(1));
        final DateTime published = page.articles.single.publishedAt;
        expect(
          published.isBefore(before.subtract(const Duration(seconds: 5))),
          isFalse,
        );
        expect(
          published.isAfter(DateTime.now().add(const Duration(seconds: 5))),
          isFalse,
        );
      },
    );

    test('skips rows that describe no story', () async {
      final Harness harness = Harness(
        (RequestOptions options) async => Harness.json(<String, dynamic>{
          'data': <Object?>[
            'not-a-map',
            <String, dynamic>{'id': 9, 'title': '', 'summary': ''},
          ],
          'meta': <String, dynamic>{'total': 2},
        }),
      );

      expect((await harness.source.fetchPage()).articles, isEmpty);
    });
  });

  group('request shape', () {
    test('sends page, page_size and the bearer token to /v1/news', () async {
      final Harness harness = Harness(
        (RequestOptions options) async => Harness.json(v1Envelope()),
      );

      await harness.source.fetchPage(
        page: 3,
        pageSize: 25,
        source: 'Awoko',
        query: 'flood',
      );

      expect(harness.adapter.requests, hasLength(1));
      expect(harness.paths.single, '/v1/news');
      expect(harness.queryAt(0), <String, dynamic>{
        'page': 3,
        'page_size': 25,
        'source': 'Awoko',
        'q': 'flood',
      });
      expect(harness.headerAt(0, 'authorization'), 'Bearer $testApiKey');
    });

    test('omits empty filters from the query string', () async {
      final Harness harness = Harness(
        (RequestOptions options) async => Harness.json(v1Envelope()),
      );

      await harness.source.fetchPage(source: '  ', query: '');

      expect(harness.queryAt(0).containsKey('source'), isFalse);
      expect(harness.queryAt(0).containsKey('q'), isFalse);
    });

    test('clamps the page size to 1..100', () async {
      final Harness harness = Harness(
        (RequestOptions options) async => Harness.json(v1Envelope()),
      );

      await harness.source.fetchPage(pageSize: 0);
      await harness.source.fetchPage(pageSize: 5000);

      expect(harness.queryAt(0)['page_size'], 1);
      expect(harness.queryAt(1)['page_size'], 100);
    });

    test('fetch() reads page 1 with the requested limit', () async {
      final Harness harness = Harness(
        (RequestOptions options) async => Harness.json(v1Envelope()),
      );

      final List<Article> articles = await harness.source.fetch(limit: 5);

      expect(articles, hasLength(1));
      expect(harness.queryAt(0), <String, dynamic>{'page': 1, 'page_size': 5});
    });

    test(
      'uses the configured page size when the caller does not pick one',
      () async {
        final Harness harness = Harness(
          (RequestOptions options) async => Harness.json(v1Envelope()),
          config: const SlNewsApiConfig(
            baseUrl: testBaseUrl,
            apiKey: testApiKey,
            pageSize: 50,
          ),
        );

        await harness.source.fetchPage();

        expect(harness.queryAt(0)['page_size'], 50);
      },
    );

    test('health() does not send the bearer token', () async {
      final Harness harness = Harness(
        (RequestOptions options) async => Harness.json(<String, dynamic>{
          'status': 'ok',
          'database': 'connected',
          'timestamp': '2026-10-16T00:00:00.000Z',
        }),
        // A shared client must still keep the key off the open probe.
        defaultHeaders: const <String, String>{'Authorization': ''},
      );

      expect(await harness.source.health(), isTrue);

      expect(harness.paths.single, '/api/health');
      expect(harness.queryAt(0), isEmpty);
      expect(harness.headerAt(0, 'authorization'), isNull);
    });

    test('health() reports false for a non-ok status and for faults', () async {
      final Harness degraded = Harness(
        (RequestOptions options) async =>
            Harness.json(<String, dynamic>{'status': 'degraded'}),
      );
      expect(await degraded.source.health(), isFalse);

      final Harness broken = Harness(
        (RequestOptions options) async => Harness.error(500),
      );
      expect(await broken.source.health(), isFalse);
    });

    test(
      'a 404 on /v1/news falls back to /api/news and reads X-Total-Count',
      () async {
        final Harness harness = Harness((RequestOptions options) async {
          if (options.uri.path == '/v1/news') return Harness.error(404);
          return Harness.json(
            <Map<String, dynamic>>[legacyRow()],
            headers: <String, String>{'X-Total-Count': '1234'},
          );
        });

        final SlNewsApiPage page = await harness.source.fetchPage(
          page: 2,
          pageSize: 20,
        );

        expect(harness.paths, <String>['/v1/news', '/api/news']);
        expect(harness.queryAt(0), containsPair('page_size', 20));
        expect(harness.queryAt(1), <String, dynamic>{'limit': 20, 'page': 2});
        expect(harness.headerAt(1, 'authorization'), 'Bearer $testApiKey');
        expect(page.total, 1234);
        expect(page.hasMore, isTrue);
        expect(page.page, 2);
        expect(page.articles.single.id, 'slnews-api:7');
      },
    );

    test(
      'derives hasMore from the page length when the header is absent',
      () async {
        final Harness harness = Harness((RequestOptions options) async {
          if (options.uri.path == '/v1/news') return Harness.error(404);
          return Harness.json(<Map<String, dynamic>>[legacyRow()]);
        });

        final SlNewsApiPage page = await harness.source.fetchPage(pageSize: 1);

        expect(page.total, 1);
        expect(page.hasMore, isTrue);

        final Harness short = Harness((RequestOptions options) async {
          if (options.uri.path == '/v1/news') return Harness.error(404);
          return Harness.json(<Map<String, dynamic>>[]);
        });

        final SlNewsApiPage empty = await short.source.fetchPage(pageSize: 20);

        expect(empty.total, 0);
        expect(empty.hasMore, isFalse);
      },
    );

    test('preferVersioned: false goes straight to /api/news', () async {
      final Harness harness = Harness(
        (RequestOptions options) async => Harness.json(
          <Map<String, dynamic>>[legacyRow()],
          headers: <String, String>{'X-Total-Count': '7'},
        ),
        config: const SlNewsApiConfig(
          baseUrl: testBaseUrl,
          apiKey: testApiKey,
          preferVersioned: false,
        ),
      );

      final SlNewsApiPage page = await harness.source.fetchPage();

      expect(harness.paths, <String>['/api/news']);
      expect(page.total, 7);
      expect(page.articles.single.id, 'slnews-api:7');
    });
  });
  group('/api/news mapping', () {
    test('keeps author and image, ignores paragraphs', () async {
      final Harness harness = Harness(
        (RequestOptions options) async => Harness.json(
          <Map<String, dynamic>>[legacyRow()],
          headers: <String, String>{'X-Total-Count': '1'},
        ),
        config: const SlNewsApiConfig(
          baseUrl: testBaseUrl,
          apiKey: testApiKey,
          preferVersioned: false,
        ),
      );

      final Article article =
          (await harness.source.fetchPage()).articles.single;

      expect(article.id, 'slnews-api:7');
      expect(article.title, 'Freetown market traders strike');
      expect(article.summary, 'Trade halted for a second day.');
      expect(article.bodyHtml, isEmpty);
      expect(article.author, 'A. Kamara');
      expect(article.imageUrl, 'https://example.test/img/7.jpg');
      expect(article.sourceUrl, 'https://example.test/story/7');
      expect(article.categoryId, 'business');
      expect(article.tags, <String>['Business']);
      // 17 characters, so the badge is the name itself rather than initials.
      expect(article.publisher.wordmark, 'AWOKO NEWSPAPER');
      // RFC-822 `pubDate` in UTC.
      expect(article.publishedAt, DateTime.utc(2026, 10, 13, 13, 30, 25));
    });
  });

  group('degraded paths', () {
    test('unconfigured source issues no HTTP request at all', () async {
      final SlNewsApiConfig disabled = const SlNewsApiConfig(
        baseUrl: testBaseUrl,
        apiKey: '',
      );
      final Harness harness = Harness(
        (RequestOptions options) async =>
            fail('the disabled source must not issue a request'),
        config: disabled,
      );

      expect(await harness.source.fetch(), isEmpty);
      expect((await harness.source.fetchPage()).articles, isEmpty);
      expect(await harness.source.articleById('slnews-api:7'), isNull);
      expect(await harness.source.health(), isFalse);
      expect(harness.adapter.requests, isEmpty);
    });

    test(
      'a 401 on /v1/news does not fall back and yields an empty page',
      () async {
        final Harness harness = Harness(
          (RequestOptions options) async => Harness.error(401),
        );

        final SlNewsApiPage page = await harness.source.fetchPage();

        expect(harness.paths, <String>['/v1/news']);
        expect(page.articles, isEmpty);
        expect(page.total, 0);
        expect(page.hasMore, isFalse);
      },
    );

    test('a 403 on /api/news yields an empty page without throwing', () async {
      final Harness harness = Harness(
        (RequestOptions options) async => Harness.error(403),
        config: const SlNewsApiConfig(
          baseUrl: testBaseUrl,
          apiKey: testApiKey,
          preferVersioned: false,
        ),
      );

      final SlNewsApiPage page = await harness.source.fetchPage();

      expect(harness.paths, <String>['/api/news']);
      expect(page.articles, isEmpty);
    });

    test('a 500 yields an empty page', () async {
      final Harness harness = Harness(
        (RequestOptions options) async => Harness.error(500),
      );

      expect((await harness.source.fetchPage()).articles, isEmpty);
      expect(await harness.source.fetch(), isEmpty);
    });

    test('a timeout yields an empty page', () async {
      final Harness harness = Harness((RequestOptions options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
          message: 'no response',
        );
      });

      expect((await harness.source.fetchPage()).articles, isEmpty);
      expect(await harness.source.fetch(), isEmpty);
      expect(await harness.source.health(), isFalse);
    });

    test('malformed JSON yields an empty page', () async {
      final Harness harness = Harness(
        (RequestOptions options) async => Harness.malformed(),
      );

      expect((await harness.source.fetchPage()).articles, isEmpty);
      expect(await harness.source.fetch(), isEmpty);
    });

    test('an unexpected payload shape yields an empty page', () async {
      final Harness harness = Harness(
        (RequestOptions options) async => Harness.json('just a string'),
      );

      final SlNewsApiPage page = await harness.source.fetchPage();

      expect(page.articles, isEmpty);
      expect(page.total, 0);
    });
  });

  group('articleById', () {
    test('accepts the namespaced id and the bare numeric id', () async {
      final Harness harness = Harness(
        (RequestOptions options) async => Harness.json(legacyRow()),
      );

      final Article? namespaced = await harness.source.articleById(
        'slnews-api:7',
      );
      final Article? bare = await harness.source.articleById('7');

      expect(harness.paths, <String>['/api/news/7', '/api/news/7']);
      expect(harness.headerAt(0, 'authorization'), 'Bearer $testApiKey');
      expect(namespaced?.id, 'slnews-api:7');
      expect(bare?.id, 'slnews-api:7');
      expect(namespaced?.title, 'Freetown market traders strike');
    });

    test('returns null without a request for a non-numeric id', () async {
      final Harness harness = Harness(
        (RequestOptions options) async =>
            fail('no request expected for id "abc"'),
      );

      expect(await harness.source.articleById('abc'), isNull);
      expect(await harness.source.articleById('slnews-api:abc'), isNull);
      expect(await harness.source.articleById(''), isNull);
      expect(await harness.source.articleById('slnews-api:'), isNull);
      expect(harness.adapter.requests, isEmpty);
    });

    test('returns null for a 404 and for a malformed row', () async {
      final Harness missing = Harness(
        (RequestOptions options) async => Harness.error(404),
      );
      final Harness malformed = Harness(
        (RequestOptions options) async =>
            Harness.json(<String, dynamic>{'id': 7}),
      );

      expect(await missing.source.articleById('7'), isNull);
      expect(await malformed.source.articleById('7'), isNull);
    });

    test('unwraps a {data: {...}} envelope', () async {
      final Harness harness = Harness(
        (RequestOptions options) async =>
            Harness.json(<String, dynamic>{'data': legacyRow()}),
      );

      expect((await harness.source.articleById('7'))?.id, 'slnews-api:7');
    });
  });

  group('categoryIdFor', () {
    test('matches curated labels case-insensitively', () {
      expect(SlNewsApiSource.categoryIdFor(<String>['Politics']), 'politics');
      expect(SlNewsApiSource.categoryIdFor(<String>['BUSINESS']), 'business');
      expect(SlNewsApiSource.categoryIdFor(<String>['Sports']), 'sports');
      expect(SlNewsApiSource.categoryIdFor(<String>['Health']), 'health');
    });

    test('splits compound labels before matching', () {
      expect(
        SlNewsApiSource.categoryIdFor(<String>['Politics & Law']),
        'politics',
      );
      expect(
        SlNewsApiSource.categoryIdFor(<String>['Business,Economy']),
        'business',
      );
      expect(SlNewsApiSource.categoryIdFor(<String>['Top Stories']), 'top');
    });

    test('first recognised label wins', () {
      expect(
        SlNewsApiSource.categoryIdFor(<String>['Uncategorised', 'Sports']),
        'sports',
      );
    });

    test('falls back to top', () {
      expect(SlNewsApiSource.categoryIdFor(<String>[]), 'top');
      expect(SlNewsApiSource.categoryIdFor(<String>['Astrology']), 'top');
      expect(SlNewsApiSource.categoryIdFor(<String>['', '   ']), 'top');
    });
  });

  group('publisherFor', () {
    test('uses the uppercase name for a short outlet', () {
      final Publisher short = SlNewsApiSource.publisherFor('Awoko');

      expect(short.id, 'publisher:awoko');
      expect(short.name, 'Awoko');
      expect(short.wordmark, 'AWOKO');
      expect(short.isWire, isFalse);
    });

    test('uses significant-word initials for a long outlet', () {
      final Publisher long = SlNewsApiSource.publisherFor(
        'The Sierra Leone Telegraph',
      );

      expect(long.id, 'publisher:the-sierra-leone-telegraph');
      expect(long.name, 'The Sierra Leone Telegraph');
      expect(long.wordmark, 'TSLT');
    });

    test('strips punctuation when slugging', () {
      final Publisher pun = SlNewsApiSource.publisherFor('Salone Times & Co.');

      expect(pun.id, 'publisher:salone-times-co');
      expect(pun.name, 'Salone Times & Co.');
    });

    test('flags wire services', () {
      expect(SlNewsApiSource.publisherFor('Reuters').isWire, isTrue);
      expect(SlNewsApiSource.publisherFor('BBC News').isWire, isTrue);
      expect(SlNewsApiSource.publisherFor('AFP').isWire, isTrue);
      expect(
        SlNewsApiSource.publisherFor('The Associated Press').isWire,
        isTrue,
      );
      expect(SlNewsApiSource.publisherFor('Awoko Newspaper').isWire, isFalse);
    });

    test('has a deterministic identity across calls', () {
      final Publisher first = SlNewsApiSource.publisherFor('Awoko Newspaper');
      final Publisher second = SlNewsApiSource.publisherFor('Awoko Newspaper');

      expect(first, second);
    });

    test('falls back to a neutral publisher for a blank source', () {
      final Publisher blank = SlNewsApiSource.publisherFor('   ');

      expect(blank.id, 'publisher:unknown');
      expect(blank.name, isNotEmpty);
    });
  });

  group('Clerk session tokens', () {
    const SlNewsApiConfig keyless = SlNewsApiConfig(
      baseUrl: testBaseUrl,
      apiKey: '',
      sessionTokenAvailable: true,
    );
    const SlNewsApiConfig keylessNoIdentity = SlNewsApiConfig(
      baseUrl: testBaseUrl,
      apiKey: '',
    );

    test(
      'a build without an embedded key is configured when identity exists',
      () {
        expect(keyless.isConfigured, isTrue);
        expect(keylessNoIdentity.isConfigured, isFalse);
        expect(keyless.copyWith(apiKey: 'next').apiKey, 'next');
        expect(
          keyless.copyWith(sessionTokenAvailable: false).isConfigured,
          isFalse,
        );
      },
    );

    test(
      'the session token authenticates the request when no key is embedded',
      () async {
        final Harness harness = Harness(
          (RequestOptions options) async => Harness.json(v1Envelope()),
          config: keyless,
          authTokenProvider: () async => 'session-jwt',
        );

        await harness.source.fetchPage();

        expect(harness.headerAt(0, 'authorization'), 'Bearer session-jwt');
      },
    );

    test('the session token wins over an embedded key', () async {
      final Harness harness = Harness(
        (RequestOptions options) async => Harness.json(v1Envelope()),
        authTokenProvider: () async => 'session-jwt',
      );

      await harness.source.fetchPage();

      expect(
        harness.headerAt(0, 'authorization'),
        'Bearer session-jwt',
        reason: 'the reader credential is preferred over the shipped one',
      );
    });

    test('signed out, an embedded key still authenticates', () async {
      final Harness harness = Harness(
        (RequestOptions options) async => Harness.json(v1Envelope()),
        authTokenProvider: () async => null,
      );

      await harness.source.fetchPage();

      expect(harness.headerAt(0, 'authorization'), 'Bearer $testApiKey');
    });

    test('a keyless build signed out sends no bearer header at all', () async {
      final Harness harness = Harness(
        (RequestOptions options) async => Harness.json(v1Envelope()),
        config: keyless,
        authTokenProvider: () async => null,
      );

      await harness.source.fetchPage();

      expect(harness.headerAt(0, 'authorization'), isNull);
    });
  });
}
