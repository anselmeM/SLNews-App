import 'package:flutter/material.dart';
// Riverpod 3 keeps `Override` out of the main entrypoint.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/core/widgets/more_stories_link.dart';
import 'package:slnews_mobile/features/feed/presentation/for_you_page.dart';

import '../feed/support/fakes.dart';
import '../feed/support/test_harness.dart';

/// The reference closes each story group with a right-aligned "More … stories ›"
/// link; this pins both the widget and its place in the For You feed.
void main() {
  Future<void> pumpForYou(WidgetTester tester) async {
    await useTallSurface(tester, size: const Size(390, 3000));
    final GoRouter router = GoRouter(
      initialLocation: '/for_you',
      routes: <RouteBase>[
        GoRoute(
          path: '/for_you',
          builder: (BuildContext context, GoRouterState state) =>
              const ForYouPage(),
        ),
        GoRoute(
          path: '/news',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('news tab')),
        ),
        GoRoute(
          path: '/sports',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('sports tab')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...feedTestOverrides(
            articles: FakeArticleRepository(
              // Distinct ids: the feed's local stream is the intersection of the
              // location feed and the merged stream, so a duplicate would be
              // filtered out and the group would not exist.
              topStories: <Article>[
                testArticle(
                  id: 'top-1',
                  title: 'Budget passes',
                  categoryId: 'top',
                ),
              ],
              localStories: <Article>[
                testArticle(
                  id: 'local-1',
                  title: 'Freetown market reopens',
                  categoryId: 'top',
                ),
              ],
              categoryStories: <Article>[
                testArticle(
                  id: 'latest-1',
                  title: 'Latest elsewhere',
                  categoryId: 'top',
                ),
                testArticle(
                  id: 'sport-1',
                  title: 'Lakers win again',
                  categoryId: 'sports',
                ),
              ],
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('there is no city-scoped group in a Sierra Leone-wide feed', (
    WidgetTester tester,
  ) async {
    await pumpForYou(tester);

    // The rail and its "More <city> stories" link went with city
    // personalisation; the widget itself is still covered below.
    expect(find.textContaining('More Freetown stories'), findsNothing);
    expect(find.text('From Freetown'), findsNothing);
  });

  testWidgets('the widget renders its label and chevron and reports taps', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MoreStoriesLink(
            label: 'More Ottawa stories',
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('More Ottawa stories'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await tester.tap(find.text('More Ottawa stories'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
