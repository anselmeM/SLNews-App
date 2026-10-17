import 'app_settings.dart';
import 'notification_item.dart';

/// Maps the reader's notification switches onto the categories the app produces.
///
/// The reference screen offers four categories; the API produces three of them
/// today (`system` is always delivered). `interactiveContentEnabled` is stored
/// and honoured when that kind starts arriving — see `NotificationKind`.
bool isNotificationKindEnabled(NotificationKind kind, AppSettings settings) {
  return switch (kind) {
    NotificationKind.breaking => settings.breakingNewsAlertsEnabled,
    // Followed teams and score updates are the "Sports" switch.
    NotificationKind.followedTeam ||
    NotificationKind.score => settings.sportsAlertsEnabled,
    // Publisher updates are the closest analogue of "Editor's picks".
    NotificationKind.followedPublisher => settings.editorsPicksEnabled,
    // System notices (account, sync, delivery problems) are not opt-out.
    NotificationKind.system => true,
  };
}

/// Filters [items] down to the categories the reader still wants.
List<NotificationItem> visibleNotifications(
  List<NotificationItem> items,
  AppSettings settings,
) {
  return items
      .where(
        (NotificationItem item) =>
            isNotificationKindEnabled(item.kind, settings),
      )
      .toList(growable: false);
}
