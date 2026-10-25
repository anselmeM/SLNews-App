import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/onboarding/presentation/onboarding_page.dart';

import '../feed/support/fakes.dart';
import '../feed/support/test_harness.dart';

void main() {
  testWidgets('first-run picker writes follows and the home city', (
    WidgetTester tester,
  ) async {
    final FakeUserStateRepository userState = FakeUserStateRepository();
    final FakeFollowingRepository following = FakeFollowingRepository(
      catalogue: const <FollowTarget>[
        FollowTarget(
          id: 'topic:politics',
          kind: FollowKind.topic,
          label: 'Politics',
        ),
        FollowTarget(
          id: 'topic:business',
          kind: FollowKind.topic,
          label: 'Business',
        ),
      ],
    );
    final GoRouter router = GoRouter(
      initialLocation: '/onboarding',
      routes: <RouteBase>[
        GoRoute(
          path: '/onboarding',
          builder: (BuildContext context, GoRouterState state) =>
              const OnboardingPage(),
        ),
        GoRoute(
          path: '/for_you',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('For You')),
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: feedTestOverrides(
          articles: FakeArticleRepository(),
          userState: userState,
          following: following,
        ),
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Politics'));
    await tester.ensureVisible(find.text('Bo'));
    await tester.tap(find.text('Bo'));
    await tester.ensureVisible(find.text('Start reading'));
    await tester.tap(find.text('Start reading'));
    await tester.pumpAndSettle();

    expect(userState.onboardingCompleted, isTrue);
    expect(userState.activeLocationId, 'city:bo');
    expect(following.isFollowed('topic:politics'), isTrue);
    expect(find.text('For You'), findsOneWidget);
  });

  testWidgets('skip still marks onboarding complete', (
    WidgetTester tester,
  ) async {
    final FakeUserStateRepository userState = FakeUserStateRepository();
    final GoRouter router = GoRouter(
      initialLocation: '/onboarding',
      routes: <RouteBase>[
        GoRoute(
          path: '/onboarding',
          builder: (BuildContext context, GoRouterState state) =>
              const OnboardingPage(),
        ),
        GoRoute(
          path: '/for_you',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('For You')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: feedTestOverrides(
          articles: FakeArticleRepository(),
          userState: userState,
        ),
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(userState.onboardingCompleted, isTrue);
    expect(find.text('For You'), findsOneWidget);
  });
}
