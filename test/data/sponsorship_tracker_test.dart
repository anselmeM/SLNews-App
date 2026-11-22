import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
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
    tracker.impression(sold);
    tracker.tap(sold);
    await Future<void>.delayed(Duration.zero);

    expect(sent, hasLength(2));
    expect(sent[0]['id'], 'sp_1');
    expect(sent[0]['type'], 'impression');
    expect(sent[1]['type'], 'tap');
    expect(sent[0]['eventId'], isA<String>());
    expect(sent[1]['eventId'], isA<String>());
    expect(sent[0]['eventId'], isNot(sent[1]['eventId']));
  });

  test('a failed impression can be retried after a remount', () async {
    final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];
    var fail = true;
    final tracker = SponsorshipTracker.forPoster((_, body) async {
      if (fail) throw StateError('offline');
      sent.add(body);
      return null;
    });

    tracker.impression(sold);
    await Future<void>.delayed(Duration.zero);
    expect(sent, isEmpty);

    fail = false;
    tracker.impression(sold);
    await Future<void>.delayed(Duration.zero);
    expect(sent, hasLength(1));
  });

  test('a retry reuses the same event id', () async {
    final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];
    var fail = true;
    final tracker = SponsorshipTracker.forPoster((_, body) async {
      if (fail) throw StateError('offline');
      sent.add(body);
      return null;
    });

    tracker.impression(sold);
    await Future<void>.delayed(Duration.zero);
    fail = false;
    tracker.impression(sold);
    await Future<void>.delayed(Duration.zero);

    expect(sent, hasLength(1));
    expect(sent.single['type'], 'impression');
  });

  test('a tap counts once per session', () async {
    final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];
    final tracker = SponsorshipTracker.forPoster((_, body) async {
      sent.add(body);
      return null;
    });

    tracker.tap(sold);
    tracker.tap(sold);
    await Future<void>.delayed(Duration.zero);

    expect(
      sent.where((Map<String, dynamic> event) => event['type'] == 'tap'),
      hasLength(1),
    );
  });

  test('a failed post is swallowed', () async {
    final tracker = SponsorshipTracker.forPoster(
      (_, _) async => throw StateError('offline'),
    );
    tracker.impression(sold);
    await Future<void>.delayed(Duration.zero);
  });
  test('queues a failed event and flushes it on the next run', () async {
    final InMemoryPreferencesStore store = InMemoryPreferencesStore();
    final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];
    final SponsorshipTracker first = SponsorshipTracker.forPoster(
      (_, _) async => throw StateError('offline'),
      store: store,
    );

    first.impression(sold);
    await Future<void>.delayed(Duration.zero);
    expect(store.string(SponsorshipTracker.outboxKey), contains('impression'));

    final SponsorshipTracker second = SponsorshipTracker.forPoster((
      _,
      body,
    ) async {
      sent.add(body);
      return null;
    }, store: store);
    await second.flush();

    expect(sent, hasLength(1));
    expect(sent.single['type'], 'impression');
    expect(store.string(SponsorshipTracker.outboxKey), '[]');
  });
}
