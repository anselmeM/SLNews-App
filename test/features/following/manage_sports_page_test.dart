import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/controllers.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/following/presentation/manage_sports_page.dart';

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
}
