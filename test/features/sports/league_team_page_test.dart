import 'package:flutter/material.dart';
// Riverpod 3 keeps `Override` out of the main entrypoint.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/sports_models.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/sports/presentation/league_page.dart';
import 'package:slnews_mobile/features/sports/presentation/team_page.dart';

import 'support/fakes.dart';

/// League and team surfaces: each renders a table/fixtures plus stories and
/// degrades locally instead of blanking.
void main() {
  const Team home = Team(
    id: 'team:blackpool',
    name: 'Mighty Blackpool',
    code: 'MBP',
    colourHex: '#1B5E20',
  );
  const Team away = Team(
    id: 'team:portloko',
    name: 'Port Loko United',
    code: 'PLU',
    colourHex: '#B71C1C',
  );
  final GameScore game = GameScore(
    id: 'game-1',
    leagueLabel: 'Sierra Leone Premier League',
    away: away,
    home: home,
    status: GameStatus.finalScore,
    awayScore: 1,
    homeScore: 2,
    startsAt: DateTime.utc(2026, 10, 14, 17),
  );
  final Article story = testArticle(
    id: 'sports-1',
    title: 'Blackpool win the derby',
    publishedAt: DateTime.utc(2026, 10, 15),
    categoryId: 'sports',
  );

  List<Override> overrides({Map<String, List<GameScore>>? gamesByTeam}) {
    return <Override>[
      articleRepositoryProvider.overrideWithValue(
        FakeArticleRepository(
          feeds: <String, List<Article>>{
            'sports': <Article>[story],
          },
        ),
      ),
      sportsRepositoryProvider.overrideWithValue(
        FakeSportsRepository(
          scoreboard: ScoreboardSnapshot(
            games: <GameScore>[game],
            providerLabel: 'test',
            updatedAt: DateTime.utc(2026, 10, 15),
          ),
          gamesByTeam: gamesByTeam,
        ),
      ),
      followingRepositoryProvider.overrideWithValue(FakeFollowingRepository()),
      userStateProvider.overrideWithValue(FakeUserStateRepository()),
    ];
  }

  testWidgets('league page shows fixtures and stories', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const LeaguePage(
            leagueId: 'spl',
            leagueLabel: 'Sierra Leone Premier League',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sierra Leone Premier League'), findsWidgets);
    // Standings were removed: the tables were incomplete for most competitions.
    expect(find.text('Standings'), findsNothing);
    expect(find.text('Fixtures & results'), findsOneWidget);
    expect(find.text('Blackpool win the derby'), findsOneWidget);
  });

  testWidgets('the merged European section lists its four leagues', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const LeaguePage(
            leagueId: 'european-leagues',
            leagueLabel: 'European Leagues',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The Sports tab renders one "European Leagues" section; opening it names
    // the competitions inside instead of showing a table the merged
    // pseudo-league cannot have.
    expect(find.text('Leagues'), findsOneWidget);
    for (final String league in <String>[
      'La Liga',
      'Serie A',
      'Bundesliga',
      'Ligue 1',
    ]) {
      expect(find.text(league), findsOneWidget, reason: league);
    }
    expect(find.text('Standings'), findsNothing);
    expect(find.text('Fixtures & results'), findsOneWidget);
    expect(find.text('Latest stories'), findsOneWidget);
  });

  testWidgets('team page shows its fixtures and a follow control', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(
          gamesByTeam: <String, List<GameScore>>{
            'team:blackpool': <GameScore>[game],
          },
        ),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const TeamPage(
            teamId: 'team:blackpool',
            teamName: 'Mighty Blackpool',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mighty Blackpool'), findsWidgets);
    expect(find.text('Fixtures & results'), findsOneWidget);
    expect(find.text('Latest stories'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
  });
}
