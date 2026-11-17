import '../domain/models/app_settings.dart';

/// FCM topic names for the reader's followed entities.
///
/// FCM topics allow only [a-zA-Z0-9-_.~%]; follow ids use colons, so the prefix
/// and separators are normalised here in one place. The mapping is deliberately
/// stable: a topic is the same string on every platform and release.
const String breakingPushTopic = 'slnews_breaking';

String topicForFollowId(String followId) {
  final String cleaned = followId
      .replaceAll(':', '_')
      .replaceAll(RegExp(r'[^A-Za-z0-9_.~%-]'), '_');
  return 'slnews_$cleaned';
}

/// Topics this device should be subscribed to, given the current follows and
/// the notification toggles.
///
/// Every followed entity gets `slnews_<kind>_<id>`, so an alert published for a
/// topic, team, league or newspaper reaches exactly the devices that follow it.
/// Breaking is the one broadcast topic.
///
/// Topics and newspapers share [AppSettings.followedTopicAlertsEnabled]: both
/// are "things you follow", and a reader who muted follow alerts means all of
/// them. The server is the other half of this contract — it must publish to the
/// same names (`SLNews-Web`, `src/lib/push/topics.ts`).
Set<String> segmentTopicsFor({
  required Set<String> followedIds,
  required AppSettings settings,
}) {
  final Set<String> topics = <String>{};
  if (settings.breakingNewsAlertsEnabled) topics.add(breakingPushTopic);
  for (final String id in followedIds) {
    final bool isTopic = id.startsWith('topic:');
    final bool isSport = id.startsWith('team:') || id.startsWith('league:');
    final bool isSource = id.startsWith('publisher:');
    if ((isTopic || isSource) && !settings.followedTopicAlertsEnabled) continue;
    if (isSport && !settings.sportsAlertsEnabled) continue;
    if (isTopic || isSport || isSource) topics.add(topicForFollowId(id));
  }
  return topics;
}
