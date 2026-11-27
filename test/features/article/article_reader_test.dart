import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/personalization_profile.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/personalization_profile.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/core/utils/time_ago.dart';
import 'package:slnews_mobile/core/widgets/publisher_mark.dart';
import 'package:slnews_mobile/features/article/presentation/article_page.dart';
import 'package:slnews_mobile/features/article/presentation/widgets/reading_progress_bar.dart';
import 'package:slnews_mobile/features/article/presentation/widgets/translate_sheet.dart';

import '../feed/support/fakes.dart';
import '../feed/support/test_harness.dart';

/// Reader polish: the outlet wordmark in the bar, the byline/date line, and the
/// translate action in the floating bar.
void main() {
  Article story({String? sourceUrl = 'https://example.com/budget'}) =>
      testArticle(
        id: 'story-1',
        title: 'Parliament passes the 2027 budget',
        summary: 'Spending targets education and health.',
        publishedAt: DateTime.utc(2026, 10, 16, 19, 30),
        sourceUrl: sourceUrl,
        author: 'Amara Bangura',
        categoryId: 'politics',
      );

  Future<void> pumpReader(
    WidgetTester tester,
    Article article, {
    Size surface = const Size(390, 2400),
    bool pushFromHome = false,
    double? initialProgress,
    FakeUserStateRepository? userState,
  }) async {
    await useTallSurface(tester, size: surface);
    final GoRouter router = GoRouter(
      initialLocation: pushFromHome ? '/' : '/article/${article.id}',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/article/:id',
          builder: (BuildContext context, GoRouterState state) {
            final Object? extra = state.extra;
            return ArticlePage(
              articleId: state.pathParameters['id'] ?? '',
              initialProgress: extra is num ? extra.toDouble() : null,
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...feedTestOverrides(
            articles: FakeArticleRepository(
              topStories: <Article>[article],
              categoryStories: <Article>[article],
            ),
            userState: userState,
          ),
          preferencesStoreProvider.overrideWithValue(
            InMemoryPreferencesStore(),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (pushFromHome) {
      router.push('/article/${article.id}', extra: initialProgress);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('an image without a supplied credit names the publisher', (
    WidgetTester tester,
  ) async {
    final Article article = testArticle(
      id: 'story-image',
      title: 'Freetown market reopens after renovation',
      imageUrl: 'https://cdn.example.com/market.jpg',
      publishedAt: DateTime.utc(2026, 10, 16, 19, 30),
    );
    await pumpReader(tester, article);

    expect(
      find.textContaining('Photo: ${article.publisher.name}'),
      findsOneWidget,
    );
  });

  testWidgets('the action bar exposes text size, share and translate', (
    WidgetTester tester,
  ) async {
    await pumpReader(tester, story());

    expect(find.text('aA'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Tooltip && (widget.message ?? '').startsWith('Text size'),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.ios_share), findsOneWidget);
    expect(find.byIcon(Icons.translate), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
  });

  testWidgets('shows the publisher wordmark in the bar and the header', (
    WidgetTester tester,
  ) async {
    final Article article = story();
    await pumpReader(tester, article);

    // Once in the app bar, once above the headline.
    expect(find.byType(PublisherMark), findsNWidgets(2));
    expect(find.text(article.publisher.mark), findsNWidgets(2));
  });

  testWidgets('shows the byline, publication time and reading time', (
    WidgetTester tester,
  ) async {
    final Article article = story();
    await pumpReader(tester, article);

    expect(find.text('By Amara Bangura'), findsOneWidget);
    final String zone = TimeAgo.localZoneLabel;
    expect(
      find.text(
        TimeAgo.published(
          article.publishedAt,
          timeZoneLabel: zone.isEmpty ? null : zone,
        ),
      ),
      findsOneWidget,
      reason:
          'the reference prints "Published: October 16, 2026 at 7:30 p.m. EDT"',
    );
    expect(find.textContaining('min read'), findsOneWidget);
    // Section eyebrow above the wordmark, in the reference's red.
    expect(find.text('Politics'), findsOneWidget);
  });

  testWidgets('the floating bar offers translate and lists languages', (
    WidgetTester tester,
  ) async {
    await pumpReader(tester, story());

    expect(find.byIcon(Icons.translate), findsOneWidget);

    await tester.tap(find.byIcon(Icons.translate));
    await tester.pumpAndSettle();

    expect(find.text('Translate story'), findsOneWidget);
    expect(find.text('French'), findsOneWidget);
    expect(find.text('Portuguese'), findsOneWidget);
    expect(find.text('Arabic'), findsOneWidget);
  });

  testWidgets('translating a story without a link explains why it cannot', (
    WidgetTester tester,
  ) async {
    await pumpReader(tester, story(sourceUrl: null));

    await tester.tap(find.byIcon(Icons.translate));
    await tester.pumpAndSettle();
    await tester.tap(find.text('French'));
    await tester.pumpAndSettle();

    expect(
      find.text('Translation needs the original story link'),
      findsOneWidget,
    );
  });

  test(
    'the translation URL carries the language and the encoded story link',
    () {
      final Article article = story();
      final Uri? uri = translationUriFor(article, TranslateLanguage.french);

      expect(uri, isNotNull);
      expect(uri!.host, 'translate.google.com');
      expect(uri.queryParameters['sl'], 'auto');
      expect(uri.queryParameters['tl'], 'fr');
      expect(uri.queryParameters['u'], 'https://example.com/budget');

      expect(
        translationUriFor(
          article,
          TranslateLanguage.chinese,
        )!.queryParameters['tl'],
        'zh-CN',
      );
      expect(
        translationUriFor(story(sourceUrl: null), TranslateLanguage.french),
        isNull,
      );
    },
  );

  testWidgets('the byline carries the device time-zone abbreviation', (
    WidgetTester tester,
  ) async {
    final Article article = story();
    await pumpReader(tester, article);

    final String zone = TimeAgo.localZoneLabel;
    expect(
      find.text(
        TimeAgo.published(
          article.publishedAt,
          timeZoneLabel: zone.isEmpty ? null : zone,
        ),
      ),
      findsOneWidget,
      reason: 'the reference reads "Oct 16, 2026 7:30 pm EDT"',
    );
  });

  testWidgets('the reader offers back-to-top after scrolling', (
    WidgetTester tester,
  ) async {
    final Article long = Article(
      id: 'long-1',
      title: 'A long read about the budget',
      summary: 'Summary',
      bodyHtml: List<String>.generate(
        24,
        (int index) => '<p>Paragraph $index of a long story.</p>',
      ).join(),
      publisher: testPublisher,
      publishedAt: DateTime.utc(2026, 10, 16, 19, 30),
      categoryId: 'politics',
    );

    await pumpReader(tester, long, surface: const Size(390, 844));
    expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
    await tester.pumpAndSettle();
    expect(
      find.byIcon(Icons.keyboard_arrow_up),
      findsNothing,
      reason: 'the button hides again at the top of the story',
    );
  });

  testWidgets('a preview story offers one publisher hand-off', (
    WidgetTester tester,
  ) async {
    final Article preview = Article(
      id: 'preview-1',
      title: 'A story we may only preview',
      summary: 'The opening two sentences are shown here.',
      publisher: testPublisher,
      publishedAt: DateTime.utc(2026, 10, 16, 19, 30),
      sourceUrl: 'https://example.com/preview',
      previewOnly: true,
    );

    await pumpReader(tester, preview);

    expect(find.text('Preview'), findsOneWidget);
    expect(find.text(preview.summary), findsOneWidget);
    expect(
      find.text('Full story at ${preview.publisher.name}.'),
      findsOneWidget,
    );
    expect(find.text('Read full story'), findsOneWidget);
  });

  testWidgets('leaving the reader records local engagement', (
    WidgetTester tester,
  ) async {
    final Article article = story();
    await pumpReader(tester, article, pushFromHome: true);
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(ArticlePage)),
    );

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    final PersonalizationProfile profile = container.read(
      personalizationProfileProvider,
    );
    expect(profile.events, isNotEmpty);
    expect(
      profile.events.any(
        (EngagementEvent event) =>
            event.articleId == article.id && event.dwellSeconds != null,
      ),
      isTrue,
    );
    expect(profile.progress[article.id], isNotNull);
  });

  testWidgets('an unscrolled scrollable article keeps zero progress', (
    WidgetTester tester,
  ) async {
    final Article article = Article(
      id: 'unscrolled',
      title: 'A long report',
      publisher: testPublisher,
      publishedAt: DateTime.utc(2026, 10, 16, 19, 30),
      categoryId: 'politics',
      bodyHtml: List<String>.generate(
        40,
        (int index) => '<p>Paragraph $index.</p>',
      ).join(),
    );
    await pumpReader(
      tester,
      article,
      surface: const Size(390, 600),
      pushFromHome: true,
    );
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(ArticlePage)),
    );

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    final PersonalizationProfile profile = container.read(
      personalizationProfileProvider,
    );
    expect(profile.progress[article.id], isNull);
    expect(
      profile.events
          .where((EngagementEvent event) => event.articleId == article.id)
          .every((EngagementEvent event) => (event.progress ?? 0) == 0),
      isTrue,
    );
  });

  testWidgets('continue reading restores the saved scroll offset', (
    WidgetTester tester,
  ) async {
    final Article article = Article(
      id: 'resume-long',
      title: 'A long report to resume',
      publisher: testPublisher,
      publishedAt: DateTime.utc(2026, 10, 16, 19, 30),
      categoryId: 'politics',
      bodyHtml: List<String>.generate(
        40,
        (int index) => '<p>Paragraph $index.</p>',
      ).join(),
    );
    await pumpReader(
      tester,
      article,
      surface: const Size(390, 600),
      pushFromHome: true,
      initialProgress: 0.5,
    );
    final ArticlePage page = tester.widget<ArticlePage>(
      find.byType(ArticlePage),
    );
    expect(page.initialProgress, 0.5);

    final ScrollableState scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.pixels, greaterThan(0));
  });

  testWidgets('opting out stops profile collection', (
    WidgetTester tester,
  ) async {
    final FakeUserStateRepository userState = FakeUserStateRepository()
      ..personalizeFeed = false;
    await pumpReader(tester, story(), userState: userState, pushFromHome: true);
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(ArticlePage)),
    );

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(container.read(personalizationProfileProvider).events, isEmpty);
  });

  testWidgets('a licensed full story has no preview hand-off', (
    WidgetTester tester,
  ) async {
    await pumpReader(tester, story());

    expect(find.text('Preview'), findsNothing);
    expect(find.text('Read full story'), findsNothing);
  });

  group('time-zone label', () {
    test('reduces platform names to an abbreviation', () {
      expect(
        TimeAgo.zoneLabelFor(
          'Eastern Daylight Time',
          const Duration(hours: -4),
        ),
        'EDT',
      );
      expect(
        TimeAgo.zoneLabelFor(
          'India Standard Time',
          const Duration(hours: 5, minutes: 30),
        ),
        'IST',
      );
      expect(TimeAgo.zoneLabelFor('CET', const Duration(hours: 1)), 'CET');
      expect(
        TimeAgo.zoneLabelFor('Coordinated Universal Time', Duration.zero),
        'UTC',
      );
    });

    test('falls back to the offset when the name is unusable', () {
      expect(TimeAgo.zoneLabelFor('', const Duration(hours: -5)), 'UTC-05');
      expect(
        TimeAgo.zoneLabelFor(
          'lowercase zone',
          const Duration(hours: 5, minutes: 30),
        ),
        'UTC+05:30',
      );
    });
  });

  testWidgets('the progress bar tracks how far the story has been read', (
    WidgetTester tester,
  ) async {
    // A long body on a phone-height surface, so the reader actually scrolls: a
    // tall test surface would make the article fit and the progress stay at 0.
    final Article long = Article(
      id: 'long-story',
      title: 'A long report',
      publisher: testPublisher,
      publishedAt: DateTime.utc(2026, 10, 16, 18),
      categoryId: 'politics',
      bodyHtml: List<String>.generate(
        24,
        (int index) => '<p>Paragraph $index of the long report body.</p>',
      ).join(),
    );
    await pumpReader(tester, long, surface: const Size(390, 800));

    expect(find.byType(ReadingProgressBar), findsOneWidget);
    expect(
      tester
          .widget<ReadingProgressBar>(find.byType(ReadingProgressBar))
          .progress,
      0,
      reason: 'nothing is read until the reader scrolls',
    );

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();

    final double progress = tester
        .widget<ReadingProgressBar>(find.byType(ReadingProgressBar))
        .progress;
    expect(progress, greaterThan(0));
    expect(progress, lessThanOrEqualTo(1));
  });

  test('progress is zero before the controller is attached', () {
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    expect(readingProgressFor(controller), 0);
  });

  testWidgets('offers Read original when the story has a source link', (
    WidgetTester tester,
  ) async {
    await pumpReader(tester, story());

    expect(find.byTooltip('Read original'), findsOneWidget);
  });

  testWidgets('hides Read original when the story has no source link', (
    WidgetTester tester,
  ) async {
    await pumpReader(tester, story(sourceUrl: null));

    expect(find.byTooltip('Read original'), findsNothing);
  });
}
