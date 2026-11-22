import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/sources/sponsorship_tracker.dart';
import 'package:slnews_mobile/core/domain/models/ad_unit.dart';

Map<String, dynamic> _fixture(String name) {
  final String raw = File('test/contracts/$name').readAsStringSync();
  return jsonDecode(raw) as Map<String, dynamic>;
}

void main() {
  group('mobile sponsorship contract', () {
    test('AdUnit parses the canonical fixture', () {
      final Map<String, dynamic> fixture = _fixture('ad-unit.json');
      final AdUnit unit = AdUnit.fromSponsorship(fixture);

      expect(unit.id, fixture['id']);
      expect(unit.placement, 'feed');
      expect(unit.advertiser, fixture['advertiser']);
      expect(unit.headline, fixture['headline']);
      expect(unit.altText, fixture['altText']);
      expect(unit.eventToken, fixture['eventToken']);
      expect(unit.targetUrl, fixture['targetUrl']);
      expect(unit.toJson().keys.toSet(), containsAll(fixture.keys));
    });

    test('event payload keys match the canonical fixture', () async {
      final Map<String, dynamic> fixture = _fixture('event-request.json');
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
      expect(sent.single.keys.toSet(), fixture.keys.toSet());
      expect(sent.single['id'], fixture['id']);
      expect(sent.single['type'], fixture['type']);
      expect(sent.single['token'], fixture['token']);
    });
  });
}
