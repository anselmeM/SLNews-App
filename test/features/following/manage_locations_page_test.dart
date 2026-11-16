import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/controllers.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/following/presentation/manage_locations_page.dart';

import '../feed/support/fakes.dart' show FakeUserStateRepository;
import 'support/fakes.dart';

/// Widget tests for Following -> Manage locations (up to three follows).
void main() {
  const FollowTarget freetown = FollowTarget(
    id: 'city:freetown',
    kind: FollowKind.location,
    label: 'Freetown',
    subtitle: 'Western Area',
  );

  late InMemoryFollowingRepository following;
  late ProviderContainer container;

  setUp(() {
    following = InMemoryFollowingRepository(
      followed: <FollowTarget>[freetown],
      catalogue: <FollowTarget>[freetown],
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
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ManageLocationsPage(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('lists every city with the reference count', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    expect(
      find.text('Select up to three locations to follow. (1/3)'),
      findsOneWidget,
    );
    for (final String city in <String>[
      'Freetown',
      'Bo',
      'Kenema',
      'Makeni',
      'Koidu',
    ]) {
      expect(find.text(city), findsOneWidget, reason: city);
    }
  });

  testWidgets('following a city updates the count', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.text('Bo'));
    await tester.pump();
    await tester.pump();

    expect(
      container.read(followingControllerProvider).isFollowed('city:bo'),
      isTrue,
    );
    expect(
      find.text('Select up to three locations to follow. (2/3)'),
      findsOneWidget,
    );
  });

  testWidgets('a fourth city is refused with an explanation', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    // Freetown is already followed; add Bo and Kenema to reach the cap.
    for (final String city in <String>['Bo', 'Kenema']) {
      await tester.tap(find.text(city));
      await tester.pump();
      await tester.pump();
    }
    expect(
      find.text('Select up to three locations to follow. (3/3)'),
      findsOneWidget,
    );

    await tester.tap(find.text('Koidu'));
    await tester.pump();
    await tester.pump();

    expect(
      container.read(followingControllerProvider).isFollowed('city:koidu'),
      isFalse,
    );
    expect(
      find.textContaining('You can follow up to 3 locations'),
      findsOneWidget,
    );
    expect(
      find.text('Select up to three locations to follow. (3/3)'),
      findsOneWidget,
    );
  });

  testWidgets('unfollowing frees a slot', (WidgetTester tester) async {
    await pumpPage(tester);

    for (final String city in <String>['Bo', 'Kenema']) {
      await tester.tap(find.text(city));
      await tester.pump();
      await tester.pump();
    }
    await tester.tap(find.text('Freetown'));
    await tester.pump();
    await tester.pump();
    expect(
      container.read(followingControllerProvider).isFollowed('city:freetown'),
      isFalse,
    );

    await tester.tap(find.text('Koidu'));
    await tester.pump();
    await tester.pump();
    expect(
      container.read(followingControllerProvider).isFollowed('city:koidu'),
      isTrue,
    );
  });
}
