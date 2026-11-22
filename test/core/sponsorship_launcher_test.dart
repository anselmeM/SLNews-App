import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/ads/sponsorship_launcher.dart';
import 'package:slnews_mobile/core/config/legal_links.dart';
import 'package:slnews_mobile/core/data/sources/sponsorship_tracker.dart';
import 'package:slnews_mobile/core/domain/models/ad_placement.dart';
import 'package:slnews_mobile/core/domain/models/ad_unit.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/core/widgets/tracked_ad_card.dart';

AdUnit sold({String? target = 'https://sponsor.example/offer'}) => AdUnit(
  id: 'sp_1',
  headline: 'SPONSORED',
  body: 'Offer',
  ctaLabel: 'Open',
  advertiser: 'Sponsor',
  targetUrl: target,
  placement: AdPlacement.feed.wire,
);

void main() {
  group('sponsorship URL policy', () {
    test('accepts only absolute http(s) URLs without credentials', () {
      expect(
        parseSponsorshipTarget('https://sponsor.example/offer'),
        isNotNull,
      );
      expect(parseSponsorshipTarget(' http://sponsor.example '), isNotNull);
      expect(parseSponsorshipTarget('javascript:alert(1)'), isNull);
      expect(parseSponsorshipTarget('intent://x#Intent;end'), isNull);
      expect(parseSponsorshipTarget('file:///etc/passwd'), isNull);
      expect(parseSponsorshipTarget('https://user:pass@example.com'), isNull);
      expect(parseSponsorshipTarget('/relative'), isNull);
      expect(parseSponsorshipTarget(''), isNull);
    });

    testWidgets('opens a valid sponsor target', (WidgetTester tester) async {
      String? opened;
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            externalUrlOpenerProvider.overrideWithValue((String url) async {
              opened = url;
              return true;
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Consumer(
                builder: (BuildContext context, WidgetRef ref, Widget? _) {
                  return TextButton(
                    onPressed: () => openSponsorship(context, ref, sold()),
                    child: const Text('open'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();

      expect(opened, 'https://sponsor.example/offer');
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('rejects an invalid target without opening it', (
      WidgetTester tester,
    ) async {
      int opens = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            externalUrlOpenerProvider.overrideWithValue((String url) async {
              opens++;
              return true;
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Consumer(
                builder: (BuildContext context, WidgetRef ref, Widget? _) {
                  return TextButton(
                    onPressed: () => openSponsorship(
                      context,
                      ref,
                      sold(target: 'javascript:alert(1)'),
                    ),
                    child: const Text('open'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();

      expect(opens, 0);
      expect(find.text('This sponsor link is unavailable.'), findsOneWidget);
    });
  });

  group('impression accounting', () {
    testWidgets('counts an impression only after the card is visible', (
      WidgetTester tester,
    ) async {
      final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];
      final SponsorshipTracker tracker = SponsorshipTracker.forPoster((
        String url,
        Map<String, dynamic> body,
      ) async {
        sent.add(body);
        return null;
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            sponsorshipTrackerProvider.overrideWithValue(tracker),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(child: TrackedAdCard(unit: sold())),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1500));

      expect(
        sent.where(
          (Map<String, dynamic> event) => event['type'] == 'impression',
        ),
        hasLength(1),
      );
    });
  });

  group('tap accounting', () {
    Future<List<Map<String, dynamic>>> pumpAndTap(
      WidgetTester tester, {
      required bool opens,
    }) async {
      final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];
      final SponsorshipTracker tracker = SponsorshipTracker.forPoster((
        String url,
        Map<String, dynamic> body,
      ) async {
        sent.add(body);
        return null;
      });
      final AdUnit unit = sold();
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            sponsorshipTrackerProvider.overrideWithValue(tracker),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: TrackedAdCard(
                  unit: unit,
                  onCtaPressed: () async => opens,
                  onOpened: (AdUnit _) async => opens,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('SPONSORED'));
      await tester.pump();
      return sent;
    }

    testWidgets('counts a tap only when the target opened', (
      WidgetTester tester,
    ) async {
      final List<Map<String, dynamic>> sent = await pumpAndTap(
        tester,
        opens: true,
      );
      expect(
        sent.where((Map<String, dynamic> event) => event['type'] == 'tap'),
        hasLength(1),
      );
    });

    testWidgets('does not count a tap when no target opened', (
      WidgetTester tester,
    ) async {
      final List<Map<String, dynamic>> sent = await pumpAndTap(
        tester,
        opens: false,
      );
      expect(
        sent.where((Map<String, dynamic> event) => event['type'] == 'tap'),
        isEmpty,
      );
    });
  });
}
