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

  Future<void> pumpReader(WidgetTester tester, Article article) async {
    await useTallSurface(tester, size: const Size(390, 2400));
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
    expect(
      find.text(TimeAgo.absolute(article.publishedAt)),
      findsOneWidget,
      reason: 'the reference puts an absolute date and time under the byline',
    );
    expect(find.textContaining('min read'), findsOneWidget);
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
}
