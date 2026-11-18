import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slnews_mobile/core/domain/models/ad_unit.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/core/widgets/ad_card.dart';
import 'package:slnews_mobile/core/widgets/article_tile.dart';
import 'package:slnews_mobile/core/widgets/section_header.dart';
import 'package:slnews_mobile/core/widgets/video_moment_card.dart';
import 'package:slnews_mobile/features/feed/presentation/for_you_page.dart';
import 'package:slnews_mobile/features/feed/presentation/widgets/weather_alert_header.dart';

import 'support/fakes.dart';
import 'support/test_harness.dart';

/// Widget tests for Tab 1.
///
/// The router is assembled from the frozen route constants rather than
/// `createAppRouter()` so this test file only depends on the Feed feature (the
/// shared router also mounts the other agents' tab pages).
void main() {
  final Article breaking = testArticle(
    id: 'breaking-1',
    title: 'Breaking: bridge closed after storm',
    publishedAt: DateTime(2026, 10, 15, 6),
    isBreaking: true,
  );
  final Article newest = testArticle(
    id: 'newest-1',
    title: 'Newest story from the capital',
    publishedAt: DateTime(2026, 10, 15, 18),
  );
  final Article local = testArticle(
    id: 'local-1',
    title: 'Local story in Freetown',
    publishedAt: DateTime(2026, 10, 15, 7),
    categoryId: 'community',
  );
  final Article latest = testArticle(
    id: 'latest-1',
    title: 'Only in the latest stream',
    publishedAt: DateTime(2026, 10, 15, 5),
    categoryId: 'politics',
  );

  FakeArticleRepository repository() => FakeArticleRepository(
    topStories: <Article>[newest, breaking],
    localStories: <Article>[local],
    categoryStories: <Article>[latest],
  );

  Future<GoRouter> pumpForYou(
    WidgetTester tester, {
    FakeArticleRepository? articles,
    FakeUserStateRepository? userState,
    FakeWeatherRepository? weather,
    List<AdUnit> ads = const <AdUnit>[],
    Size surface = const Size(390, 2200),
    FakeFollowingRepository? following,
  }) async {
    await useTallSurface(tester, size: surface);
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
              const Scaffold(body: Text('news route')),
        ),
        GoRoute(
          path: '/article/:id',
          builder: (BuildContext context, GoRouterState state) =>
              Scaffold(body: Text('article ${state.pathParameters['id']}')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: feedTestOverrides(
          articles: articles ?? repository(),
          userState: userState,
          weather: weather,
          ads: ads,
          following: following,
        ),
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets(
    'renders hero headline, breaking tag, weather label and streams',
    (WidgetTester tester) async {
      await pumpForYou(tester);

      expect(find.text('Top stories'), findsWidgets);
      expect(find.text('Breaking: bridge closed after storm'), findsOneWidget);
      // Once on the hero card, once in the weather/alert header.
      expect(find.text('BREAKING'), findsNWidgets(2));
      expect(find.text('29° · Thundery showers'), findsOneWidget);
      // The feed covers Sierra Leone as a whole, so the city-scoped rail is
      // gone even when the repository can serve a city feed.
      expect(find.text('From Freetown'), findsNothing);
      expect(find.text('Local story in Freetown'), findsNothing);
      expect(find.text('Latest'), findsOneWidget);
      expect(find.text('Only in the latest stream'), findsOneWidget);
    },
  );

  testWidgets('a followed topic brings its stories into the feed', (
    WidgetTester tester,
  ) async {
    final FakeArticleRepository articles = FakeArticleRepository(
      topStories: <Article>[newest],
    );
    articles.seed('business', <Article>[
      testArticle(
        id: 'biz-1',
        title: 'Port expansion wins backing',
        categoryId: 'business',
        publishedAt: DateTime(2026, 10, 15, 8),
      ),
    ]);
    const FollowTarget business = FollowTarget(
      id: 'topic:business',
      kind: FollowKind.topic,
      label: 'Business',
    );
    final FakeFollowingRepository following = FakeFollowingRepository(
      catalogue: const <FollowTarget>[business],
    );
    await following.follow(business);

    await pumpForYou(tester, articles: articles, following: following);

    // The story is not in the home pool; it arrives because Business is followed.
    expect(find.text('Port expansion wins backing'), findsOneWidget);
  });

  testWidgets('an unfollowed topic stays out of the feed', (
    WidgetTester tester,
  ) async {
    final FakeArticleRepository articles = FakeArticleRepository(
      topStories: <Article>[newest],
    );
    articles.seed('business', <Article>[
      testArticle(
        id: 'biz-1',
        title: 'Port expansion wins backing',
        categoryId: 'business',
        publishedAt: DateTime(2026, 10, 15, 8),
      ),
    ]);

    await pumpForYou(tester, articles: articles);

    expect(find.text('Port expansion wins backing'), findsNothing);
  });

  testWidgets('never repeats a story between the carousel and the streams', (
    WidgetTester tester,
  ) async {
    await pumpForYou(tester);

    // The newest story is the second hero page, so it must not also be a tile.
    expect(find.text('Newest story from the capital'), findsOneWidget);
    expect(find.text('Breaking: bridge closed after storm'), findsOneWidget);
  });

  testWidgets('tapping a tile pushes the article route', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpForYou(tester);

    // The latest tile sits below the fold on the test surface, so it is scrolled
    // into view and its callback is invoked directly: synthetic taps inside a
    // scrolled sliver are unreliable here, while this asserts the wiring that
    // matters (tile -> reader route). `push` keeps `/for_you` in the router's
    // reported configuration, so the pushed page is asserted instead.
    final Finder tile = find.widgetWithText(
      ArticleTile,
      'Only in the latest stream',
    );
    expect(tile, findsOneWidget);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();

    final ArticleTile tileWidget = tester.widget<ArticleTile>(tile);
    expect(
      tileWidget.onTap,
      isNotNull,
      reason: 'feed tiles must open the reader',
    );
    tileWidget.onTap!();
    await tester.pumpAndSettle();

    expect(find.text('article latest-1'), findsOneWidget);
    expect(
      router.canPop(),
      isTrue,
      reason: 'the reader is pushed over the feed',
    );
  });

  testWidgets('shows the offline banner when the repository is offline', (
    WidgetTester tester,
  ) async {
    await pumpForYou(
      tester,
      articles: FakeArticleRepository(
        topStories: <Article>[newest],
        isOffline: true,
        lastSyncedAt: DateTime(2026, 10, 15, 7, 30),
      ),
    );

    expect(find.textContaining('Offline'), findsOneWidget);
  });

  testWidgets('shows an error state instead of a raw exception', (
    WidgetTester tester,
  ) async {
    await pumpForYou(
      tester,
      articles: FakeArticleRepository(
        topStories: <Article>[newest],
        failTopStories: true,
      ),
    );

    expect(find.text("We couldn't load this right now."), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the empty state when every stream is empty', (
    WidgetTester tester,
  ) async {
    await pumpForYou(tester, articles: FakeArticleRepository());

    expect(find.text('No stories yet'), findsOneWidget);
  });

  testWidgets('weather chip survives a 320pt screen at 1.3 text scale', (
    WidgetTester tester,
  ) async {
    final FakeWeatherRepository weather = FakeWeatherRepository(
      throwOnCurrent: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: feedTestOverrides(
          articles: FakeArticleRepository(),
          weather: weather,
        ),
        child: themedChild(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: 304,
                child: WeatherAlertHeader(
                  location: SlLocations.fallback,
                  hasBreaking: true,
                ),
              ),
            ),
          ),
          textScaler: 1.3,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Thundery showers'), findsOneWidget);
    expect(find.text('BREAKING'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  /// The feed's stream excludes the six hero stories and the page shows three
  /// rails of four, so a fixture needs 6 + 12 = 18 stories to fill them.
  FakeArticleRepository railRepository() => FakeArticleRepository(
    topStories: <Article>[
      for (int index = 0; index < 8; index++)
        testArticle(
          id: 'hero-$index',
          title: 'Hero story $index',
          publishedAt: DateTime(2026, 10, 15, 21 - index),
        ),
    ],
    categoryStories: <Article>[
      for (int index = 0; index < 18; index++)
        testArticle(
          id: 'rail-$index',
          title: 'Rail story $index',
          publishedAt: DateTime(2026, 10, 15, 14 - index, 30),
        ),
    ],
  );

  testWidgets('renders the reference rails with content', (
    WidgetTester tester,
  ) async {
    await pumpForYou(
      tester,
      surface: const Size(390, 6200),
      articles: railRepository(),
    );

    expect(find.text('Video moments'), findsOneWidget);
    expect(find.text("See what's new"), findsOneWidget);
    expect(find.byType(VideoMomentCard), findsWidgets);

    expect(find.text('Picks for you'), findsOneWidget);
    expect(find.text('Articles you might enjoy'), findsOneWidget);

    expect(find.text('Your next read'), findsOneWidget);
    expect(find.text('Based on your interests'), findsOneWidget);
  });

  testWidgets('interleaves a sponsored card from the rotation', (
    WidgetTester tester,
  ) async {
    await pumpForYou(
      tester,
      surface: const Size(390, 6200),
      articles: railRepository(),
      ads: <AdUnit>[
        const AdUnit(
          id: 'ad-1',
          headline: 'Ultimate Shopping Spree',
          body: 'Deals of the week',
          ctaLabel: 'View more',
          advertiser: 'Shop Direct',
        ),
      ],
    );

    expect(find.byType(AdCard), findsOneWidget);
    expect(find.text('Ultimate Shopping Spree'), findsOneWidget);
    expect(find.text('AD'), findsWidgets, reason: 'sponsored must be labelled');
  });

  testWidgets('shows the Following topic mosaic', (WidgetTester tester) async {
    await pumpForYou(
      tester,
      surface: const Size(390, 6200),
      articles: railRepository(),
    );

    expect(find.widgetWithText(SectionHeader, 'Following'), findsOneWidget);
    // Categories with no story image still render a readable fallback card.
    expect(find.text('Cars and Vehicles'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
  });

  testWidgets('the More affordance opens the News tab', (
    WidgetTester tester,
  ) async {
    await pumpForYou(
      tester,
      surface: const Size(390, 6200),
      articles: railRepository(),
    );

    await tester.tap(find.text('More').first);
    await tester.pumpAndSettle();

    expect(find.text('news route'), findsOneWidget);
  });

  testWidgets('the back-to-top button scrolls back to the top', (
    WidgetTester tester,
  ) async {
    await pumpForYou(
      tester,
      surface: const Size(390, 844),
      articles: railRepository(),
    );

    expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1600));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
    await tester.pumpAndSettle();

    expect(
      find.byIcon(Icons.keyboard_arrow_up),
      findsNothing,
      reason: 'the button hides again once the feed is back at the top',
    );
  });
}
