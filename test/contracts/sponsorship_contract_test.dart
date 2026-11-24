import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/sources/sponsorship_tracker.dart';
import 'package:slnews_mobile/core/domain/models/ad_placement.dart';
import 'package:slnews_mobile/core/domain/models/ad_unit.dart';

import 'mobile_contract.g.dart';

/// The server-side placement enum this app must be able to request.
const Set<String> backendPlacements = <String>{
  'feed',
  'news_stream',
  'sports_stream',
  'article_end',
};

/// The anonymous install id contract: 32 lowercase hex characters.
final RegExp installIdPattern = RegExp(r'^[0-9a-f]{32}$');

void main() {
  group('mobile sponsorship contract', () {
    test('AdPlacement matches the backend placement enum', () {
      expect(
        AdPlacement.values
            .map((AdPlacement placement) => placement.wire)
            .toSet(),
        backendPlacements,
      );
      expect(AdPlacement.tryParse('news_stream'), AdPlacement.newsStream);
      expect(AdPlacement.newsStream.wire, 'news_stream');
    });

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

    test('AdUnit accepts a news_stream placement', () {
      final AdUnit unit = AdUnit.fromSponsorship(<String, dynamic>{
        ...adUnitContractFixture,
        'placement': AdPlacement.newsStream.wire,
      });

      expect(unit.placement, 'news_stream');
      expect(unit.isSold, isTrue);
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
      expect(eventRequestContractFields, contains('installId'));
      expect(sent.single.keys.toSet(), eventRequestContractFields);
      expect(sent.single['id'], eventRequestContractFixture['id']);
      expect(sent.single['type'], eventRequestContractFixture['type']);
      expect(sent.single['token'], eventRequestContractFixture['token']);
      expect(sent.single['installId'], matches(installIdPattern));
      expect(
        eventRequestContractFixture['installId'],
        matches(installIdPattern),
        reason: 'the canonical EventRequest fixture carries a valid installId',
      );
      // No account or user identity is ever attached to a sponsorship event.
      expect(
        sent.single.keys.toSet(),
        isNot(contains(anyOf('accountId', 'userId', 'user_id'))),
      );
    });

    test('event payload omits token when the unit has none', () async {
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
        placement: 'news_stream',
      );

      tracker.impression(sold);
      await Future<void>.delayed(Duration.zero);

      expect(sent, hasLength(1));
      expect(
        sent.single.keys.toSet(),
        eventRequestContractFields.difference(<String>{'token'}),
      );
      expect(sent.single['installId'], matches(installIdPattern));
    });
  });
}
