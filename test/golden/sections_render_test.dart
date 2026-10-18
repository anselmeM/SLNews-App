import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/market_snapshot.dart';
import 'package:slnews_mobile/core/domain/models/sports_models.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/core/widgets/section_header.dart';
import 'package:slnews_mobile/features/feed/presentation/widgets/sports_carousel.dart';
import 'package:slnews_mobile/features/feed/presentation/widgets/stocks_carousel.dart';

/// Visual reference for the two service sections added to For You.
///
/// The app-level renders in `screen_renders_test.dart` capture the top of each
/// tab, and the Sports/Stocks sections sit below the fold there; this file
/// captures them on their own so a layout change is reviewed as an image.
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

  testWidgets('Sports and Stocks sections render as paged cards', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 760 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final List<GameScore> games = <GameScore>[
      GameScore(
        id: 'g1',
        leagueLabel: 'Sierra Leone Premier League',
        away: const Team(id: 't1', name: 'Bo Rangers', code: 'BOR'),
        home: const Team(id: 't2', name: 'East End Lions', code: 'EEL'),
        status: GameStatus.live,
        awayScore: 1,
        homeScore: 2,
        periodLabel: '72 min',
        venue: 'Bo Stadium',
      ),
      GameScore(
        id: 'g2',
        leagueLabel: 'Sierra Leone Premier League',
        away: const Team(id: 't3', name: 'Mighty Blackpool', code: 'MIG'),
        home: const Team(id: 't4', name: 'FC Kallon', code: 'KAL'),
        status: GameStatus.scheduled,
        startsAt: DateTime(2026, 10, 15, 16, 30),
      ),
    ];

    final MarketSnapshot board = MarketSnapshot(
      base: 'USD',
      rates: const <String, double>{
        'SLE': 24.357927,
        'SLL': 24357.92723,
        'GBP': 0.750839,
        'EUR': 0.889517,
      },
      updatedAt: DateTime(2026, 10, 15, 9),
      source: 'open.er-api.com',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ListView(
            children: <Widget>[
              const SectionHeader(
                title: 'Sports',
                subtitle: 'Scores and fixtures',
              ),
              SportsCarousel(games: games),
              const SectionHeader(title: 'Stocks', subtitle: 'Markets today'),
              StocksCarousel(rates: board.board),
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
