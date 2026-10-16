import '../models/notification_item.dart';

/// Breaking-news alert history shown in the Following tab.
abstract interface class NotificationRepository {
  /// Alerts newest first.
  Future<List<NotificationItem>> history({int limit = 30});

  /// Cached alerts without awaiting storage I/O.
  List<NotificationItem> get cachedHistory;

  Future<void> record(NotificationItem item);

  Future<void> markRead(String id);

  Future<void> markAllRead();

  int get unreadCount;
}
