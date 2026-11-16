import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/controllers.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/following/presentation/manage_sports_page.dart';
import 'package:slnews_mobile/features/following/presentation/widgets/follow_row.dart';

import 'support/fakes.dart';

/// Widget tests for the Following tab (tab 4).
void main() {
  late FollowingTestFixture fixture;
  late ProviderContainer container;

  setUp(() {
    fixture = FollowingTestFixture();
    container = ProviderContainer(
      overrides: [
        followingRepositoryProvider.overrideWithValue(fixture.following),
        userStateProvider.overrideWithValue(fixture.userState),
        notificationRepositoryProvider.overrideWithValue(fixture.notifications),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: buildFollowingTestRouter(),
        ),
      ),
    );
    // `MaterialApp.router` builds its first route one frame behind the widget
    // insertion, and the alert history resolves on a microtask, so settle both.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Scrolls the page with discrete drags.
  ///
  /// `scrollUntilVisible`/`pumpAndSettle` are deliberately avoided: the loading
  /// skeleton runs an infinite shimmer, so settling would never complete.
  Future<void> dragPage(WidgetTester tester, {int times = 10}) async {
    for (int index = 0; index < times; index++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
      await tester.pump();
    }
  }

  testWidgets('renders the subscription sections without city locations', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpPage(tester);

    // The app-bar title, the followed team chip and the followed topic chip all
    // read "Following"; the page title is the one inside the app bar.
    final Finder appBarTitle = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Following'),
    );
    expect(appBarTitle, findsOneWidget);
    expect(find.text('Notification history'), findsOneWidget);

    // Section 1: Sports, with the followed team row.
    expect(find.text('Sports'), findsOneWidget);
    expect(find.text('Los Angeles Lakers'), findsOneWidget);

    // City locations are off the page for now: no header, no rows and no
    // location suggestions, even though the fixture follows Freetown.
    expect(find.text('Locations'), findsNothing);
    expect(find.text('Freetown'), findsNothing);
    expect(find.text('Most popular with users'), findsNothing);
    expect(find.text('Koidu'), findsNothing);

    // Section 2: Topics, with the followed topic.
    expect(find.text('Topics'), findsOneWidget);
    expect(find.text('Politics'), findsOneWidget);

    // Section 3: "Based on what you follow" — topic suggestions only.
    expect(find.text('Based on what you follow'), findsOneWidget);
    expect(find.text('Business'), findsOneWidget);
    expect(find.text('National News'), findsNothing);

    // Section 4: Sources — the header and its caption always render, even
    // before a source is followed.
    expect(find.text('Sources'), findsOneWidget);
    expect(
      find.text('Get news from the sources you trust at the top of your feed.'),
      findsOneWidget,
    );

    // Everything is reachable while scrolling too.
    await dragPage(tester);
    expect(find.byType(FollowRow), findsWidgets);
  });

  testWidgets('the Sports header opens the league/team catalogue', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpPage(tester);

    await tester.tap(find.text('Sports'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ManageSportsPage), findsOneWidget);
    expect(find.text('Manage leagues and teams'), findsOneWidget);
  });

  testWidgets('the Topics header opens the topic catalogue', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpPage(tester);

    await tester.tap(find.text('Topics'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Manage news topics'), findsOneWidget);
  });

  testWidgets('the Sources header opens the publisher catalogue', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpPage(tester);

    await tester.tap(find.text('Sources'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Manage news sources'), findsOneWidget);
  });

  testWidgets('tapping a followed team opens its surface', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpPage(tester);

    await tester.tap(find.text('Los Angeles Lakers'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('article-stub:team:lal'), findsOneWidget);
  });

  testWidgets('empty groups explain how to fill them', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A reader who follows nothing and has no suggestions still needs the
    // headers to be usable routes into the catalogues.
    final FollowingTestFixture empty = FollowingTestFixture.empty();
    final ProviderContainer emptyContainer = ProviderContainer(
      overrides: [
        followingRepositoryProvider.overrideWithValue(empty.following),
        userStateProvider.overrideWithValue(empty.userState),
        notificationRepositoryProvider.overrideWithValue(empty.notifications),
      ],
    );
    addTearDown(emptyContainer.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: emptyContainer,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: buildFollowingTestRouter(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Pick the leagues and teams you follow.'), findsOneWidget);
    // Locations are off the page, so no city hint is offered.
    expect(
      find.text('Pick up to three cities you want in your feed.'),
      findsNothing,
    );
    expect(find.text('Locations'), findsNothing);
    expect(
      find.text('Pick the news sections you want to follow.'),
      findsOneWidget,
    );
    expect(find.text('Sources'), findsOneWidget);
  });

  testWidgets(
    'tapping a Follow chip follows a suggested topic and stops suggesting it',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpPage(tester);

      expect(
        fixture.following.isFollowed(FollowingTestFixture.business.id),
        isFalse,
      );

      // Business is the only suggestion on the page now that locations are off
      // it; Politics is already followed and its row carries no chip.
      expect(find.text('Follow'), findsOneWidget);
      expect(
        container
            .read(followingControllerProvider)
            .isFollowed(FollowingTestFixture.politics.id),
        isTrue,
      );

      final Finder businessRow = find.ancestor(
        of: find.text('Business'),
        matching: find.byType(FollowRow),
      );
      final Finder businessChip = find.descendant(
        of: businessRow,
        matching: find.text('Follow'),
      );
      expect(businessChip, findsOneWidget);

      await tester.tap(businessChip);
      await tester.pump();
      await tester.pump();

      // The fake recorded the follow and the controller state converged.
      expect(
        fixture.following.toggleLog.map((FollowTarget target) => target.id),
        contains('topic:business'),
      );
      expect(
        container
            .read(followingControllerProvider)
            .isFollowed(FollowingTestFixture.business.id),
        isTrue,
      );

      // It leaves the suggestion group, so no outlined chip remains.
      expect(find.text('Follow'), findsNothing);

      // The action is confirmed with a snack bar.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Following Business'), findsOneWidget);
    },
  );

  testWidgets('the notification history row shows the unread count', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpPage(tester);

    final Finder historyTile = find
        .ancestor(
          of: find.text('Notification history'),
          matching: find.byType(Material),
        )
        .first;
    expect(
      find.descendant(of: historyTile, matching: find.text('2')),
      findsOneWidget,
    );

    // Mark the seeded alerts read: the badge must disappear.
    await fixture.notifications.markAllRead();
    await container.read(notificationsControllerProvider.notifier).reload();
    await tester.pump();

    expect(
      find.descendant(of: historyTile, matching: find.text('2')),
      findsNothing,
    );
  });

  testWidgets('does not overflow at 320pt width with text scale 1.3', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: buildFollowingTestRouter(),
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Walk the whole page so every row is laid out at least once. The default
    // test binding reports a RenderFlex overflow as a test failure, so a
    // surviving `takeException()` means the layout did not fit.
    await dragPage(tester, times: 14);

    final Object? overflow = tester.takeException();
    expect(
      overflow == null || !overflow.toString().contains('overflowed'),
      isTrue,
      reason: 'layout overflowed at 320pt with text scale 1.3: $overflow',
    );
    expect(find.byType(FollowRow), findsWidgets);
    expect(FollowingTestFixture.lakers.kind, FollowKind.team);
  });
}
