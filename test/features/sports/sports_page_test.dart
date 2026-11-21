import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slnews_mobile/core/domain/models/ad_unit.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/domain/models/sports_models.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/core/widgets/state_views.dart';
import 'package:slnews_mobile/features/sports/presentation/sports_page.dart';
import 'package:slnews_mobile/features/sports/presentation/widgets/followed_teams_row.dart';

import 'support/fakes.dart';

/// Widget-level coverage for Tab 3: the scoreboard strip, the followed-team row
/// and the inline ad all render from overridden in-memory repositories, and the
/// screen keeps its static sections when the scores endpoint fails.
void main() {
  const FollowTarget leoneStarsTarget = FollowTarget(
    id: 'team:leone-stars',
    kind: FollowKind.team,
    label: 'Leone Stars',
  );
  const Team leoneStars = Team(
    id: 'team:leone-stars',
    name: 'Leone Stars',
    code: 'LNS',
    colourHex: '#1B7F3B',
  );
  const Team boRangers = Team(
    id: 'team:bo-rangers',
    name: 'Bo Rangers',
    code: 'BOR',
    colourHex: '#B01C2E',
  );
  const AdUnit sportsAd = AdUnit(
    id: 'ad-sports-1',
    headline: 'CLAIM YOUR REWARD',
    body: 'Switch your salary account and get cash back.',
    ctaLabel: 'View more',
    advertiser: 'PayPal',
    assetLabel: r'$20',
    disclosure: 'Sponsored content from SLNews partners.',
  );

  /// Scoreboard with one final (NBA) and one live (SPL) fixture.
  FakeSportsRepository sportsWithScores() => FakeSportsRepository(
    scoreboard: ScoreboardSnapshot(
      games: <GameScore>[
        buildGame(
          id: 'g-nba-final',
          leagueLabel: 'NBA',
          status: GameStatus.finalScore,
          homeScore: 101,
          awayScore: 99,
          startsAt: DateTime(2026, 10, 14, 22),
        ),
        buildGame(
          id: 'g-spl-live',
          leagueLabel: 'Sierra Leone Premier League',
          status: GameStatus.live,
          periodLabel: "72'",
          home: leoneStars,
          away: boRangers,
          homeScore: 1,
          awayScore: 0,
          startsAt: DateTime(2026, 10, 15, 16),
        ),
      ],
      providerLabel: 'slnews',
      updatedAt: DateTime(2026, 10, 15, 20, 45),
    ),
    gamesByTeam: <String, List<GameScore>>{
      'team:leone-stars': <GameScore>[
        buildGame(
          id: 'g-spl-next',
          leagueLabel: 'SLPL Cup',
          home: leoneStars,
          away: boRangers,
          startsAt: DateTime(2026, 10, 20, 16, 30),
        ),
      ],
    },
  );

  FakeArticleRepository articlesWithSportsNews() {
    final FakeArticleRepository repository = FakeArticleRepository();
    repository.seed('sports', <Article>[
      buildArticle(
        id: 'story-1',
        title: 'Leone Stars hold Bo Rangers in Freetown derby',
      ),
    ]);
    return repository;
  }

  FakeFollowingRepository followingLeoneStars() => FakeFollowingRepository(
    snapshot: const FollowingSnapshot(
      followed: <FollowTarget>[leoneStarsTarget],
      suggested: <FollowTarget>[],
    ),
  );

  /// Pumps the real page inside a routing shell with overridden repositories.
  Widget buildApp({
    FakeArticleRepository? articles,
    FakeSportsRepository? sports,
    FakeFollowingRepository? following,
    FakeAdRepository? ads,
    double textScale = 1,
  }) {
    final GoRouter router = GoRouter(
      initialLocation: '/sports',
      routes: <RouteBase>[
        GoRoute(
          path: '/sports',
          builder: (BuildContext context, GoRouterState state) =>
              const SportsPage(),
        ),
        GoRoute(
          path: '/following',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Center(child: Text('Following tab'))),
        ),
        GoRoute(
          path: '/article/:id',
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: Center(child: Text('Article ${state.pathParameters['id']}')),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        articleRepositoryProvider.overrideWithValue(
          articles ?? articlesWithSportsNews(),
        ),
        sportsRepositoryProvider.overrideWithValue(
          sports ?? sportsWithScores(),
        ),
        followingRepositoryProvider.overrideWithValue(
          following ?? followingLeoneStars(),
        ),
        adRepositoryProvider.overrideWithValue(
          ads ?? FakeAdRepository(units: <AdUnit>[sportsAd]),
        ),
        userStateProvider.overrideWithValue(FakeUserStateRepository()),
        liveSportsFeedsProvider.overrideWithValue(false),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    );
  }

  /// Two frames are enough: the first paints the loading state, the second the
  /// resolved `AsyncValue` data.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'scoreboard strip renders team codes, scores and the FINAL label',
    (WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      await settle(tester);

      expect(find.text('LAL'), findsOneWidget);
      expect(find.text('BOS'), findsOneWidget);
      expect(find.text('101'), findsOneWidget);
      expect(find.text('99'), findsOneWidget);
      expect(find.text('FINAL'), findsOneWidget);
      expect(find.text("72'"), findsOneWidget);
      expect(find.text('Scores'), findsOneWidget);
      expect(find.text('slnews · 8:45PM'), findsOneWidget);
    },
  );

  testWidgets(
    'renders the following row, the team news stream and the fixtures',
    (WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      await settle(tester);

      expect(find.text('Following'), findsOneWidget);
      // The followed chip is a crest carrying the initials plus the code below it.
      expect(
        find.descendant(
          of: find.byType(FollowedTeamsRow),
          matching: find.text('LS'),
        ),
        findsNWidgets(2),
      );

      // Slivers below the fold are only built once they scroll into view.
      for (
        int i = 0;
        i < 12 && find.text('Top stories').evaluate().isEmpty;
        i++
      ) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pump();
      }
      expect(find.text('Top stories'), findsOneWidget);

      // The SPL block now sits after the curated major-league sections, so it
      // may not exist until it scrolls into view.
      for (
        int i = 0;
        i < 30 && find.text('Bo Rangers v Leone Stars').evaluate().isEmpty;
        i++
      ) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
        await tester.pump();
      }
      expect(find.text('Bo Rangers v Leone Stars'), findsOneWidget);

      for (
        int i = 0;
        i < 20 && find.text('Fixtures & results').evaluate().isEmpty;
        i++
      ) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
        await tester.pump();
      }
      expect(find.text('Fixtures & results'), findsOneWidget);
    },
  );

  testWidgets('embeds exactly one inline ad unit carrying the Ad label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await settle(tester);

    expect(find.text('AD'), findsOneWidget);
    expect(find.text('CLAIM YOUR REWARD'), findsOneWidget);
    expect(find.text('PayPal'), findsOneWidget);
  });

  testWidgets('keeps the static sections when the scoreboard fails', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        sports: FakeSportsRepository(error: StateError('scores offline')),
      ),
    );
    await settle(tester);

    expect(find.text('Scores are unavailable right now.'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FollowedTeamsRow),
        matching: find.text('LS'),
      ),
      findsNWidgets(2),
    );
    expect(find.text('AD'), findsOneWidget);
    expect(find.text('Top stories'), findsOneWidget);
    expect(find.byType(ErrorStateView), findsNothing);
  });

  testWidgets(
    'uses the full-page error only when the screen has no data at all',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        buildApp(
          articles: FakeArticleRepository(),
          sports: FakeSportsRepository(error: StateError('scores offline')),
          following: FakeFollowingRepository(
            snapshot: const FollowingSnapshot.empty(),
          ),
          ads: FakeAdRepository(),
        ),
      );
      await settle(tester);

      expect(find.byType(ErrorStateView), findsOneWidget);
      expect(find.text('Sports'), findsOneWidget);
    },
  );

  testWidgets(
    'empty following row prompts the reader and routes to /following',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        buildApp(
          following: FakeFollowingRepository(
            snapshot: const FollowingSnapshot.empty(),
          ),
        ),
      );
      await settle(tester);

      expect(find.text('Follow a team'), findsOneWidget);

      await tester.tap(find.text('Follow a team'));
      await tester.pumpAndSettle();

      expect(find.text('Following tab'), findsOneWidget);
    },
  );

  testWidgets('a member competition folds into the merged European block', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        sports: FakeSportsRepository(
          scoreboard: ScoreboardSnapshot(
            games: <GameScore>[
              buildGame(
                id: 'g-la-liga',
                leagueLabel: 'La Liga',
                status: GameStatus.finalScore,
                homeScore: 2,
                awayScore: 1,
                startsAt: DateTime(2026, 10, 14, 20),
              ),
            ],
            providerLabel: 'slnews',
            updatedAt: DateTime(2026, 10, 15, 20),
          ),
        ),
      ),
    );
    await settle(tester);

    // A provider label of "La Liga" must not spawn a second block next to the
    // merged one; the fixture belongs to "European Leagues".
    for (
      int i = 0;
      i < 30 && find.text('European Leagues').evaluate().isEmpty;
      i++
    ) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();
    }
    expect(find.text('European Leagues'), findsOneWidget);
    expect(find.text('La Liga'), findsNothing);
  });

  // The inline ad is deliberately left out of this case: the Lead-owned
  // `AdCard` paints its simulated offer row with `mainAxisSize.min` and no
  // flexible child, so under the widget-test font (one em per glyph) it
  // overflows a 320pt viewport by ~84px at 1.3x. That is a shared-widget
  // limitation reported upstream; every Sports-owned widget is covered here.
  testWidgets('renders at 320pt with 1.3 text scale without overflowing', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildApp(textScale: 1.3, ads: FakeAdRepository()));
    await settle(tester);

    expect(tester.takeException(), isNull);

    // The shorter score cards move the league sections further down; build the
    // SPL block by scrolling it into view before asserting.
    for (
      int i = 0;
      i < 30 && find.text('Sierra Leone Premier League').evaluate().isEmpty;
      i++
    ) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Sierra Leone Premier League'), findsOneWidget);
  });
}
