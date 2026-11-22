import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/sources/sponsorship_tracker.dart';
import 'package:slnews_mobile/core/domain/models/ad_unit.dart';

import 'mobile_contract.g.dart';

void main() {
  group('mobile sponsorship contract', () {
    test('AdUnit parses the generated fixture', () {
      final AdUnit unit = AdUnit.fromSponsorship(adUnitContractFixture);

      expect(unit.id, adUnitContractFixture['id']);
      expect(unit.placement, 'feed');
      expect(unit.advertiser, adUnitContractFixture['advertiser']);
      expect(unit.headline, adUnitContractFixture['headline']);
      expect(unit.altText, adUnitContractFixture['altText']);
      expect(unit.eventToken, adUnitContractFixture['eventToken']);
      expect(unit.targetUrl, adUnitContractFixture['targetUrl']);
      expect(unit.toJson().keys.toSet(), adUnitContractFields);
      expect(adUnitRequiredFields.difference(adUnitContractFields), isEmpty);
    });

    test('event payload keys match the generated fixture', () async {
      final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];
      final SponsorshipTracker tracker = SponsorshipTracker.forPoster((
        String url,
        Map<String, dynamic> body,
      ) async {
        sent.add(body);
        return null;
      });
      const AdUnit sold = AdUnit(
        id: 'sp_contract_fixture',
        headline: 'Contract fixture',
        body: 'Body',
        ctaLabel: 'Open',
        advertiser: 'Contract Partner',
        placement: 'feed',
        eventToken: 'signed-event-token',
      );

      tracker.impression(sold);
      await Future<void>.delayed(Duration.zero);

      expect(sent, hasLength(1));
      expect(sent.single.keys.toSet(), eventRequestContractFields);
      expect(sent.single['id'], eventRequestContractFixture['id']);
      expect(sent.single['type'], eventRequestContractFixture['type']);
      expect(sent.single['token'], eventRequestContractFixture['token']);
    });
  });
}
