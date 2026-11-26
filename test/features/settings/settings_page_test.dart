import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/controllers.dart';
import 'package:slnews_mobile/core/providers/personalization_profile.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/settings/presentation/settings_page.dart';

import '../feed/support/fakes.dart';

/// Widget tests for the settings screen (`/settings`).
void main() {
  late FakeUserStateRepository userState;
  late ProviderContainer container;

  setUp(() {
    userState = FakeUserStateRepository();
    container = ProviderContainer(
      overrides: [
        userStateProvider.overrideWithValue(userState),
        preferencesStoreProvider.overrideWithValue(InMemoryPreferencesStore()),
      ],
    );
  });

  tearDown(() => container.dispose());

  GoRouter router() => GoRouter(
    initialLocation: '/settings',
    routes: <RouteBase>[
      GoRoute(
        path: '/settings',
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsPage(),
      ),
      GoRoute(
        path: '/sign_in',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('sign-in route')),
      ),
    ],
  );

  Future<void> pumpPage(WidgetTester tester) async {
    // The screen is a tall stack of cards, so give the test a viewport that fits
    // it: otherwise the rows below the fold are never built and cannot be found
    // or tapped. Scrolling per-test would work too, at the cost of repetition.
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool switchValue(WidgetTester tester, String rowTitle) {
    final Finder row = find.ancestor(
      of: find.text(rowTitle),
      matching: find.byType(Row),
    );
    final Switch toggle = tester.widget<Switch>(
      find.descendant(of: row.first, matching: find.byType(Switch)),
    );
    return toggle.value;
  }

  testWidgets('renders every group from the reference screen', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    // Header and account.
    expect(find.text('SLNews settings'), findsOneWidget);
    expect(find.text('SLNews account'), findsOneWidget);
    expect(find.text('Not signed in \u2014 tap to sign in'), findsOneWidget);

    // Notifications: the four categories, with the reference copy.
    expect(find.text('Notifications'), findsOneWidget);
    for (final String title in <String>[
      'Breaking news',
      "Editor's picks",
      'Interactive content',
      'Sports',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(
      find.text('Get top stories, daily briefings, and recommended news.'),
      findsOneWidget,
    );
    expect(
      find.text('Get notified when teams and leagues you follow have updates.'),
      findsOneWidget,
    );

    // News group.
    expect(find.text('News'), findsOneWidget);
    expect(find.text('Language and region'), findsOneWidget);
    expect(find.text('System default'), findsOneWidget);
    expect(find.text('Show weather forecast'), findsOneWidget);
    // City personalisation is parked: the feed is Sierra Leone-wide, so there
    // is no location to manage or to show as followed.
    expect(find.text('Manage locations'), findsNothing);
    expect(find.text('Followed location'), findsNothing);

    // Appearance + About, which the app persisted but had no screen for.
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Text size'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text(SettingsPage.appVersion), findsOneWidget);
  });

  testWidgets('defaults follow the reference screen', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    expect(switchValue(tester, 'Breaking news'), isTrue);
    expect(switchValue(tester, "Editor's picks"), isFalse);
    // On by default: the reference feed shows its finance section without being
    // asked, and the switch hides it.
    expect(switchValue(tester, 'Interactive content'), isTrue);
    expect(switchValue(tester, 'Sports'), isTrue);
    expect(switchValue(tester, 'Show weather forecast'), isTrue);
  });

  testWidgets('a switch writes through to storage', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.text('Sports'));
    await tester.pumpAndSettle();

    expect(userState.sportsAlertsEnabled, isFalse);
    expect(switchValue(tester, 'Sports'), isFalse);

    await tester.tap(find.text("Editor's picks"));
    await tester.pumpAndSettle();

    expect(userState.editorsPicksEnabled, isTrue);
    expect(switchValue(tester, "Editor's picks"), isTrue);
  });

  testWidgets('the personalization switch persists locally', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    expect(switchValue(tester, 'Personalize For You'), isTrue);
    await tester.tap(find.text('Personalize For You'));
    await tester.pumpAndSettle();

    expect(userState.personalizeFeed, isFalse);
    expect(switchValue(tester, 'Personalize For You'), isFalse);
  });

  test(
    'failed rapid personalization writes restore the last durable value',
    () async {
      userState.personalizeWriter = (bool enabled) async {
        throw StateError('write failed');
      };
      final SettingsController controller = container.read(
        settingsControllerProvider.notifier,
      );

      final Future<void> first = controller.setPersonalizeFeed(false);
      final Future<void> second = controller.setPersonalizeFeed(true);
      await Future.wait(<Future<void>>[first, second]);

      expect(
        container.read(settingsControllerProvider).personalizeFeed,
        isTrue,
      );
      expect(userState.personalizeFeed, isTrue);
    },
  );

  testWidgets('rapid personalization taps persist the final intent', (
    WidgetTester tester,
  ) async {
    final Completer<void> gate = Completer<void>();
    userState.personalizeGate = gate;
    await pumpPage(tester);

    await tester.tap(find.text('Personalize For You'));
    await tester.pump();
    expect(switchValue(tester, 'Personalize For You'), isFalse);
    await tester.tap(find.text('Personalize For You'));
    await tester.pump();
    expect(switchValue(tester, 'Personalize For You'), isTrue);

    gate.complete();
    await tester.pumpAndSettle();

    expect(userState.personalizeFeed, isTrue);
    expect(switchValue(tester, 'Personalize For You'), isTrue);
  });

  testWidgets('personalization data can be reviewed and reset', (
    WidgetTester tester,
  ) async {
    container
        .read(personalizationProfileProvider.notifier)
        .recordSave(testArticle(id: 'story-1', title: 'Budget passes'));
    await pumpPage(tester);

    expect(find.text('Personalization data'), findsOneWidget);
    await tester.tap(find.text('Personalization data'));
    await tester.pumpAndSettle();
    expect(find.text('Reset'), findsOneWidget);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(container.read(personalizationProfileProvider).isEmpty, isTrue);
    expect(find.text('Personalization data was reset'), findsOneWidget);
  });

  testWidgets('the weather switch persists', (WidgetTester tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Show weather forecast'));
    await tester.pumpAndSettle();

    expect(userState.weatherForecastEnabled, isFalse);
  });

  testWidgets('theme is chosen from a sheet and applied', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();

    // "System" is both the row's current value and a sheet option; Light and
    // Dark only exist in the sheet.
    expect(find.text('System'), findsNWidgets(2));
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(userState.themeMode, 'dark');
    expect(
      find.text('Dark'),
      findsOneWidget,
      reason: 'the row shows the choice',
    );
  });

  testWidgets('text size is chosen from a sheet and applied', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Default (100%)'), findsOneWidget);

    await tester.tap(find.text('Text size'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('115%'));
    await tester.pumpAndSettle();

    expect(userState.textScale, closeTo(1.15, 0.0001));
    expect(find.text('115%'), findsOneWidget);
  });

  testWidgets('the account row leads to sign-in', (WidgetTester tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('SLNews account'));
    await tester.pumpAndSettle();

    expect(find.text('sign-in route'), findsOneWidget);
  });
  testWidgets('offers one alert toggle for followed topics and newspapers', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    // Newspaper follows share this toggle: both are "things you follow".
    expect(find.text('Topics and newspapers'), findsOneWidget);
    expect(find.textContaining('new story in a topic or from'), findsOneWidget);
  });

  testWidgets('the language picker changes the selected language row', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.text('Language and region'));
    await tester.pumpAndSettle();
    expect(find.text('Français'), findsOneWidget);

    await tester.tap(find.text('Français').last);
    await tester.pumpAndSettle();

    expect(find.text('Français'), findsOneWidget);
  });

  testWidgets('the quiet-hours picker saves a window', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.text('Quiet hours'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Quiet hours saved.'), findsOneWidget);
    expect(find.text('22:00 – 07:00'), findsOneWidget);
  });
}
