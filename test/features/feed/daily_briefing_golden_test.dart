import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/feed/presentation/widgets/daily_briefing_card.dart';

import 'support/fakes.dart';

void main() {
  setUpAll(() async {
    final FontLoader textLoader = FontLoader('SLNewsSans');
    textLoader.addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
    await textLoader.load();
    final FontLoader iconLoader = FontLoader('MaterialIcons');
    iconLoader.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await iconLoader.load();
  });

  testWidgets(
    'daily briefing card layout',
    (WidgetTester tester) async {
      final articles = <dynamic>[
        testArticle(
          id: 'a',
          title: 'Government orders legal review of steel plant',
        ),
        testArticle(id: 'b', title: 'Macron reacts to protests in Freetown'),
        testArticle(
          id: 'c',
          title: 'Abnormal weather suspected across the provinces',
        ),
      ];
      await tester.binding.setSurfaceSize(const Size(440, 860));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topCenter,
                child: DailyBriefingCard(
                  title: 'Evening briefing',
                  articles: articles.cast(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DailyBriefingCard),
        matchesGoldenFile('goldens/daily_briefing_card.png'),
      );
    },
    skip: Platform.environment['CI'] == 'true'
        ? 'Host-dependent golden; run locally for visual review'
        : false,
  );
}
