part of 'sync_repository.dart';

/// A subscription to a team, league, city, topic or publisher.
@immutable
class SyncFollow implements SyncRow {
  /// Creates a follow row.
  const SyncFollow({
    required this.targetId,
    required this.kind,
    required this.updatedAt,
    this.label,
    this.deleted = false,
  });

  /// Creates a tombstone for [targetId]; `kind` is still sent because the API
  /// requires it on every follow row.
  const SyncFollow.deleted({
    required this.targetId,
    required this.updatedAt,
    this.kind = 'topic',
  }) : label = null,
       deleted = true;

  /// Follow target id (`team:lal`, `league:spl`, `city:freetown`, ...).
  final String targetId;

  /// `team`, `league`, `location`, `topic` or `publisher`.
  final String kind;

  /// Display label, e.g. `Los Angeles Lakers`.
  final String? label;

  @override
  final DateTime updatedAt;

  @override
  final bool deleted;

  @override
  String get id => targetId;

  @override
  String get collection => SyncCollections.follows;

  /// Copy of this row with the given fields replaced.
  SyncFollow copyWith({
    String? kind,
    String? label,
    DateTime? updatedAt,
    bool? deleted,
  }) => SyncFollow(
    targetId: targetId,
    kind: kind ?? this.kind,
    label: label ?? this.label,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'targetId': targetId,
    'kind': kind,
    'label': label,
    'updatedAt': syncTimestamp(updatedAt),
    'deleted': deleted,
  };

  factory SyncFollow.fromJson(Map<String, dynamic> json) => SyncFollow(
    targetId: _requiredString(json['targetId'], 'targetId'),
    kind: _optionalString(json['kind'])?.toLowerCase() ?? 'topic',
    label: _optionalString(json['label']),
    updatedAt: parseSyncTimestamp(json['updatedAt']) ?? syncEpoch,
    deleted: _flag(json['deleted']),
  );

  @override
  bool operator ==(Object other) =>
      other is SyncFollow && other.targetId == targetId;

  @override
  int get hashCode => targetId.hashCode;

  @override
  String toString() =>
      'SyncFollow($targetId, $kind, updatedAt: ${syncTimestamp(updatedAt)}'
      '${deleted ? ', deleted' : ''})';
}
