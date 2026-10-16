import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/features/feed/presentation/widgets/weather_alert_header.dart';

import 'support/fakes.dart';
import 'support/test_harness.dart';

/// Proves the header row never overflows at the narrowest supported width and
/// at the large text scales readers actually use.
void main() {
  for (final double scale in <double>[1, 1.3, 1.5]) {
    testWidgets('weather header fits at 320pt and textScale $scale', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: feedTestOverrides(
            articles: FakeArticleRepository(),
            weather: FakeWeatherRepository(throwOnCurrent: true),
          ),
          child: themedChild(
            Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(size: Size(320, 600)),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 320,
                    child: WeatherAlertHeader(
                      location: SlLocations.all[3],
                      hasBreaking: true,
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

      expect(find.text('BREAKING'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
