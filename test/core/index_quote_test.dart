import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/sources/index_quote_source.dart';
import 'package:slnews_mobile/core/domain/models/index_quote.dart';

/// The Stocks board depends on one wire format and one simplification (the New
/// York session). Both are pinned here so a provider change fails loudly.
void main() {
  group('formatQuotePrice', () {
    test('groups thousands and keeps two decimals', () {
      expect(formatQuotePrice(26140.03), '26,140.03');
      expect(formatQuotePrice(52002.4), '52,002.40');
      expect(formatQuotePrice(999.5), '999.50');
      expect(formatQuotePrice(1000000), '1,000,000.00');
      expect(formatQuotePrice(0.1), '0.10');
    });
  });

  group('IndexQuote', () {
    test('signs the move and flags its direction', () {
      const IndexQuote up = IndexQuote(
        symbol: '^GSPTSE',
        name: 'TSX Comp',
        subtitle: '',
        price: 36176.55,
        changePercent: 0.1,
      );
      const IndexQuote down = IndexQuote(
        symbol: '^IXIC',
        name: 'Nasdaq Comp',
        subtitle: '',
        price: 26140.03,
        changePercent: -3.94,
      );

      expect(up.isUp, isTrue);
      expect(up.changeLabel, '+0.10%');
      expect(down.isUp, isFalse);
      expect(down.changeLabel, '-3.94%');
      expect(up.priceLabel, '36,176.55');
    });

    test('round-trips through JSON', () {
      const IndexQuote quote = IndexQuote(
        symbol: '^IXIC',
        name: 'Nasdaq Comp',
        subtitle: 'NASDAQ Composite',
        price: 26140.03,
        changePercent: -3.94,
        sparkline: <double>[26500, 26410, 26140],
      );
      final IndexQuote parsed = IndexQuote.fromJson(<String, dynamic>{
        ...quote.toJson(),
      });

      expect(parsed.symbol, '^IXIC');
      expect(parsed.price, closeTo(26140.03, 0.001));
      expect(parsed.changePercent, closeTo(-3.94, 0.001));
      expect(parsed.sparkline, <double>[26500, 26410, 26140]);
    });
  });

  group('parseChart', () {
    test('reads price, previous close and intraday closes', () {
      final Object payload = <String, Object?>{
        'chart': <String, Object?>{
          'result': <Object?>[
            <String, Object?>{
              'meta': <String, Object?>{
                'regularMarketPrice': 26140.03,
                'chartPreviousClose': 27221.4,
              },
              'indicators': <String, Object?>{
                'quote': <Object?>[
                  <String, Object?>{
                    'close': <Object?>[26500.0, null, 26410.0, 26140.03],
                  },
                ],
              },
            },
          ],
        },
      };

      final ({double price, double changePercent, List<double> sparkline})?
      parsed = IndexQuoteSource.parseChart(payload);

      expect(parsed, isNotNull);
      expect(parsed!.price, closeTo(26140.03, 0.001));
      expect(parsed.changePercent, closeTo(-3.973, 0.01));
      expect(parsed.sparkline, <double>[26500.0, 26410.0, 26140.03]);
    });

    test('falls back to the last close when the meta has no price', () {
      final Object payload = <String, Object?>{
        'chart': <String, Object?>{
          'result': <Object?>[
            <String, Object?>{
              'meta': <String, Object?>{'previousClose': 100.0},
              'indicators': <String, Object?>{
                'quote': <Object?>[
                  <String, Object?>{
                    'close': <Object?>[90.0, 110.0],
                  },
                ],
              },
            },
          ],
        },
      };

      final ({double price, double changePercent, List<double> sparkline})?
      parsed = IndexQuoteSource.parseChart(payload);

      expect(parsed!.price, closeTo(110, 0.001));
      expect(parsed.changePercent, closeTo(10, 0.001));
    });

    test('rejects payloads that are not a chart', () {
      expect(IndexQuoteSource.parseChart(null), isNull);
      expect(
        IndexQuoteSource.parseChart(<String, Object?>{'chart': 'no'}),
        isNull,
      );
      expect(
        IndexQuoteSource.parseChart(<String, Object?>{
          'chart': <String, Object?>{'result': <Object?>[]},
        }),
        isNull,
      );
      expect(
        IndexQuoteSource.parseChart(<String, Object?>{
          'chart': <String, Object?>{
            'result': <Object?>[
              <String, Object?>{'meta': <String, Object?>{}},
            ],
          },
        }),
        isNull,
      );
    });

    test('thins a long series to 24 points', () {
      final Object payload = <String, Object?>{
        'chart': <String, Object?>{
          'result': <Object?>[
            <String, Object?>{
              'meta': <String, Object?>{'regularMarketPrice': 100.0},
              'indicators': <String, Object?>{
                'quote': <Object?>[
                  <String, Object?>{
                    'close': <Object?>[
                      for (int i = 0; i < 200; i++) i.toDouble(),
                    ],
                  },
                ],
              },
            },
          ],
        },
      };

      final ({double price, double changePercent, List<double> sparkline})?
      parsed = IndexQuoteSource.parseChart(payload);

      expect(parsed!.sparkline.length, 24);
      expect(parsed.sparkline.first, 0);
    });

    test('builds chart URLs per symbol', () {
      expect(IndexQuoteSource.chartUrl('^IXIC'), contains('%5EIXIC'));
      expect(IndexQuoteSource.chartUrl('^IXIC'), contains('range=1d'));
    });
  });

  group('marketOpen', () {
    test('is open on a weekday inside the New York session', () {
      // 14:30 UTC in October is 10:30 in New York (EDT).
      expect(
        IndexQuoteSource.marketOpen(DateTime.utc(2026, 10, 16, 14, 30)),
        isTrue,
      );
      // 15:30 UTC is 11:30 in January (EST).
      expect(
        IndexQuoteSource.marketOpen(DateTime.utc(2026, 1, 16, 15, 30)),
        isTrue,
      );
    });

    test('is closed before the open and after the close', () {
      expect(
        IndexQuoteSource.marketOpen(DateTime.utc(2026, 10, 16, 12)),
        isFalse,
      );
      expect(
        IndexQuoteSource.marketOpen(DateTime.utc(2026, 10, 16, 21)),
        isFalse,
      );
    });

    test('is closed at the weekend', () {
      expect(
        IndexQuoteSource.marketOpen(DateTime.utc(2026, 10, 17, 16)),
        isFalse,
      );
      expect(
        IndexQuoteSource.marketOpen(DateTime.utc(2026, 10, 18, 16)),
        isFalse,
      );
    });
  });

  group('IndexBoard', () {
    test('round-trips through JSON', () {
      final IndexBoard board = IndexBoard(
        quotes: const <IndexQuote>[
          IndexQuote(
            symbol: '^IXIC',
            name: 'Nasdaq Comp',
            subtitle: 'NASDAQ Composite',
            price: 26140.03,
            changePercent: -3.94,
          ),
        ],
        updatedAt: DateTime.utc(2026, 10, 16, 20),
        sourceLabel: 'yahoo/finance',
        isOpen: false,
      );

      final IndexBoard parsed = IndexBoard.fromJson(<String, dynamic>{
        ...board.toJson(),
      });

      expect(parsed.quotes.single.name, 'Nasdaq Comp');
      expect(parsed.sourceLabel, 'yahoo/finance');
      expect(parsed.isOpen, isFalse);
      expect(parsed.updatedAt.toUtc(), DateTime.utc(2026, 10, 16, 20));
    });
  });
}
