import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/ad_placement.dart';
import 'package:slnews_mobile/core/domain/models/ad_unit.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/controllers.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/core/widgets/ad_card.dart';
import 'package:slnews_mobile/core/widgets/article_grid_tile.dart';
import 'package:slnews_mobile/core/widgets/article_hero_card.dart';
import 'package:slnews_mobile/core/widgets/state_views.dart';
import 'package:slnews_mobile/features/news/presentation/news_page.dart';
import 'package:slnews_mobile/features/news/presentation/widgets/category_pill_header.dart';

import 'support/fakes.dart';

/// The fixture unit the News tab's own `news_stream` placement returns.
const AdUnit kFakeNewsStreamAd = AdUnit(
  id: 'ad-news-1',
  headline: 'NEWS STREAM OFFER',
  body: 'A sold unit from the news_stream placement.',
  ctaLabel: 'View more',
  advertiser: 'News Stream Partner',
);

/// Headline of the `top` hero in [defaultNewsFixtures].
const String topHeadline =
    'Bo government hospital receives new dialysis machines from partners';

/// Headline of the `politics` hero in [defaultNewsFixtures].
const String politicsHeadline =
    'Parliament passes the 2026 budget after a marathon overnight sitting';

void main() {
  // `flutter_test` measures text with the Ahem placeholder face (one full em per
  // glyph) unless a real font is loaded, which would report overflows for
  // layouts that are fine on device. Loading the app's bundled Inter makes the
  // narrow-width assertions measure the same text the reader sees.
  setUpAll(() async {
    final ByteData data = ByteData.sublistView(
      File('assets/fonts/Inter-Variable.ttf').readAsBytesSync(),
    );
    final FontLoader loader = FontLoader('SLNewsSans')
      ..addFont(Future<ByteData>.value(data));
    await loader.load();
  });

  group('NewsPage', () {
    testWidgets('renders the hero headline of the selected category', (
      WidgetTester tester,
    ) async {
      await pumpNewsPage(tester);

      expect(find.text(topHeadline), findsOneWidget);
      // The pinned strip renders the label as a pill; the content renders the
      // large in-content title with the same text.
      expect(find.text('Top stories'), findsWidgets);
      expect(find.byType(CategoryPillHeader), findsOneWidget);
    });

    testWidgets(
      'tapping the Politics pill swaps the hero to a politics story',
      (WidgetTester tester) async {
        await pumpNewsPage(tester);
        expect(find.text(topHeadline), findsOneWidget);
        expect(find.text(politicsHeadline), findsNothing);

        await tester.tap(find.text('Politics').first);
        await tester.pumpAndSettle();

        expect(find.text(topHeadline), findsNothing);
        expect(find.text(politicsHeadline), findsOneWidget);
      },
    );

    testWidgets('renders the two-column grid of ArticleGridTiles', (
      WidgetTester tester,
    ) async {
      await pumpNewsPage(tester);

      expect(find.byType(ArticleGridTile), findsWidgets);
      // The grid is a SliverGrid inside the page's single scroll view, never a
      // nested GridView with its own scroll position.
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('falls back to latest stories for a category with no stories', (
      WidgetTester tester,
    ) async {
      await pumpNewsPage(tester);

      await tester.tap(find.text('Cars and Vehicles'));
      await tester.pumpAndSettle();

      // A quiet category must never leave the tab blank; the page shows the
      // latest feed under the selected category heading instead.
      expect(find.byType(EmptyStateView), findsNothing);
      expect(find.text(topHeadline), findsOneWidget);
      expect(
        find.textContaining(
          'No cars and vehicles stories right now — showing the latest news.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('inserts one in-stream ad after the third Latest row', (
      WidgetTester tester,
    ) async {
      await pumpNewsPage(tester, size: const Size(800, 3200));

      expect(find.byType(AdCard), findsOneWidget);
      expect(find.text(kFakeNewsStreamAd.headline), findsOneWidget);
    });

    testWidgets('requests and paints news_stream, never the shared feed slot', (
      WidgetTester tester,
    ) async {
      const AdUnit feedAd = AdUnit(
        id: 'ad-feed-decoy',
        headline: 'FEED DECOY',
        body: 'This unit belongs to the For You pool.',
        ctaLabel: 'View more',
        advertiser: 'Feed Partner',
      );
      final FakeAdRepository ads = FakeAdRepository(
        unitsForPlacement: <String, List<AdUnit>>{
          AdPlacement.newsStream.wire: const <AdUnit>[kFakeNewsStreamAd],
          AdPlacement.feed.wire: const <AdUnit>[feedAd],
        },
      );
      await pumpNewsPage(
        tester,
        size: const Size(800, 3200),
        adRepository: ads,
      );

      expect(find.text(kFakeNewsStreamAd.headline), findsOneWidget);
      expect(find.text(feedAd.headline), findsNothing);
      expect(ads.requestedPlacements, contains(AdPlacement.newsStream.wire));
      expect(
        ads.requestedPlacements,
        isNot(contains(AdPlacement.feed.wire)),
        reason: 'News has its own slot and no longer shares the feed pool',
      );
    });

    testWidgets('keeps the two-column grid and truncates 60+ char headlines', (
      WidgetTester tester,
    ) async {
      // Long Sierra Leonean headlines (60+ characters) must ellipsize, never
      // clip: `ArticleGridTile` is told to use three lines with an ellipsis.
      await pumpNewsPage(
        tester,
        articles: <String, List<Article>>{
          'top': <Article>[
            fakeArticle(id: 'long-hero', title: kLongHeadline),
            for (int index = 2; index <= 9; index++)
              fakeArticle(
                id: 'long-$index',
                title: kLongHeadline,
                minutesAgo: index * 10,
              ),
          ],
        },
      );

      final ArticleGridTile tile = tester.widget<ArticleGridTile>(
        find.byType(ArticleGridTile).first,
      );
      expect(tile.maxTitleLines, 3);
      expect(find.text(kLongHeadline), findsWidgets);
      // The hero still renders above the grid on the same single scroll view.
      expect(find.byType(ArticleHeroCard), findsOneWidget);
    });
  });
}

/// Pumps [NewsPage] with every repository replaced by an in-memory fake.
///
/// The surface defaults to 800x2400 so the lazily-built grid and the first list
/// rows are actually laid out; a shorter surface would silently skip them.
Future<void> pumpNewsPage(
  WidgetTester tester, {
  Map<String, List<Article>>? articles,
  Size size = const Size(800, 2400),
  double textScale = 1,
  List<AdUnit> ads = const <AdUnit>[kFakeNewsStreamAd],
  FakeAdRepository? adRepository,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final FakeArticleRepository articleRepository = FakeArticleRepository(
    byCategory: articles ?? defaultNewsFixtures(),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        articleRepositoryProvider.overrideWithValue(articleRepository),
        adRepositoryProvider.overrideWithValue(
          adRepository ??
              FakeAdRepository(
                unitsForPlacement: <String, List<AdUnit>>{
                  AdPlacement.newsStream.wire: ads,
                },
              ),
        ),
        userStateProvider.overrideWithValue(FakeUserStateRepository()),
        refreshFeedsProvider.overrideWithValue(() async {}),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(theme: AppTheme.light(), home: const NewsPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
