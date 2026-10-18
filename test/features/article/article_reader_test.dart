import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/core/utils/time_ago.dart';
import 'package:slnews_mobile/core/widgets/publisher_mark.dart';
import 'package:slnews_mobile/features/article/presentation/article_page.dart';
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
  }) async {
    await useTallSurface(tester, size: surface);
    final GoRouter router = GoRouter(
      initialLocation: '/article/${article.id}',
      routes: <RouteBase>[
        GoRoute(
          path: '/article/:id',
          builder: (BuildContext context, GoRouterState state) =>
              ArticlePage(articleId: state.pathParameters['id'] ?? ''),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: feedTestOverrides(
          articles: FakeArticleRepository(
            topStories: <Article>[article],
            categoryStories: <Article>[article],
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
}
