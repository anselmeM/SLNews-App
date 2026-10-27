import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/ad_unit.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/core/widgets/ad_card.dart';
import 'package:slnews_mobile/core/widgets/sl_network_image.dart';

/// Regression coverage for the shared ad unit.
///
/// The offer card's 38pt figure used to make `_OfferCard` overflow by ~84px on a
/// 320pt screen at a 1.3x text scale (reported from the Sports feature probe),
/// so the creative must stay bounded on small phones with large type.
void main() {
  const AdUnit withLabel = AdUnit(
    id: 'ad-1',
    headline: 'CLAIM YOUR REWARD',
    body: 'JustPlay: Earn Money or Donate',
    ctaLabel: 'View more',
    advertiser: 'Salone Rewards',
    assetLabel: r'$20',
    disclosure:
        'Actual payout depends on playing games and engaging with the app.',
  );

  const AdUnit withImage = AdUnit(
    id: 'ad-image',
    headline: 'SCAN AND WIN',
    body: 'Every top-up this month',
    ctaLabel: 'View more',
    advertiser: 'Orange SL',
    imageUrl: 'https://cdn.example.com/creative.jpg',
  );

  const AdUnit withoutLabel = AdUnit(
    id: 'ad-2',
    headline: 'BUY LOCAL',
    body: 'Support Sierra Leonean businesses',
    ctaLabel: 'Learn more',
    advertiser: 'Salone Market',
  );

  Future<void> pumpCard(
    WidgetTester tester,
    AdUnit unit, {
    double width = 320,
    double textScale = 1.3,
  }) async {
    tester.view.physicalSize = Size(width * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AdCard(unit: unit),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lays out on a 320pt screen at a 1.3x text scale', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, withLabel);

    expect(find.text('CLAIM YOUR REWARD'), findsOneWidget);
    expect(find.text(r'$20'), findsOneWidget);
    expect(find.text('AD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out without an asset label', (WidgetTester tester) async {
    await pumpCard(tester, withoutLabel);

    expect(find.text('BUY LOCAL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders a sold creative image behind the copy', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, withImage, textScale: 1);

    expect(find.byType(SlNetworkImage), findsOneWidget);
    expect(find.text('SCAN AND WIN'), findsOneWidget);
    expect(find.text('AD'), findsOneWidget);
  });

  testWidgets('carries the Ad label and its disclosure', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, withLabel, textScale: 1);

    expect(find.text('AD'), findsOneWidget);
    expect(
      find.text(
        'Actual payout depends on playing games and engaging with the app.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });
}
