import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/app_settings.dart';
import 'package:slnews_mobile/core/domain/models/notification_item.dart';
import 'package:slnews_mobile/core/domain/models/notification_preferences.dart';

/// The Settings switches must agree with what the history screens show.
void main() {
  const AppSettings defaults = AppSettings();

  test('defaults match the reference screen', () {
    expect(defaults.breakingNewsAlertsEnabled, isTrue);
    expect(defaults.editorsPicksEnabled, isFalse);
    expect(defaults.interactiveContentEnabled, isFalse);
    expect(defaults.sportsAlertsEnabled, isTrue);
    expect(defaults.weatherForecastEnabled, isTrue);
  });

  test('breaking alerts follow their switch', () {
    expect(
      isNotificationKindEnabled(NotificationKind.breaking, defaults),
      isTrue,
    );
    expect(
      isNotificationKindEnabled(
        NotificationKind.breaking,
        defaults.copyWith(breakingNewsAlertsEnabled: false),
      ),
      isFalse,
    );
  });

  test('sports covers followed teams and scores', () {
    final AppSettings quiet = defaults.copyWith(sportsAlertsEnabled: false);

    expect(
      isNotificationKindEnabled(NotificationKind.followedTeam, quiet),
      isFalse,
    );
    expect(isNotificationKindEnabled(NotificationKind.score, quiet), isFalse);
    expect(
      isNotificationKindEnabled(NotificationKind.followedTeam, defaults),
      isTrue,
    );
  });

  test("publisher updates belong to editor's picks", () {
    expect(
      isNotificationKindEnabled(
        NotificationKind.followedPublisher,
        defaults.copyWith(editorsPicksEnabled: true),
      ),
      isTrue,
    );
    expect(
      isNotificationKindEnabled(NotificationKind.followedPublisher, defaults),
      isFalse,
    );
  });

  test('system notices cannot be switched off', () {
    final AppSettings allOff = defaults.copyWith(
      breakingNewsAlertsEnabled: false,
      editorsPicksEnabled: false,
      interactiveContentEnabled: false,
      sportsAlertsEnabled: false,
    );

    expect(isNotificationKindEnabled(NotificationKind.system, allOff), isTrue);
  });

  test('visibleNotifications drops the switched-off categories', () {
    final List<NotificationItem> items = <NotificationItem>[
      NotificationItem(
        id: 'n1',
        title: 'Breaking',
        body: 'b',
        receivedAt: DateTime.utc(2026, 10, 16),
        kind: NotificationKind.breaking,
      ),
      NotificationItem(
        id: 'n2',
        title: 'Sports',
        body: 'b',
        receivedAt: DateTime.utc(2026, 10, 16),
        kind: NotificationKind.score,
      ),
      NotificationItem(
        id: 'n3',
        title: 'System',
        body: 'b',
        receivedAt: DateTime.utc(2026, 10, 16),
        kind: NotificationKind.system,
      ),
    ];

    expect(visibleNotifications(items, defaults), hasLength(3));

    final List<NotificationItem> quiet = visibleNotifications(
      items,
      defaults.copyWith(sportsAlertsEnabled: false),
    );
    expect(quiet.map((NotificationItem item) => item.id), <String>['n1', 'n3']);
  });
}
