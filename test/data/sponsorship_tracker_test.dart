import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/sources/sponsorship_tracker.dart';
import 'package:slnews_mobile/core/domain/models/ad_unit.dart';

const AdUnit house = AdUnit(
  id: 'house-1',
  headline: 'HOUSE',
  body: 'Seed',
  ctaLabel: 'View more',
  advertiser: 'SLNews',
);

const AdUnit sold = AdUnit(
  id: 'sp_1',
  headline: 'SOLD',
  body: 'Sold',
  ctaLabel: 'View more',
  advertiser: 'Orange SL',
  placement: 'feed',
);

void main() {
  test('posts impressions and taps only for sold units', () async {
    final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];
    final tracker = SponsorshipTracker.forPoster((_, body) async {
      sent.add(body);
      return null;
    });

    tracker.impression(house);
    tracker.tap(house);
    tracker.impression(sold);
    tracker.tap(sold);
    await Future<void>.delayed(Duration.zero);

    expect(sent, hasLength(2));
    expect(sent[0], <String, dynamic>{'id': 'sp_1', 'type': 'impression'});
    expect(sent[1], <String, dynamic>{'id': 'sp_1', 'type': 'tap'});
  });

  test('a failed post is swallowed', () async {
    final tracker = SponsorshipTracker.forPoster(
      (_, _) async => throw StateError('offline'),
    );
    tracker.impression(sold);
    await Future<void>.delayed(Duration.zero);
  });
}
