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
/// the notification toggles. Breaking is the only broadcast topic; topic and
/// sports subscriptions are opt-in per category.
Set<String> segmentTopicsFor({
  required Set<String> followedIds,
  required AppSettings settings,
}) {
  final Set<String> topics = <String>{};
  if (settings.breakingNewsAlertsEnabled) topics.add(breakingPushTopic);
  for (final String id in followedIds) {
    final bool isTopic = id.startsWith('topic:');
    final bool isSport = id.startsWith('team:') || id.startsWith('league:');
    if (isTopic && !settings.followedTopicAlertsEnabled) continue;
    if (isSport && !settings.sportsAlertsEnabled) continue;
    if (isTopic || isSport) topics.add(topicForFollowId(id));
  }
  return topics;
}
