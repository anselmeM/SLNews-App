import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/market_snapshot.dart';
import 'package:slnews_mobile/core/domain/models/sports_models.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/core/widgets/page_dots.dart';
import 'package:slnews_mobile/features/feed/presentation/widgets/sports_carousel.dart';
import 'package:slnews_mobile/features/feed/presentation/widgets/stocks_carousel.dart';

/// The two service sections that repeat the lead carousel's behaviour: snap to a
/// card, dots underneath, tap to open the full surface.
void main() {
  List<MarketRate> rates() => <MarketRate>[
    for (final CurrencyInfo info in trackedCurrencies)
      if (info.code != 'SLL' && info.code != 'GHS' && info.code != 'XOF')
        MarketRate(
          info: info,
          perBase: info.code == 'SLE' ? 24.357927 : 0.750839,
        ),
  ];

  GameScore game({
    required String id,
    required GameStatus status,
    int? away,
    int? home,
    String? period,
    DateTime? startsAt,
  }) => GameScore(
    id: id,
    leagueLabel: 'Sierra Leone Premier League',
    away: const Team(id: 't1', name: 'Bo Rangers', code: 'BOR'),
    home: const Team(id: 't2', name: 'East End Lions', code: 'EEL'),
    status: status,
    awayScore: away,
    homeScore: home,
    periodLabel: period,
    startsAt: startsAt,
    venue: 'Bo Stadium',
  );

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('StocksCarousel', () {
    testWidgets('quotes each pair with the board formatting', (
      WidgetTester tester,
    ) async {
      await pump(tester, StocksCarousel(rates: rates()));

      expect(find.text('Sierra Leone (new leone)'), findsOneWidget);
      expect(find.text('Le 24.36'), findsOneWidget);
      expect(find.text('SLE'), findsOneWidget);
      // The paged viewport keeps the neighbouring card built, so the caption on
      // the next quote is in the tree as well.
      expect(find.text('per 1 US dollar'), findsWidgets);
    });

    testWidgets('uses dots when there is more than one quote', (
      WidgetTester tester,
    ) async {
      await pump(tester, StocksCarousel(rates: rates()));

      final PageDots dots = tester.widget<PageDots>(find.byType(PageDots));
      expect(dots.count, rates().length);
      expect(dots.index, 0);
    });

    testWidgets('a tap reports the quote', (WidgetTester tester) async {
      MarketRate? tapped;
      await pump(
        tester,
        StocksCarousel(
          rates: rates(),
          onOpen: (MarketRate rate) => tapped = rate,
        ),
      );

      await tester.tap(find.text('Le 24.36'));
      await tester.pumpAndSettle();

      expect(tapped?.info.code, 'SLE');
    });

    testWidgets('renders nothing without quotes', (WidgetTester tester) async {
      await pump(tester, StocksCarousel(rates: const <MarketRate>[]));

      expect(find.byType(PageDots), findsNothing);
    });
  });

  group('SportsCarousel', () {
    testWidgets('shows both teams and a live period', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        SportsCarousel(
          games: <GameScore>[
            game(
              id: 'g1',
              status: GameStatus.live,
              away: 1,
              home: 2,
              period: '2nd half',
            ),
          ],
        ),
      );

      expect(find.text('Bo Rangers'), findsOneWidget);
      expect(find.text('East End Lions'), findsOneWidget);
      expect(find.text('BOR'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('2ND HALF'), findsOneWidget);
    });

    testWidgets('labels full time and scheduled fixtures distinctly', (
      WidgetTester tester,
    ) async {
      expect(
        fixtureStatusLabel(game(id: 'g1', status: GameStatus.finalScore)),
        'FT',
      );
      expect(
        fixtureStatusLabel(game(id: 'g2', status: GameStatus.postponed)),
        'POSTPONED',
      );
      expect(
        fixtureStatusLabel(
          game(
            id: 'g3',
            status: GameStatus.scheduled,
            startsAt: DateTime(2026, 10, 18),
          ),
        ),
        isNotEmpty,
      );
      expect(
        fixtureHasScore(game(id: 'g4', status: GameStatus.scheduled)),
        isFalse,
      );
      expect(
        fixtureHasScore(
          game(id: 'g5', status: GameStatus.finalScore, away: 0, home: 0),
        ),
        isTrue,
      );
    });

    testWidgets('a tap reports the fixture', (WidgetTester tester) async {
      GameScore? tapped;
      await pump(
        tester,
        SportsCarousel(
          games: <GameScore>[
            game(id: 'g1', status: GameStatus.live, away: 1, home: 2),
          ],
          onOpen: (GameScore value) => tapped = value,
        ),
      );

      await tester.tap(find.text('Bo Rangers'));
      await tester.pumpAndSettle();

      expect(tapped?.id, 'g1');
    });

    testWidgets('renders nothing without fixtures', (
      WidgetTester tester,
    ) async {
      await pump(tester, SportsCarousel(games: const <GameScore>[]));

      expect(find.byType(PageDots), findsNothing);
    });
  });
}
