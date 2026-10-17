import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/sources/api_client.dart';
import 'package:slnews_mobile/core/data/sources/market_rate_source.dart';
import 'package:slnews_mobile/core/domain/models/market_snapshot.dart';

import '../../data/fakes.dart';

/// The currency-board contract and the offline fallback behaviour.
void main() {
  Object? successPayload() => <String, Object?>{
    'result': 'success',
    'base_code': 'USD',
    'time_last_update_unix': 1792137600,
    'time_last_update_utc': 'Fri, 16 Oct 2026 00:00:00 +0000',
    'rates': <String, Object?>{
      'USD': 1,
      'SLE': 24.357927,
      'SLL': 24357.92723,
      'GBP': 0.750839,
      'EUR': 0.889517,
      'NGN': 1332.43205,
      'XOF': 583.48353,
    },
  };

  group('parse', () {
    test('reads the rates and the update instant', () {
      final MarketSnapshot? board = MarketRateSource.parse(successPayload());

      expect(board, isNotNull);
      expect(board!.base, 'USD');
      expect(board.rateOf('SLE'), closeTo(24.357927, 0.0001));
      expect(board.rateOf('GBP'), closeTo(0.750839, 0.0001));
      expect(
        board.updatedAt,
        DateTime.fromMillisecondsSinceEpoch(1792137600 * 1000, isUtc: true),
      );
      expect(board.source, 'open.er-api.com');
    });

    test('refuses a payload that is not a rate table', () {
      expect(MarketRateSource.parse(null), isNull);
      expect(MarketRateSource.parse('not json'), isNull);
      expect(MarketRateSource.parse(<String, Object?>{}), isNull);
      expect(
        MarketRateSource.parse(<String, Object?>{'result': 'error'}),
        isNull,
        reason: 'an error result must not be mistaken for rates',
      );
      expect(
        MarketRateSource.parse(<String, Object?>{'result': 'success'}),
        isNull,
        reason: 'no rates at all',
      );
      expect(
        MarketRateSource.parse(<String, Object?>{
          'result': 'success',
          'rates': <String, Object?>{},
        }),
        isNull,
      );
    });

    test('the board lists the leone first and skips absent currencies', () {
      final MarketSnapshot board = MarketSnapshot(
        base: 'USD',
        rates: const <String, double>{'SLE': 24.35, 'GBP': 0.75},
        updatedAt: DateTime.utc(2026, 10, 16),
        source: 'open.er-api.com',
      );

      expect(board.board.map((MarketRate rate) => rate.info.code), <String>[
        'SLE',
        'GBP',
      ], reason: 'EUR is missing from the payload, so it is not listed');
      expect(board.board.first.formatted, 'Le 24.35');
      expect(board.crossInBase('GBP'), closeTo(1.3333, 0.001));
    });

    test(
      'formats thousands with grouping and a pair-appropriate precision',
      () {
        expect(formatRate(24357.92723, decimals: 2), '24,357.93');
        expect(formatRate(1332.43205, decimals: 2), '1,332.43');
        expect(formatRate(24.357927, decimals: 2), '24.36');
        expect(formatRate(0.750839, decimals: 4), '0.7508');
        expect(formatRate(1, decimals: 2), '1.00');
      },
    );
  });

  group('fetch', () {
    test('returns null instead of throwing when the service fails', () async {
      final ({Dio dio, FakeHttpAdapter adapter}) fake = dioWith(
        (RequestOptions options) async =>
            jsonBody('{"error":"boom"}', statusCode: 500),
      );
      final MarketRateSource source = MarketRateSource(
        ApiClient(dio: fake.dio),
      );

      expect(await source.fetch(), isNull);
    });

    test('returns the board when the service answers with rates', () async {
      final ({Dio dio, FakeHttpAdapter adapter}) fake = dioWith(
        (RequestOptions options) async => jsonBody(
          '{"result":"success","base_code":"USD","time_last_update_unix":1792137600,'
          '"rates":{"SLE":24.357927,"GBP":0.750839}}',
        ),
      );
      final MarketRateSource source = MarketRateSource(
        ApiClient(dio: fake.dio),
      );

      final MarketSnapshot? board = await source.fetch();
      expect(board, isNotNull);
      expect(board!.rateOf('SLE'), closeTo(24.357927, 0.0001));
      expect(
        fake.adapter.requests.single.uri.toString(),
        MarketRateSource.defaultUrl,
      );
    });
  });
}
