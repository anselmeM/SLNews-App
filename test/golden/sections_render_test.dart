import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/index_quote.dart';
import 'package:slnews_mobile/core/domain/models/sports_models.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/core/widgets/section_header.dart';
import 'package:slnews_mobile/features/feed/presentation/widgets/sport_spotlight_card.dart';
import 'package:slnews_mobile/features/markets/presentation/widgets/stocks_card.dart';

/// Visual reference for the two service sections added to For You.
///
/// The app-level renders in `screen_renders_test.dart` capture the top of each
/// tab, and the Sports/Stocks cards sit below the fold there; this file captures
/// them on their own so a layout change is reviewed as an image.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final String tempDir = Directory.systemTemp
        .createTempSync('slnews_sections_')
        .path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall call) async => tempDir,
        );

    final FontLoader textLoader = FontLoader('SLNewsSans');
    textLoader.addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
    await textLoader.load();

    final FontLoader iconLoader = FontLoader('MaterialIcons');
    iconLoader.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await iconLoader.load();
  });

  testWidgets('Sports and Stocks sections render their boards', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final GameScore game = GameScore(
      id: 'g1',
      leagueLabel: 'NBA',
      away: const Team(id: 't1', name: 'Denver Nuggets', code: 'DEN'),
      home: const Team(id: 't2', name: 'Los Angeles Lakers', code: 'LAL'),
      status: GameStatus.live,
      awayScore: 62,
      homeScore: 55,
      periodLabel: 'Q2 - 00.0',
      venue: 'Ball Arena',
    );

    final IndexBoard board = IndexBoard(
      quotes: const <IndexQuote>[
        IndexQuote(
          symbol: '^IXIC',
          name: 'Nasdaq Comp',
          subtitle: 'NASDAQ Composite',
          price: 26140.03,
          changePercent: -3.94,
          sparkline: <double>[26800, 26620, 26410, 26290, 26140],
        ),
        IndexQuote(
          symbol: '^RUT',
          name: 'Russell 2000',
          subtitle: 'Russell 2000 Index',
          price: 2721.37,
          changePercent: -1.66,
          sparkline: <double>[2790, 2760, 2740, 2721],
        ),
        IndexQuote(
          symbol: '^DJI',
          name: 'Dow Jones',
          subtitle: 'Dow Jones Industrial Average',
          price: 52002.40,
          changePercent: -0.36,
          sparkline: <double>[52300, 52200, 52100, 52002],
        ),
        IndexQuote(
          symbol: '^GSPTSE',
          name: 'TSX Comp',
          subtitle: 'S&P/TSX Composite index',
          price: 36176.55,
          changePercent: 0.10,
          sparkline: <double>[36100, 36130, 36160, 36176],
        ),
      ],
      updatedAt: DateTime.utc(2026, 10, 15, 20),
      sourceLabel: 'yahoo/finance',
      isOpen: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: <Widget>[
              const SectionHeader(
                title: 'Sports',
                subtitle: 'Scores and fixtures',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SportSpotlightCard(game: game),
              ),
              const SectionHeader(title: 'Stocks', subtitle: 'Market closed'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: StocksCard(board: board),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/sections.png'),
    );
  });
}
