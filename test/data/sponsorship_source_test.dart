import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/repositories/default_ad_repository.dart';
import 'package:slnews_mobile/core/data/seed/seed_loader.dart';
import 'package:slnews_mobile/core/data/sources/sponsorship_source.dart';
import 'package:slnews_mobile/core/domain/models/ad_unit.dart';

import 'fakes.dart';

const AdUnit house = AdUnit(
  id: 'house-1',
  headline: 'HOUSE',
  body: 'Seed rotation',
  ctaLabel: 'View more',
  advertiser: 'SLNews',
);

Map<String, dynamic> shipped(String id) => <String, dynamic>{
  'id': id,
  'headline': 'SCAN AND SAVE',
  'body': 'Every top-up this month',
  'ctaLabel': 'View more',
  'advertiser': 'Orange SL',
  'targetUrl': 'https://example.com/offer',
  'brandHex': '#FF7900',
  'brandAccentHex': '#FFA040',
  'imageUrl': 'https://cdn.example.com/orange.jpg',
};

void main() {
  group('SponsorshipSource', () {
    test('maps sold units to AdUnit and skips malformed entries', () async {
      final source = SponsorshipSource.forFetcher(
        (String url) async => <String, dynamic>{
          'items': <dynamic>[
            shipped('sp_1'),
            <String, dynamic>{'id': 'broken'},
          ],
        },
      );
      final units = await source.units('feed');
      expect(units, hasLength(1));
      expect(units.single.advertiser, 'Orange SL');
      expect(units.single.targetUrl, 'https://example.com/offer');
      expect(units.single.imageUrl, 'https://cdn.example.com/orange.jpg');
    });

    test('empty or failed responses yield no units and never throw', () async {
      expect(
        await SponsorshipSource.forFetcher(
          (_) async => <String, dynamic>{'items': <dynamic>[]},
        ).units('feed'),
        isEmpty,
      );
      expect(
        await SponsorshipSource.forFetcher(
          (_) async => throw StateError('down'),
        ).units('feed'),
        isEmpty,
      );
      expect(
        await SponsorshipSource.forFetcher((_) async => null).units('feed'),
        isEmpty,
      );
    });

    test('asks for the requested placement', () async {
      String? seen;
      await SponsorshipSource.forFetcher((String url) async {
        seen = url;
        return <String, dynamic>{'items': <dynamic>[]};
      }).units('sports_stream');
      expect(seen, contains('placement=sports_stream'));
    });
  });

  group('DefaultAdRepository', () {
    test('prefers a sold unit over the seeded rotation', () async {
      final repository = DefaultAdRepository(
        seedLoader: InMemorySeedLoader(seedData()),
        sponsorships: SponsorshipSource.forFetcher(
          (_) async => <String, dynamic>{
            'items': <dynamic>[shipped('sp_1')],
          },
        ),
      );
      final units = await repository.units(placement: 'feed');
      expect(units.single.id, 'sp_1');
    });

    test('falls back to the seed rotation when nothing is sold', () async {
      final repository = DefaultAdRepository(
        seedLoader: InMemorySeedLoader(seedData(ads: const <AdUnit>[house])),
        sponsorships: SponsorshipSource.forFetcher(
          (_) async => <String, dynamic>{'items': <dynamic>[]},
        ),
      );
      final units = await repository.units(placement: 'feed');
      expect(units.single.headline, 'HOUSE');
    });

    test('rotates the seeded creative by placement and by day', () async {
      const AdUnit second = AdUnit(
        id: 'house-2',
        headline: 'SECOND',
        body: '',
        ctaLabel: 'View more',
        advertiser: 'SLNews',
      );
      const AdUnit third = AdUnit(
        id: 'house-3',
        headline: 'THIRD',
        body: '',
        ctaLabel: 'View more',
        advertiser: 'SLNews',
      );
      DateTime day = DateTime.utc(2026, 11, 18);
      final DefaultAdRepository repository = DefaultAdRepository(
        seedLoader: InMemorySeedLoader(
          seedData(ads: const <AdUnit>[house, second, third]),
        ),
        now: () => day,
      );

      Future<List<String>> idsAt(String placement) async =>
          (await repository.units(placement: placement))
              .map((AdUnit unit) => unit.id)
              .toList();

      final List<String> feedToday = await idsAt('feed');
      // Stable within the day for one placement (cache-friendly, testable).
      expect(await idsAt('feed'), feedToday);
      // Different placements do not all show the same creative.
      expect(await idsAt('top'), isNot(equals(feedToday)));

      // ...and the rotation moves on the next day.
      day = day.add(const Duration(days: 1));
      expect(await idsAt('feed'), isNot(equals(feedToday)));
    });
  });
}
