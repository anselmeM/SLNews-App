import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/article/presentation/article_web_page.dart';

import '../feed/support/fakes.dart';
import '../feed/support/test_harness.dart';

/// The web reader's degraded paths must never leave a blank screen: offline, a
/// story without a link, and a publisher page that refuses to load all land on
/// the native reader instead.
void main() {
  Article story({String? sourceUrl = 'https://example.com/budget'}) =>
      testArticle(
        id: 'story-1',
        title: 'Parliament passes the 2027 budget',
        summary: 'Spending targets education and health.',
        publishedAt: DateTime.utc(2026, 10, 16, 19, 30),
        sourceUrl: sourceUrl,
      );

  Future<void> pumpWebReader(
    WidgetTester tester,
    Article article, {
    bool offline = false,
  }) async {
    await useTallSurface(tester, size: const Size(390, 2200));
    final GoRouter router = GoRouter(
      initialLocation: '/article/${article.id}/original',
      routes: <RouteBase>[
        GoRoute(
          path: '/article/:id',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('native reader')),
        ),
        GoRoute(
          path: '/article/:id/original',
          builder: (BuildContext context, GoRouterState state) =>
              ArticleWebPage(articleId: state.pathParameters['id'] ?? ''),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: feedTestOverrides(
          articles: FakeArticleRepository(
            topStories: <Article>[article],
            categoryStories: <Article>[article],
            isOffline: offline,
          ),
        ),
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('explains an offline device and offers the native reader', (
    WidgetTester tester,
  ) async {
    await pumpWebReader(tester, story(), offline: true);

    expect(find.text("You're offline"), findsOneWidget);
    expect(find.text('Read in SLNews reader'), findsOneWidget);
  });

  testWidgets('explains a story with no published link', (
    WidgetTester tester,
  ) async {
    await pumpWebReader(tester, story(sourceUrl: null));

    expect(find.text('No original page'), findsOneWidget);
    expect(find.text('Read in SLNews reader'), findsOneWidget);
  });

  testWidgets('keeps the reader chrome over the page', (
    WidgetTester tester,
  ) async {
    await pumpWebReader(tester, story(), offline: true);

    // Back and a way back to the native reader, even with no page loaded.
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byTooltip('Read in the SLNews reader'), findsOneWidget);
  });
}
