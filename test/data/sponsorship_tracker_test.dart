import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/data/sources/api_client.dart';
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

const AdUnit soldWithToken = AdUnit(
  id: 'sp_2',
  headline: 'TOKEN',
  body: 'Sold with a served token',
  ctaLabel: 'View more',
  advertiser: 'Orange SL',
  placement: 'news_stream',
  eventToken: 'signed-token',
);

/// The anonymous install id contract: 32 lowercase hex characters.
final RegExp installIdPattern = RegExp(r'^[0-9a-f]{32}$');

/// A deterministic id for tests that do not exercise generation.
const String fixedInstallId = '0123456789abcdef0123456789abcdef';

/// Lets the microtask/timer turns behind a fire-and-forget post settle.
Future<void> settle() => Future<void>.delayed(Duration.zero);

List<Map<String, dynamic>> outboxEvents(InMemoryPreferencesStore store) {
  final Object? decoded = jsonDecode(
    store.string(SponsorshipTracker.outboxKey) ?? '[]',
  );
  return <Map<String, dynamic>>[
    for (final Object? item in decoded as List<dynamic>)
      Map<String, dynamic>.from(item as Map),
  ];
}

void main() {
  test(
    'every impression call posts its own event with a fresh event id',
    () async {
      final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];
      var installIdCalls = 0;
      final tracker = SponsorshipTracker.forPoster(
        (String url, Map<String, dynamic> body) async {
          sent.add(body);
          return null;
        },
        newInstallId: () {
          installIdCalls++;
          return fixedInstallId;
        },
      );

      tracker.impression(sold);
      tracker.impression(sold);
      await settle();

      expect(sent, hasLength(2), reason: 'one network event per impression');
      expect(
        sent.every(
          (Map<String, dynamic> event) => event['type'] == 'impression',
        ),
        isTrue,
      );
      expect(sent[0]['id'], 'sp_1');
      expect(sent[1]['id'], 'sp_1');
      expect(sent[0]['eventId'], isA<String>());
      expect(
        sent[0]['eventId'],
        isNot(sent[1]['eventId']),
        reason: 'two views are two billable events',
      );
      expect(
        sent.every(
          (Map<String, dynamic> event) => event['installId'] == fixedInstallId,
        ),
        isTrue,
        reason: 'the injected install id is stable and on every event',
      );
      expect(installIdCalls, 1, reason: 'the install id is resolved once');
    },
  );

  test('every tap call posts its own event with a fresh event id', () async {
    final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];
    final tracker = SponsorshipTracker.forPoster((
      String url,
      Map<String, dynamic> body,
    ) async {
      sent.add(body);
      return null;
    }, newInstallId: () => fixedInstallId);

    tracker.tap(sold);
    tracker.tap(sold);
    await settle();

    expect(sent, hasLength(2));
    expect(
      sent.every((Map<String, dynamic> event) => event['type'] == 'tap'),
      isTrue,
    );
    expect(sent[0]['eventId'], isNot(sent[1]['eventId']));
  });

  test('only sold units are measured', () async {
    final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];
    final tracker = SponsorshipTracker.forPoster((
      String url,
      Map<String, dynamic> body,
    ) async {
      sent.add(body);
      return null;
    }, newInstallId: () => fixedInstallId);

    tracker.impression(house);
    tracker.tap(house);
    await settle();

    expect(sent, isEmpty);
  });

  test('carries the served event token only when the unit has one', () async {
    final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];
    final tracker = SponsorshipTracker.forPoster((
      String url,
      Map<String, dynamic> body,
    ) async {
      sent.add(body);
      return null;
    }, newInstallId: () => fixedInstallId);

    tracker.impression(sold);
    tracker.impression(soldWithToken);
    await settle();

    expect(sent, hasLength(2));
    expect(sent[0].containsKey('token'), isFalse);
    expect(sent[1]['token'], 'signed-token');
  });

  test(
    'generates a valid anonymous install id and reuses it per tracker',
    () async {
      final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];
      final tracker = SponsorshipTracker.forPoster((
        String url,
        Map<String, dynamic> body,
      ) async {
        sent.add(body);
        return null;
      });

      tracker.impression(sold);
      tracker.tap(sold);
      await settle();

      expect(sent, hasLength(2));
      final String installId = sent[0]['installId'] as String;
      expect(installId, matches(installIdPattern));
      expect(sent[1]['installId'], installId);
      // The event body is anonymous: no account/user identity is ever attached.
      expect(sent[0].keys.toSet(), <String>{
        'id',
        'type',
        'eventId',
        'installId',
      });
    },
  );

  test(
    'install id is stable across tracker instances sharing preferences',
    () async {
      final InMemoryPreferencesStore store = InMemoryPreferencesStore();
      final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];

      final SponsorshipTracker first = SponsorshipTracker.forPoster((
        String url,
        Map<String, dynamic> body,
      ) async {
        sent.add(body);
        return null;
      }, store: store);
      first.impression(sold);
      await settle();

      final String? stored = store.string(SponsorshipTracker.installIdKey);
      expect(stored, matches(installIdPattern));
      expect(sent.single['installId'], stored);

      final SponsorshipTracker second = SponsorshipTracker.forPoster((
        String url,
        Map<String, dynamic> body,
      ) async {
        sent.add(body);
        return null;
      }, store: store);
      second.impression(sold);
      await settle();

      expect(sent, hasLength(2));
      expect(sent[1]['installId'], stored);
    },
  );

  test('an existing install id is never regenerated', () async {
    final InMemoryPreferencesStore store = InMemoryPreferencesStore(
      <String, Object?>{SponsorshipTracker.installIdKey: fixedInstallId},
    );
    final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];
    var generated = 0;
    final SponsorshipTracker tracker = SponsorshipTracker.forPoster(
      (String url, Map<String, dynamic> body) async {
        sent.add(body);
        return null;
      },
      store: store,
      newInstallId: () {
        generated++;
        return 'ffffffffffffffffffffffffffffffff';
      },
    );

    tracker.impression(sold);
    await settle();

    expect(generated, 0);
    expect(sent.single['installId'], fixedInstallId);
  });

  test(
    'a transient failure stays queued and a retry reuses its event id',
    () async {
      final InMemoryPreferencesStore store = InMemoryPreferencesStore();
      final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];
      final SponsorshipTracker first = SponsorshipTracker.forPoster(
        (String url, Map<String, dynamic> body) async =>
            throw StateError('offline'),
        store: store,
        newInstallId: () => fixedInstallId,
      );

      first.impression(soldWithToken);
      await settle();
      expect(sent, isEmpty);

      final List<Map<String, dynamic>> queued = outboxEvents(store);
      expect(queued, hasLength(1));
      final Map<String, dynamic> event = queued.single;
      expect(event['type'], 'impression');
      expect(event['token'], 'signed-token');
      expect(event['installId'], fixedInstallId);
      expect(event['eventId'], isA<String>());

      final SponsorshipTracker second = SponsorshipTracker.forPoster((
        String url,
        Map<String, dynamic> body,
      ) async {
        sent.add(body);
        return null;
      }, store: store);
      await second.flush();

      expect(sent, hasLength(1));
      expect(
        sent.single['eventId'],
        event['eventId'],
        reason: 'a retry of one event keeps that event id',
      );
      expect(sent.single['installId'], event['installId']);
      expect(store.string(SponsorshipTracker.outboxKey), '[]');
    },
  );

  test('a failed post is swallowed', () async {
    final tracker = SponsorshipTracker.forPoster(
      (String url, Map<String, dynamic> body) async =>
          throw StateError('offline'),
    );
    tracker.impression(sold);
    await settle();
  });

  test('drops a permanently rejected event and continues the queue', () async {
    final InMemoryPreferencesStore store = InMemoryPreferencesStore();
    final SponsorshipTracker first = SponsorshipTracker.forPoster(
      (String url, Map<String, dynamic> body) async =>
          throw StateError('offline'),
      store: store,
    );
    first.impression(sold);
    first.tap(sold);
    await settle();

    final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];
    var calls = 0;
    final SponsorshipTracker second = SponsorshipTracker.forPoster((
      String url,
      Map<String, dynamic> body,
    ) async {
      calls++;
      if (calls == 1) {
        throw ApiException('token expired', statusCode: 401);
      }
      sent.add(body);
      return null;
    }, store: store);
    await second.flush();

    expect(calls, 2);
    expect(sent, hasLength(1));
    expect(store.string(SponsorshipTracker.outboxKey), '[]');
  });

  test('queues a failed event and flushes it on the next run', () async {
    final InMemoryPreferencesStore store = InMemoryPreferencesStore();
    final List<Map<String, dynamic>> sent = <Map<String, dynamic>>[];
    final SponsorshipTracker first = SponsorshipTracker.forPoster(
      (String url, Map<String, dynamic> body) async =>
          throw StateError('offline'),
      store: store,
    );

    first.impression(sold);
    await settle();
    expect(store.string(SponsorshipTracker.outboxKey), contains('impression'));

    final SponsorshipTracker second = SponsorshipTracker.forPoster((
      String url,
      Map<String, dynamic> body,
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
