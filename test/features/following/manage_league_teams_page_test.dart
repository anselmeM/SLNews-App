import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/controllers.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/following/presentation/manage_league_teams_page.dart';

import '../feed/support/fakes.dart' show FakeUserStateRepository;
import 'support/fakes.dart';

/// Widget tests for the league -> team drill-in.
void main() {
  const FollowTarget lakers = FollowTarget(
    id: 'team:lal',
    kind: FollowKind.team,
    label: 'Los Angeles Lakers',
    subtitle: 'Basketball · NBA',
  );
  const FollowTarget rangers = FollowTarget(
    id: 'team:bo-rangers',
    kind: FollowKind.team,
    label: 'Bo Rangers',
    subtitle: 'Football · Sierra Leone Premier League',
  );
  const FollowTarget bayern = FollowTarget(
    id: 'team:bundesliga-bayern',
    kind: FollowKind.team,
    label: 'Bayern Munich',
    subtitle: 'Football · Bundesliga',
  );

  late InMemoryFollowingRepository following;
  late ProviderContainer container;

  setUp(() {
    following = InMemoryFollowingRepository(
      followed: <FollowTarget>[lakers],
      catalogue: <FollowTarget>[lakers, rangers, bayern],
    );
    container = ProviderContainer(
      overrides: [
        followingRepositoryProvider.overrideWithValue(following),
        userStateProvider.overrideWithValue(FakeUserStateRepository()),
      ],
    );
  });

  tearDown(() => container.dispose());

  /// Pumps the page behind a router so its pushes (league pages) resolve.
  Future<void> pumpPage(
    WidgetTester tester, {
    required String leagueId,
    String? label,
  }) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              ManageLeagueTeamsPage(leagueId: leagueId, label: label),
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
  }

  testWidgets('a competition lists only its own seeded teams', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester, leagueId: 'nba', label: 'NBA');

    expect(find.text('NBA'), findsOneWidget);
    expect(find.text('Select the teams you want to follow.'), findsOneWidget);
    expect(find.text('Los Angeles Lakers'), findsOneWidget);
    // The Sierra Leone Premier League side belongs to a different competition.
    expect(find.text('Bo Rangers'), findsNothing);

    // Already followed: the row is ticked and tapping it unfollows.
    expect(find.byIcon(Icons.check), findsOneWidget);
    await tester.tap(find.text('Los Angeles Lakers'));
    await tester.pump();
    await tester.pump();
    expect(
      container.read(followingControllerProvider).isFollowed('team:lal'),
      isFalse,
    );
  });

  testWidgets('a competition with no seeded teams explains itself', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester, leagueId: 'f1', label: 'Formula 1');

    expect(find.text('No teams listed yet'), findsOneWidget);

    await tester.tap(find.text('Open league page'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('league:f1'), findsOneWidget);
  });

  testWidgets('the merged competition lists its member leagues', (
    WidgetTester tester,
  ) async {
    await pumpPage(
      tester,
      leagueId: 'european-leagues',
      label: 'European Leagues',
    );

    expect(find.text('Pick a league to choose its teams.'), findsOneWidget);
    for (final String league in <String>[
      'La Liga',
      'Serie A',
      'Bundesliga',
      'Ligue 1',
    ]) {
      expect(find.text(league), findsOneWidget, reason: league);
    }

    await tester.tap(find.text('Bundesliga'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Select the teams you want to follow.'), findsOneWidget);
    expect(find.text('Bayern Munich'), findsOneWidget);
  });
}
