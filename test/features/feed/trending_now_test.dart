import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/feed/presentation/widgets/trending_now.dart';

import '../feed/support/fakes.dart';

/// "Trending now" is a ranked list: breaking first, then image-bearing, then
/// newest, with the rank printed as a numeral.
void main() {
  Article article({
    required String id,
    required String title,
    required DateTime publishedAt,
    bool isBreaking = false,
    String? imageUrl,
  }) => testArticle(
    id: id,
    title: title,
    publishedAt: publishedAt,
    isBreaking: isBreaking,
    imageUrl: imageUrl,
  );

  group('trendingArticles', () {
    test('ranks breaking first, then image-bearing, then newest', () {
      final List<Article> ranked = trendingArticles(<Article>[
        article(
          id: 'plain',
          title: 'Plain story',
          publishedAt: DateTime.utc(2026, 10, 16, 12),
        ),
        article(
          id: 'image',
          title: 'With image',
          publishedAt: DateTime.utc(2026, 10, 16, 8),
          imageUrl: 'https://example.com/a.jpg',
        ),
        article(
          id: 'breaking',
          title: 'Breaking story',
          publishedAt: DateTime.utc(2026, 10, 16, 6),
          isBreaking: true,
        ),
      ]);

      expect(ranked.map((Article a) => a.id), <String>[
        'breaking',
        'image',
        'plain',
      ]);
    });

    test('ties break on publish time and the limit is honoured', () {
      final List<Article> ranked = trendingArticles(<Article>[
        article(
          id: 'older',
          title: 'Older',
          publishedAt: DateTime.utc(2026, 10, 16, 8),
        ),
        article(
          id: 'newer',
          title: 'Newer',
          publishedAt: DateTime.utc(2026, 10, 16, 9),
        ),
        article(
          id: 'newest',
          title: 'Newest',
          publishedAt: DateTime.utc(2026, 10, 16, 10),
        ),
      ], limit: 2);

      expect(ranked.map((Article a) => a.id), <String>['newest', 'newer']);
    });

    test('an empty feed ranks to nothing', () {
      expect(trendingArticles(const <Article>[]), isEmpty);
    });
  });

  testWidgets('renders ranks 1..n and reports taps', (
    WidgetTester tester,
  ) async {
    Article? tapped;
    final Article first = article(
      id: 'a',
      title: 'Leone Stars draw in Guinea',
      publishedAt: DateTime.utc(2026, 10, 16, 12),
      isBreaking: true,
    );
    final Article second = article(
      id: 'b',
      title: 'Budget passes in parliament',
      publishedAt: DateTime.utc(2026, 10, 16, 10),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TrendingNow(
            articles: <Article>[second, first],
            onOpen: (Article value) => tapped = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Leone Stars draw in Guinea'), findsOneWidget);
    expect(find.text('Budget passes in parliament'), findsOneWidget);

    await tester.tap(find.text('Leone Stars draw in Guinea'));
    await tester.pumpAndSettle();

    expect(tapped?.id, 'a');
  });

  testWidgets('renders nothing without articles', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TrendingNow(
            articles: const <Article>[],
            onOpen: (Article _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1'), findsNothing);
  });
}
