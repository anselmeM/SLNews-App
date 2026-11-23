import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/utils/time_ago.dart';
import 'package:slnews_mobile/features/feed/presentation/widgets/weather_briefing_card.dart';

import 'support/fakes.dart';
import 'support/test_harness.dart';

void main() {
  setUp(() => appNow = () => DateTime(2026, 11, 23, 15));
  tearDown(() => appNow = () => DateTime.now());

  Widget card({
    bool showWeather = true,
    List<Article> articles = const <Article>[],
    ValueChanged<Article>? onOpen,
  }) {
    return ProviderScope(
      overrides: feedTestOverrides(
        articles: FakeArticleRepository(),
        weather: FakeWeatherRepository(),
      ),
      child: themedChild(
        Scaffold(
          body: WeatherBriefingCard(
            location: SlLocations.fallback,
            showWeather: showWeather,
            briefing: articles,
            onOpenArticle: (Article article) => onOpen?.call(article),
          ),
        ),
      ),
    );
  }

  testWidgets('merges weather and briefing into one card', (
    WidgetTester tester,
  ) async {
    final List<String> opened = <String>[];
    await tester.pumpWidget(
      card(
        articles: <Article>[
          testArticle(id: 'a', title: 'First briefing headline'),
          testArticle(id: 'b', title: 'Second briefing headline'),
        ],
        onOpen: (Article article) => opened.add(article.id),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DAILY BRIEFING · AFTERNOON'), findsOneWidget);
    expect(find.text('MON 23 NOV'), findsOneWidget);
    expect(find.text('Stormy afternoon'), findsOneWidget);
    expect(find.text('29°'), findsOneWidget);
    expect(find.text('Thundery showers'), findsOneWidget);
    expect(find.text('Freetown'), findsOneWidget);
    expect(find.text('TODAY’S BRIEFING'), findsOneWidget);
    expect(find.text('2 stories'), findsOneWidget);
    expect(find.text('First briefing headline'), findsOneWidget);
    expect(find.text('Second briefing headline'), findsOneWidget);

    await tester.tap(find.text('Second briefing headline'));
    await tester.pumpAndSettle();
    expect(opened, <String>['b']);
  });

  testWidgets('weather can be hidden while the briefing stays', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      card(
        showWeather: false,
        articles: <Article>[
          testArticle(id: 'a', title: 'Briefing without weather'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Briefing without weather'), findsOneWidget);
    expect(find.text('DAILY BRIEFING'), findsOneWidget);
    expect(find.text('Stormy afternoon'), findsNothing);
    expect(find.text('29°'), findsNothing);
  });

  testWidgets('an empty weather-off card collapses', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(card(showWeather: false));
    await tester.pumpAndSettle();

    expect(find.byType(WeatherBriefingCard), findsOneWidget);
    expect(find.text('DAILY BRIEFING'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final double scale in <double>[1, 1.3, 1.5]) {
    testWidgets('merged card fits at 320pt and textScale $scale', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: feedTestOverrides(
            articles: FakeArticleRepository(),
            weather: FakeWeatherRepository(),
          ),
          child: themedChild(
            Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(size: Size(320, 900)),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 320,
                    child: WeatherBriefingCard(
                      location: SlLocations.fallback,
                      showWeather: true,
                      briefing: <Article>[
                        testArticle(
                          id: 'a',
                          title:
                              'A long briefing headline that wraps at the '
                              'narrowest supported screen width',
                        ),
                        testArticle(id: 'b', title: 'Second headline'),
                      ],
                      onOpenArticle: (_) {},
                    ),
                  ),
                ),
              ),
            ),
            textScaler: scale,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
