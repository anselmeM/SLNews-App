import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/feed/presentation/widgets/daily_briefing_card.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('briefing lists its headlines and opens the tapped one', (
    WidgetTester tester,
  ) async {
    final articles = <dynamic>[
      testArticle(id: 'a', title: 'Deadly fire investigation'),
      testArticle(id: 'b', title: 'Macron reacts to protests'),
      testArticle(id: 'c', title: 'Abnormal weather suspected'),
    ];
    final List<String> opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: DailyBriefingCard(
            title: 'Evening briefing',
            articles: articles.cast(),
            onOpen: (article) => opened.add(article.id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Evening briefing'), findsOneWidget);
    expect(find.text('Macron reacts to protests'), findsOneWidget);

    await tester.tap(find.text('Macron reacts to protests'));
    await tester.pumpAndSettle();
    expect(opened, <String>['b']);
  });

  test('briefing title follows the time of day', () {
    expect(briefingTitleFor(DateTime(2026, 10, 18, 7)), 'Morning briefing');
    expect(briefingTitleFor(DateTime(2026, 10, 18, 14)), 'Afternoon briefing');
    expect(briefingTitleFor(DateTime(2026, 10, 18, 20)), 'Evening briefing');
  });
}
