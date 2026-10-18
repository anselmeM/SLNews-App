import 'package:flutter/material.dart';
// Riverpod 3 keeps `Override` out of the main entrypoint.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/feed/presentation/top_stories_section_page.dart';

import '../feed/support/fakes.dart';
import '../feed/support/test_harness.dart';

/// The pushed Top stories screen: photo header, story list, and the two failure
/// states a reader can actually hit.
void main() {
  Article story(String id, String title, {String? imageUrl}) =>
      testArticle(id: id, title: title, categoryId: 'top', imageUrl: imageUrl);

  Future<void> pumpSection(
    WidgetTester tester, {
    required FakeArticleRepository articles,
  }) async {
    await useTallSurface(tester, size: const Size(390, 1200));
    final GoRouter router = GoRouter(
      initialLocation: '/top_stories',
      routes: <RouteBase>[
        GoRoute(
          path: '/top_stories',
          builder: (BuildContext context, GoRouterState state) =>
              const TopStoriesSectionPage(),
        ),
        GoRoute(
          path: '/article/:id',
          builder: (BuildContext context, GoRouterState state) =>
              Scaffold(body: Text('article ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/news',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('news tab')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[...feedTestOverrides(articles: articles)],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the header title and the section list', (
    WidgetTester tester,
  ) async {
    await pumpSection(
      tester,
      articles: FakeArticleRepository(
        topStories: <Article>[
          story(
            'a-1',
            'Leone Stars level with Guinea',
            imageUrl: 'https://example.com/hero.jpg',
          ),
          story('a-2', 'Budget passes in parliament'),
        ],
      ),
    );

    expect(find.text('Top stories'), findsOneWidget);
    expect(find.text('Leone Stars level with Guinea'), findsOneWidget);
    expect(find.text('Budget passes in parliament'), findsOneWidget);
  });

  testWidgets('opens a story from the section list', (
    WidgetTester tester,
  ) async {
    await pumpSection(
      tester,
      articles: FakeArticleRepository(
        topStories: <Article>[story('a-1', 'Budget passes in parliament')],
      ),
    );

    await tester.tap(find.text('Budget passes in parliament'));
    await tester.pumpAndSettle();

    expect(find.text('article a-1'), findsOneWidget);
  });

  testWidgets('a failing source offers a retry instead of a blank screen', (
    WidgetTester tester,
  ) async {
    await pumpSection(
      tester,
      articles: FakeArticleRepository(failTopStories: true),
    );

    expect(find.textContaining("couldn't load"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
