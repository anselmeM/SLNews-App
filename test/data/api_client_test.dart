import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/sources/api_client.dart';

import 'fakes.dart';

void main() {
  test(
    'getJson decodes an object payload and sends query parameters',
    () async {
      final ({Dio dio, FakeHttpAdapter adapter}) fake = dioWith(
        (RequestOptions options) async => jsonBody('{"items":[1,2]}'),
      );
      final ApiClient client = ApiClient(
        dio: fake.dio,
        timeout: const Duration(seconds: 2),
      );

      final Object? payload = await client.getJson(
        'https://example.test/feed',
        query: <String, dynamic>{'limit': 5},
      );

      expect(payload, isA<Map<String, dynamic>>());
      expect((payload! as Map<String, dynamic>)['items'], <int>[1, 2]);
      expect(
        fake.adapter.requests.single.uri.toString(),
        'https://example.test/feed?limit=5',
      );
    },
  );

  test('getJson decodes a JSON body the server did not label', () async {
    final ({Dio dio, FakeHttpAdapter adapter}) fake = dioWith(
      (RequestOptions options) async =>
          ResponseBody.fromString('[{"id":1}]', 200),
    );
    final ApiClient client = ApiClient(dio: fake.dio);

    final Object? payload = await client.getJson('https://example.test/x');

    expect(payload, isA<List<dynamic>>());
    expect((payload! as List<dynamic>).single, <String, dynamic>{'id': 1});
  });

  test('getText returns the raw XML body', () async {
    final ({Dio dio, FakeHttpAdapter adapter}) fake = dioWith(
      (RequestOptions options) async => ResponseBody.fromString(
        '<rss><channel><title>Feed</title></channel></rss>',
        200,
        headers: <String, List<String>>{
          'content-type': <String>['application/rss+xml; charset=utf-8'],
        },
      ),
    );
    final ApiClient client = ApiClient(dio: fake.dio);

    expect(
      await client.getText('https://example.test/feed'),
      startsWith('<rss>'),
    );
  });

  test('postJson sends a JSON body and decodes the response', () async {
    final ({Dio dio, FakeHttpAdapter adapter}) fake = dioWith(
      (RequestOptions options) async => jsonBody('{"data":{"articles":[]}}'),
    );
    final ApiClient client = ApiClient(dio: fake.dio);

    final Object? payload = await client.postJson(
      'https://example.test/graphql',
      <String, dynamic>{'query': '{ articles { id } }'},
    );

    expect(
      (payload! as Map<String, dynamic>)['data'],
      isA<Map<String, dynamic>>(),
    );
    expect(fake.adapter.requests.single.method, 'POST');
    expect(fake.adapter.requests.single.data.toString(), contains('articles'));
  });

  test(
    'maps a non-2xx response to ApiException carrying the status code',
    () async {
      final ({Dio dio, FakeHttpAdapter adapter}) fake = dioWith(
        (RequestOptions options) async =>
            jsonBody('{"error":"nope"}', statusCode: 404),
      );
      final ApiClient client = ApiClient(dio: fake.dio);

      await expectLater(
        client.getJson('https://example.test/missing'),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.statusCode, 'statusCode', 404)
              .having((ApiException e) => e.message, 'message', contains('404'))
              .having(
                (ApiException e) => e.uri,
                'uri',
                Uri.parse('https://example.test/missing'),
              ),
        ),
      );
    },
  );

  test(
    'keeps response headers on the failure so Retry-After survives the throw',
    () async {
      final ({Dio dio, FakeHttpAdapter adapter}) fake = dioWith(
        (RequestOptions options) async => ResponseBody.fromString(
          '{"error":"slow down"}',
          429,
          headers: <String, List<String>>{
            'content-type': <String>['application/json; charset=utf-8'],
            'retry-after': <String>['540'],
          },
        ),
      );
      final ApiClient client = ApiClient(dio: fake.dio);

      await expectLater(
        client.getJson('https://example.test/api/mobile/v1/sync'),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.statusCode, 'statusCode', 429)
              .having(
                (ApiException e) => e.responseHeaders?['retry-after'],
                'retry-after',
                '540',
              ),
        ),
      );
    },
  );

  test('a timeout carries no response headers', () async {
    final ({Dio dio, FakeHttpAdapter adapter}) fake = dioWith((
      RequestOptions options,
    ) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
        message: 'no response',
      );
    });
    final ApiClient client = ApiClient(dio: fake.dio);

    await expectLater(
      client.getJson('https://example.test/feed'),
      throwsA(
        isA<ApiException>().having(
          (ApiException e) => e.responseHeaders,
          'responseHeaders',
          isNull,
        ),
      ),
    );
  });

  test('maps a timeout to a readable ApiException', () async {
    final ({Dio dio, FakeHttpAdapter adapter}) fake = dioWith((
      RequestOptions options,
    ) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
        message: 'no response',
      );
    });
    final ApiClient client = ApiClient(
      dio: fake.dio,
      timeout: const Duration(milliseconds: 50),
    );

    await expectLater(
      client.getText('https://example.test/slow'),
      throwsA(
        isA<ApiException>()
            .having(
              (ApiException e) => e.message,
              'message',
              contains('Timed out after 50ms'),
            )
            .having((ApiException e) => e.statusCode, 'statusCode', isNull),
      ),
    );
  });

  test('maps a connection failure without leaking Dio internals', () async {
    final ({Dio dio, FakeHttpAdapter adapter}) fake = dioWith((
      RequestOptions options,
    ) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'SocketException: failed host lookup',
      );
    });
    final ApiClient client = ApiClient(dio: fake.dio);

    await expectLater(
      client.getJson('https://example.test/offline'),
      throwsA(
        isA<ApiException>().having(
          (ApiException e) => e.message,
          'message',
          'Could not reach the server',
        ),
      ),
    );
  });

  test(
    'reports unparseable JSON as an ApiException rather than a FormatException',
    () async {
      final ({Dio dio, FakeHttpAdapter adapter}) fake = dioWith(
        (RequestOptions options) async =>
            ResponseBody.fromString('<html>not json</html>', 200),
      );
      final ApiClient client = ApiClient(dio: fake.dio);

      await expectLater(
        client.getJson('https://example.test/html'),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test('ApiException renders a useful toString', () {
    expect(
      ApiException('boom', statusCode: 500).toString(),
      'ApiException(500): boom',
    );
    expect(ApiException('boom').toString(), 'ApiException: boom');
  });
}
