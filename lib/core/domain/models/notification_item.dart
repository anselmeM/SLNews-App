import 'package:flutter/foundation.dart';

import '../../utils/time_ago.dart';

/// Category of a push alert, used for the icon and grouping in history.
enum NotificationKind {
  breaking,
  followedTeam,
  followedPublisher,
  score,
  system;

  static NotificationKind fromWire(String? raw) => switch (raw?.toLowerCase()) {
    'breaking' => NotificationKind.breaking,
    'team' => NotificationKind.followedTeam,
    'publisher' => NotificationKind.followedPublisher,
    'score' => NotificationKind.score,
    _ => NotificationKind.system,
  };

  String get wireValue => switch (this) {
    NotificationKind.breaking => 'breaking',
    NotificationKind.followedTeam => 'team',
    NotificationKind.followedPublisher => 'publisher',
    NotificationKind.score => 'score',
    NotificationKind.system => 'system',
  };
}

/// One row in the Following tab's "Notification history" list.
@immutable
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    required this.kind,
    this.articleId,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;
  final NotificationKind kind;

  /// Deep-link target: tapping the row opens `/article/:id`.
  final String? articleId;

  final bool isRead;

  String get ageLabel => TimeAgo.format(receivedAt);

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
    id: id,
    title: title,
    body: body,
    receivedAt: receivedAt,
    kind: kind,
    articleId: articleId,
    isRead: isRead ?? this.isRead,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'body': body,
    'receivedAt': receivedAt.toIso8601String(),
    'kind': kind.wireValue,
    'articleId': articleId,
    'isRead': isRead,
  };

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String? ?? '',
        receivedAt: DateTime.parse(json['receivedAt'] as String),
        kind: NotificationKind.fromWire(json['kind'] as String?),
        articleId: json['articleId'] as String?,
        isRead: json['isRead'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is NotificationItem && other.id == id && other.isRead == isRead;

  @override
  int get hashCode => Object.hash(id, isRead);
}
