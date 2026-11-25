import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slnews_mobile/core/domain/models/ad_unit.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/core/widgets/ad_card.dart';
import 'package:slnews_mobile/core/widgets/section_header.dart';
import 'package:slnews_mobile/core/widgets/video_moment_card.dart';
import 'package:slnews_mobile/features/feed/presentation/for_you_page.dart';

import 'package:slnews_mobile/core/utils/time_ago.dart';

import 'support/fakes.dart';
import 'support/test_harness.dart';

/// Widget tests for Tab 1.
///
/// The router is assembled from the frozen route constants rather than
/// `createAppRouter()` so this test file only depends on the Feed feature (the
/// shared router also mounts the other agents' tab pages).
void main() {
  setUp(() => appNow = () => DateTime(2026, 10, 15, 20));
  tearDown(() => appNow = () => DateTime.now());

  final Article breaking = testArticle(
    id: 'breaking-1',
    title: 'Breaking: bridge closed after storm',
    publishedAt: DateTime(2026, 10, 15, 17),
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
    FakeAdRepository? adRepository,
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
          adRepository: adRepository,
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
      final Article extra = testArticle(
        id: 'extra-1',
        title: 'A fourth stream story',
        publishedAt: DateTime(2026, 10, 15, 16),
      );
      final Article extra2 = testArticle(
        id: 'extra-2',
        title: 'A fifth stream story',
        publishedAt: DateTime(2026, 10, 15, 15),
      );
      await pumpForYou(
        tester,
        articles: FakeArticleRepository(
          topStories: <Article>[newest, breaking],
          localStories: <Article>[local],
          categoryStories: <Article>[latest, extra, extra2],
        ),
      );

      expect(find.text('Top stories'), findsWidgets);
      // Once in the dismissible alert row, once on the hero card.
      expect(
        find.text('Breaking: bridge closed after storm'),
        findsNWidgets(2),
      );
      expect(find.text('BREAKING'), findsNWidgets(2));
      expect(find.text('29°'), findsOneWidget);
      expect(find.text('Thundery showers'), findsOneWidget);
      expect(find.textContaining('DAILY BRIEFING'), findsOneWidget);
      // The feed covers Sierra Leone as a whole, so the city-scoped rail is
      // gone even when the repository can serve a city feed.
      expect(find.text('From Freetown'), findsNothing);
      expect(find.text('Local story in Freetown'), findsNothing);
      // The briefing card owns the first stream stories; Latest may start
      // below the fold in this compact fixture.
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

    // The story is not in the home pool; it arrives because Business is followed
    // and is explained by the dedicated follows rail.
    expect(find.text('From your follows'), findsOneWidget);
    expect(find.text('Port expansion wins backing'), findsOneWidget);
  });

  testWidgets('turning personalization off hides the follows rail', (
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
    final FakeUserStateRepository userState = FakeUserStateRepository()
      ..personalizeFeed = false;

    await pumpForYou(
      tester,
      articles: articles,
      following: following,
      userState: userState,
    );

    expect(find.text('From your follows'), findsNothing);
    // The followed category feed still exists; it is just not personalised.
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
    // The alert row also renders the headline; it is not a stream duplicate.
    expect(find.text('Breaking: bridge closed after storm'), findsNWidgets(2));
  });

  testWidgets('breaking alert row can be dismissed without hiding the hero', (
    WidgetTester tester,
  ) async {
    await pumpForYou(tester);

    expect(find.byTooltip('Dismiss breaking alert'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss breaking alert'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Dismiss breaking alert'), findsNothing);
    expect(find.text('Breaking: bridge closed after storm'), findsOneWidget);
    expect(find.text('BREAKING'), findsOneWidget);
  });

  testWidgets('tapping a briefing story pushes the article route', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await pumpForYou(tester);

    // The briefing card owns the first stream stories, so this asserts the
    // merged card -> reader wiring rather than a duplicated feed tile.
    final Finder story = find.text('Only in the latest stream');
    expect(story, findsOneWidget);
    await tester.ensureVisible(story);
    await tester.pumpAndSettle();
    await tester.tap(story);
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

  testWidgets('renders up to two server-selected feed units in server order', (
    WidgetTester tester,
  ) async {
    // The backend selects at most two `feed` units and owns their order. The
    // ids are intentionally unsorted so a client-side reshuffle would fail.
    final FakeAdRepository ads = FakeAdRepository(
      rotation: <AdUnit>[
        const AdUnit(
          id: 'ad-zulu-first',
          headline: 'ZULU SERVER UNIT',
          body: 'First in the server-selected order',
          ctaLabel: 'View more',
          advertiser: 'Zulu Partner',
        ),
        const AdUnit(
          id: 'ad-alpha-second',
          headline: 'ALPHA SERVER UNIT',
          body: 'Second in the server-selected order',
          ctaLabel: 'View more',
          advertiser: 'Alpha Partner',
        ),
      ],
    );
    await pumpForYou(
      tester,
      surface: const Size(390, 6200),
      articles: railRepository(),
      adRepository: ads,
    );

    final List<AdCard> cards = tester
        .widgetList<AdCard>(find.byType(AdCard))
        .toList();
    expect(cards, hasLength(2), reason: 'both returned feed units display');
    expect(cards[0].unit.id, 'ad-zulu-first');
    expect(cards[1].unit.id, 'ad-alpha-second');
    expect(ads.requestedPlacements, contains('feed'));
    expect(find.text('ZULU SERVER UNIT'), findsOneWidget);
    expect(find.text('ALPHA SERVER UNIT'), findsOneWidget);
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
