import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/core/widgets/page_menu_button.dart';

/// The page-level kebab menu: Saved stories (the route needs an entry point),
/// Settings and Notices.
void main() {
  GoRouter router() => GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) => Scaffold(
          appBar: AppBar(
            title: const Text('Top stories'),
            actions: const <Widget>[PageMenuButton()],
          ),
        ),
      ),
      GoRoute(
        path: '/search',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('search screen')),
      ),
      GoRoute(
        path: '/saved',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('saved screen')),
      ),
      GoRoute(
        path: '/settings',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('settings screen')),
      ),
      GoRoute(
        path: '/following/notifications',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('notices screen')),
      ),
    ],
  );

  Future<void> pumpMenu(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
  }

  testWidgets('offers Search, Saved stories, Settings and Notices', (
    WidgetTester tester,
  ) async {
    await pumpMenu(tester);

    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Saved stories'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Notices'), findsOneWidget);
  });

  testWidgets('Search opens the search screen', (WidgetTester tester) async {
    await pumpMenu(tester);
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(find.text('search screen'), findsOneWidget);
  });

  testWidgets('Saved stories opens the saved list', (
    WidgetTester tester,
  ) async {
    await pumpMenu(tester);
    await tester.tap(find.text('Saved stories'));
    await tester.pumpAndSettle();

    expect(find.text('saved screen'), findsOneWidget);
  });

  testWidgets('Settings opens the settings screen', (
    WidgetTester tester,
  ) async {
    await pumpMenu(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('settings screen'), findsOneWidget);
  });

  testWidgets('Notices opens the notification history', (
    WidgetTester tester,
  ) async {
    await pumpMenu(tester);
    await tester.tap(find.text('Notices'));
    await tester.pumpAndSettle();

    expect(find.text('notices screen'), findsOneWidget);
  });

  testWidgets('the menu surface stays white on the app-bar white', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    // Material 3 would tint this with surfaceContainer, which reads grey next to
    // the app bar; the reference keeps the little menu white.
    final Iterable<Material> materials = tester.widgetList<Material>(
      find.ancestor(of: find.text('Settings'), matching: find.byType(Material)),
    );
    expect(
      materials.any(
        (Material material) => material.color == const Color(0xFFFFFFFF),
      ),
      isTrue,
      reason: 'the popup menu should sit on the white surface token',
    );
  });
}
