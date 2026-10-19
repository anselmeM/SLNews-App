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
  });
}
