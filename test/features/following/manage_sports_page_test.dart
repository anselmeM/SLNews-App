import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/controllers.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/following/presentation/manage_league_teams_page.dart';
import 'package:slnews_mobile/features/following/presentation/manage_sports_page.dart';
import 'package:slnews_mobile/features/following/presentation/widgets/catalogue_list.dart';

import '../feed/support/fakes.dart' show FakeUserStateRepository;
import 'support/fakes.dart';

/// Widget tests for Following -> Manage leagues and teams.
void main() {
  const FollowTarget lakers = FollowTarget(
    id: 'team:lal',
    kind: FollowKind.team,
    label: 'Los Angeles Lakers',
    subtitle: 'Basketball · NBA',
  );

  late InMemoryFollowingRepository following;
  late ProviderContainer container;

  setUp(() {
    following = InMemoryFollowingRepository(
      followed: <FollowTarget>[lakers],
      catalogue: <FollowTarget>[lakers],
    );
    container = ProviderContainer(
      overrides: [
        followingRepositoryProvider.overrideWithValue(following),
        userStateProvider.overrideWithValue(FakeUserStateRepository()),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ManageSportsPage(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('lists every featured league and the seeded teams', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpPage(tester);

    expect(find.text('Leagues'), findsOneWidget);
    expect(find.text('NBA'), findsOneWidget);
    expect(find.text('NFL'), findsOneWidget);
    expect(find.text('Premier League'), findsOneWidget);
    expect(find.text('Sierra Leone Premier League'), findsOneWidget);

    expect(find.text('Teams'), findsOneWidget);
    expect(find.text('Los Angeles Lakers'), findsOneWidget);
  });

  testWidgets('the followed team is ticked', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpPage(tester);

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('following a league records the league target', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpPage(tester);

    await tester.tap(find.text('NFL'));
    await tester.pump();
    await tester.pump();

    final FollowingSnapshot snapshot = container.read(
      followingControllerProvider,
    );
    expect(snapshot.isFollowed('league:nfl'), isTrue);
    expect(snapshot.followed.map((FollowTarget t) => t.label), contains('NFL'));
  });

  testWidgets('search matches leagues and teams', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'lakers');
    await tester.pump();

    expect(find.text('Los Angeles Lakers'), findsOneWidget);
    expect(find.text('NBA'), findsNothing);
  });

  testWidgets(
    'European Leagues stays one section and expands to its four leagues',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpPage(tester);

      // One row for the whole merged section; the members are not listed until
      // the row is opened.
      expect(find.text('European Leagues'), findsOneWidget);
      expect(find.text('One section · 4 leagues'), findsOneWidget);
      expect(find.text('La Liga'), findsNothing);

      await tester.tap(find.text('European Leagues'));
      await tester.pump();

      expect(find.text('La Liga'), findsOneWidget);
      expect(find.text('Serie A'), findsOneWidget);
      expect(find.text('Bundesliga'), findsOneWidget);
      expect(find.text('Ligue 1'), findsOneWidget);

      // Collapsing hides them again.
      await tester.tap(find.text('European Leagues'));
      await tester.pump();
      expect(find.text('La Liga'), findsNothing);
    },
  );

  testWidgets('the tick follows the merged section without expanding it', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpPage(tester);

    final Finder row = find
        .ancestor(
          of: find.text('European Leagues'),
          matching: find.byType(InkWell),
        )
        .first;
    await tester.tap(
      find.descendant(of: row, matching: find.byType(CatalogueCheckCircle)),
    );
    await tester.pump();
    await tester.pump();

    expect(
      container
          .read(followingControllerProvider)
          .isFollowed('league:european-leagues'),
      isTrue,
    );
    // Tapping the tick must not also open the section.
    expect(find.text('La Liga'), findsNothing);
  });

  testWidgets('a member league opens its team list', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const ManageSportsPage(),
        ),
        GoRoute(
          path: '/sports/league/:id',
          builder: (BuildContext context, GoRouterState state) =>
              Scaffold(body: Text('league:${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/following/sports/:leagueId',
          builder: (BuildContext context, GoRouterState state) =>
              ManageLeagueTeamsPage(
                leagueId: state.pathParameters['leagueId'] ?? '',
                label: state.extra is String ? state.extra! as String : null,
              ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('European Leagues'));
    await tester.pump();
    await tester.tap(find.text('Serie A'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ManageLeagueTeamsPage), findsOneWidget);
    expect(find.text('Pick a league to choose its teams.'), findsNothing);
  });

  testWidgets('a league chevron drills into its teams', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A reader who follows nothing yet, so the drill-in starts unticked.
    final InMemoryFollowingRepository local = InMemoryFollowingRepository(
      catalogue: <FollowTarget>[lakers],
    );
    final ProviderContainer localContainer = ProviderContainer(
      overrides: [
        followingRepositoryProvider.overrideWithValue(local),
        userStateProvider.overrideWithValue(FakeUserStateRepository()),
      ],
    );
    addTearDown(localContainer.dispose);

    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const ManageSportsPage(),
        ),
        GoRoute(
          path: '/following/sports/:leagueId',
          builder: (BuildContext context, GoRouterState state) =>
              ManageLeagueTeamsPage(
                leagueId: state.pathParameters['leagueId'] ?? '',
                label: state.extra is String ? state.extra! as String : null,
              ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: localContainer,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    final Finder nbaRow = find
        .ancestor(of: find.text('NBA'), matching: find.byType(InkWell))
        .first;
    await tester.tap(
      find.descendant(of: nbaRow, matching: find.byTooltip('Teams')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The league row opened its own team list, not the Sports tab.
    expect(find.text('Select the teams you want to follow.'), findsOneWidget);
    final Finder teamsPage = find.byType(ManageLeagueTeamsPage);
    final Finder lakersRow = find.descendant(
      of: teamsPage,
      matching: find.text('Los Angeles Lakers'),
    );
    expect(lakersRow, findsOneWidget);

    await tester.tap(lakersRow);
    await tester.pump();
    await tester.pump();

    expect(
      localContainer.read(followingControllerProvider).isFollowed('team:lal'),
      isTrue,
    );
    expect(local.toggleLog.single.id, 'team:lal');
  });
}
