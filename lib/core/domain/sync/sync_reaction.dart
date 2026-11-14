part of 'sync_repository.dart';

/// A like (reaction) on a mobile item.
@immutable
class SyncReaction implements SyncRow {
  /// Creates a reaction row.
  const SyncReaction({
    required this.itemId,
    required this.updatedAt,
    this.kind = 'like',
    this.deleted = false,
  });

  /// Creates a tombstone for [itemId].
  const SyncReaction.deleted({
    required this.itemId,
    required this.updatedAt,
    this.kind = 'like',
  }) : deleted = true;

  /// Opaque mobile item id the reader reacted to.
  final String itemId;

  /// Reaction kind; `like` is the only value the app produces today.
  final String kind;

  @override
  final DateTime updatedAt;

  @override
  final bool deleted;

  @override
  String get id => itemId;

  @override
  String get collection => SyncCollections.reactions;

  /// Copy of this row with the given fields replaced.
  SyncReaction copyWith({String? kind, DateTime? updatedAt, bool? deleted}) =>
      SyncReaction(
        itemId: itemId,
        kind: kind ?? this.kind,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'itemId': itemId,
    'kind': kind,
    'updatedAt': syncTimestamp(updatedAt),
    'deleted': deleted,
  };

  factory SyncReaction.fromJson(Map<String, dynamic> json) => SyncReaction(
    itemId: _requiredString(json['itemId'], 'itemId'),
    kind: _optionalString(json['kind'])?.toLowerCase() ?? 'like',
    updatedAt: parseSyncTimestamp(json['updatedAt']) ?? syncEpoch,
    deleted: _flag(json['deleted']),
  );

  @override
  bool operator ==(Object other) =>
      other is SyncReaction && other.itemId == itemId;

  @override
  int get hashCode => itemId.hashCode;

  @override
  String toString() =>
      'SyncReaction($itemId, $kind, updatedAt: ${syncTimestamp(updatedAt)}'
      '${deleted ? ', deleted' : ''})';
}
