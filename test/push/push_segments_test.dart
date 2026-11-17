import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/app_settings.dart';
import 'package:slnews_mobile/core/push/push_segments.dart';
import 'package:slnews_mobile/core/push/push_service.dart';

void main() {
  const AppSettings allOn = AppSettings(
    breakingNewsAlertsEnabled: true,
    followedTopicAlertsEnabled: true,
    sportsAlertsEnabled: true,
  );

  test('maps follow ids to stable FCM topic names', () {
    expect(topicForFollowId('topic:politics'), 'slnews_topic_politics');
    expect(topicForFollowId('team:lal'), 'slnews_team_lal');
    expect(topicForFollowId('publisher:awoko'), 'slnews_publisher_awoko');
  });

  test('newspaper follows subscribe to their own topic', () {
    final Set<String> topics = segmentTopicsFor(
      followedIds: const <String>{'publisher:awoko'},
      settings: allOn,
    );
    expect(topics, contains('slnews_publisher_awoko'));

    // The "topics and newspapers" toggle mutes both follow kinds together.
    final Set<String> muted = segmentTopicsFor(
      followedIds: const <String>{'publisher:awoko', 'topic:politics'},
      settings: const AppSettings(
        breakingNewsAlertsEnabled: false,
        followedTopicAlertsEnabled: false,
      ),
    );
    expect(muted, isEmpty);

    // ...while the sports toggle leaves newspaper alerts alone.
    final Set<String> sportsOff = segmentTopicsFor(
      followedIds: const <String>{'publisher:awoko', 'team:lal'},
      settings: const AppSettings(sportsAlertsEnabled: false),
    );
    expect(sportsOff, contains('slnews_publisher_awoko'));
    expect(sportsOff, isNot(contains('slnews_team_lal')));
  });

  test('only subscribes to enabled categories', () {
    final Set<String> topics = segmentTopicsFor(
      followedIds: const <String>{'topic:politics', 'team:lal', 'league:nba'},
      settings: allOn,
    );
    expect(
      topics,
      containsAll(<String>[
        breakingPushTopic,
        'slnews_topic_politics',
        'slnews_team_lal',
        'slnews_league_nba',
      ]),
    );

    final Set<String> muted = segmentTopicsFor(
      followedIds: const <String>{'topic:politics', 'team:lal'},
      settings: const AppSettings(
        breakingNewsAlertsEnabled: false,
        followedTopicAlertsEnabled: false,
        sportsAlertsEnabled: false,
      ),
    );
    expect(muted, isEmpty);
  });

  test('sync subscribes new topics and drops removed ones', () async {
    final List<String> subscribed = <String>[];
    final List<String> unsubscribed = <String>[];
    final PushService push = PushService.forTransports(
      register: (String url, Map<String, dynamic> body) async => null,
      unregister: (String url, Map<String, dynamic> body) async => null,
      token: () async => 'token',
      requestPermission: () async => true,
      subscribeTopic: (String topic) async => subscribed.add(topic),
      unsubscribeTopic: (String topic) async => unsubscribed.add(topic),
    );

    await push.syncSegments(
      followedIds: const <String>{'topic:politics'},
      settings: allOn,
    );
    expect(
      subscribed,
      containsAll(<String>[breakingPushTopic, 'slnews_topic_politics']),
    );

    await push.syncSegments(
      followedIds: const <String>{'topic:sports'},
      settings: allOn,
    );
    expect(subscribed, contains('slnews_topic_sports'));
    expect(unsubscribed, contains('slnews_topic_politics'));

    await push.clearSegments();
    expect(push.activeTopics, isEmpty);
  });

  test(
    'persists applied topics and reconciles stale topics on restart',
    () async {
      final List<String> unsubscribed = <String>[];
      Set<String> persisted = <String>{};
      final PushService push = PushService.forTransports(
        register: (String url, Map<String, dynamic> body) async => null,
        unregister: (String url, Map<String, dynamic> body) async => null,
        token: () async => 'token',
        requestPermission: () async => true,
        subscribeTopic: (String topic) async {},
        unsubscribeTopic: (String topic) async => unsubscribed.add(topic),
        initialTopics: const <String>{'slnews_topic_stale'},
        persistTopics: (Set<String> topics) async => persisted = topics,
      );

      await push.syncSegments(
        followedIds: const <String>{'topic:politics'},
        settings: const AppSettings(
          breakingNewsAlertsEnabled: false,
          followedTopicAlertsEnabled: true,
          sportsAlertsEnabled: false,
        ),
      );

      expect(unsubscribed, contains('slnews_topic_stale'));
      expect(persisted, <String>{'slnews_topic_politics'});
      expect(push.activeTopics, <String>{'slnews_topic_politics'});
    },
  );
}
