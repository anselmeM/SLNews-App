import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slnews_mobile/core/widgets/page_menu_button.dart';

/// The page-level kebab menu from the reference screen: Settings and Notices.
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

  testWidgets('offers Settings and Notices', (WidgetTester tester) async {
    await pumpMenu(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Notices'), findsOneWidget);
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
}
