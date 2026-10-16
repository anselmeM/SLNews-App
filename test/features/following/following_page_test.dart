import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/controllers.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
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

  testWidgets('renders all five sections', (WidgetTester tester) async {
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

    // Section 2: Locations, with the followed city row.
    expect(find.text('Locations'), findsOneWidget);
    expect(find.text('Freetown'), findsOneWidget);

    // Section 3: "Most popular with users" — only the *location* suggestions.
    expect(find.text('Most popular with users'), findsOneWidget);
    expect(find.text('Koidu'), findsOneWidget);
    expect(find.text('Kenema'), findsOneWidget);
    expect(find.text('National News'), findsNothing);

    // Section 4: Topics.
    expect(find.text('Topics'), findsOneWidget);
    expect(find.text('Politics'), findsOneWidget);

    // Everything is reachable while scrolling too.
    await dragPage(tester);
    expect(find.byType(FollowRow), findsWidgets);
  });

  testWidgets(
    'tapping a Follow chip flips it to Following and mutates the repository',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpPage(tester);

      expect(
        fixture.following.isFollowed(FollowingTestFixture.koidu.id),
        isFalse,
      );

      // Two outlined "Follow" chips are on screen (Kenema and Koidu); the topic
      // row already renders "Following" for the followed topic. The suggestions
      // are sorted by label, so target the Koidu row explicitly rather than
      // relying on document order.
      expect(find.text('Follow'), findsNWidgets(2));
      expect(
        container
            .read(followingControllerProvider)
            .isFollowed(FollowingTestFixture.politics.id),
        isTrue,
      );

      final Finder koiduRow = find.ancestor(
        of: find.text('Koidu'),
        matching: find.byType(FollowRow),
      );
      final Finder koiduChip = find.descendant(
        of: koiduRow,
        matching: find.text('Follow'),
      );
      expect(koiduChip, findsOneWidget);

      await tester.tap(koiduChip);
      await tester.pump();
      await tester.pump();

      // The fake recorded the follow and the controller state converged.
      expect(
        fixture.following.toggleLog.map((FollowTarget target) => target.id),
        contains('city:koidu'),
      );
      expect(
        container
            .read(followingControllerProvider)
            .isFollowed(FollowingTestFixture.koidu.id),
        isTrue,
      );

      // Koidu's chip now reads "Following": one outlined chip remains (Kenema).
      expect(find.text('Follow'), findsOneWidget);
      expect(
        find.descendant(of: koiduRow, matching: find.text('Following')),
        findsOneWidget,
      );

      // The action is confirmed with a snack bar.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Following Koidu'), findsOneWidget);
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
