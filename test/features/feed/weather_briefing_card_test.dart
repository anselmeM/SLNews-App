import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/location/device_location_service.dart';
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
    DeviceLocationService? deviceLocation,
  }) {
    return ProviderScope(
      overrides: feedTestOverrides(
        articles: FakeArticleRepository(),
        weather: FakeWeatherRepository(),
        deviceLocation: deviceLocation,
      ),
      child: themedChild(
        Scaffold(
          body: WeatherBriefingCard(
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

  testWidgets('can switch the weather card to the device location', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(card(deviceLocation: _FakeDeviceLocationService()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    expect(find.text('Weather location'), findsOneWidget);

    await tester.tap(find.text('Use my location'));
    await tester.pumpAndSettle();

    expect(find.text('London'), findsWidgets);
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

class _FakeDeviceLocationService implements DeviceLocationService {
  @override
  Future<DeviceLocationResult> current() async => const DeviceLocationResult(
    status: DeviceLocationStatus.granted,
    location: NewsLocation(
      id: 'geo:51.51,-0.13',
      label: 'London',
      region: 'United Kingdom',
      latitude: 51.51,
      longitude: -0.13,
    ),
  );

  @override
  Future<bool> openSettings() async => false;
}
