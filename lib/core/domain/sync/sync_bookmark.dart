part of 'sync_repository.dart';

/// A saved story as the sync API stores it.
///
/// This is a row about a *mobile item*, not a pointer to a PWA content row: the
/// API treats `itemId` as an opaque string and never resolves it.
@immutable
class SyncBookmark implements SyncRow {
  /// Creates a bookmark row.
  const SyncBookmark({
    required this.itemId,
    required this.title,
    required this.updatedAt,
    this.sourceUrl,
    this.imageUrl,
    this.publisher,
    this.publishedAt,
    this.savedAt,
    this.deleted = false,
  });

  /// Creates a tombstone for [itemId]; only the identity and the instant matter.
  const SyncBookmark.deleted({required this.itemId, required this.updatedAt})
    : title = '',
      sourceUrl = null,
      imageUrl = null,
      publisher = null,
      publishedAt = null,
      savedAt = null,
      deleted = true;

  /// Opaque mobile item id (`slnews-api:4821`, `rss:<hex>`, `web:<cuid>`).
  final String itemId;

  /// Headline shown in the saved list. Defaults to the id when the server has
  /// none, because the API requires the field on every bookmark push.
  final String title;

  /// Canonical link to the story, also the future join key with the PWA.
  final String? sourceUrl;

  final String? imageUrl;
  final String? publisher;

  /// When the story was published (not when it was saved).
  final DateTime? publishedAt;

  /// When the reader saved it, or `null` when neither the server nor the row
  /// supplied one — the API defaults `savedAt` to `updatedAt`, and [toJson]
  /// sends that default explicitly so a retry is byte-for-byte stable.
  ///
  /// [fromJson] resolves the same default, because parsing must not produce a
  /// bookmark with no save time at all.
  final DateTime? savedAt;

  @override
  final DateTime updatedAt;

  @override
  final bool deleted;

  @override
  String get id => itemId;

  @override
  String get collection => SyncCollections.bookmarks;

  /// Copy of this row with the given fields replaced.
  SyncBookmark copyWith({
    String? title,
    String? sourceUrl,
    String? imageUrl,
    String? publisher,
    DateTime? publishedAt,
    DateTime? savedAt,
    DateTime? updatedAt,
    bool? deleted,
  }) => SyncBookmark(
    itemId: itemId,
    title: title ?? this.title,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    imageUrl: imageUrl ?? this.imageUrl,
    publisher: publisher ?? this.publisher,
    publishedAt: publishedAt ?? this.publishedAt,
    savedAt: savedAt ?? this.savedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
  );

  /// Wire shape for `POST /sync`. Always ISO-8601 UTC with milliseconds.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'itemId': itemId,
    'title': title,
    'sourceUrl': sourceUrl,
    'imageUrl': imageUrl,
    'publisher': publisher,
    'publishedAt': syncTimestamp(publishedAt),
    // The API defaults `savedAt` to `updatedAt`; sending it explicitly keeps
    // the request body identical on every retry of the same row.
    'savedAt': syncTimestamp(savedAt ?? updatedAt),
    'updatedAt': syncTimestamp(updatedAt),
    'deleted': deleted,
  };

  /// Parses a wire row. Throws [FormatException] when `itemId` is absent, so a
  /// malformed row is skipped instead of poisoning the whole response.
  factory SyncBookmark.fromJson(Map<String, dynamic> json) {
    final String itemId = _requiredString(json['itemId'], 'itemId');
    final DateTime? updatedAt = parseSyncTimestamp(json['updatedAt']);
    final DateTime? savedAt = parseSyncTimestamp(json['savedAt']);
    return SyncBookmark(
      itemId: itemId,
      // The API requires a non-empty title on push, so fall back to the id
      // rather than write back a value the server would reject as 400.
      title: _optionalString(json['title']) ?? itemId,
      sourceUrl: _optionalString(json['sourceUrl']),
      imageUrl: _optionalString(json['imageUrl']),
      publisher: _optionalString(json['publisher']),
      publishedAt: parseSyncTimestamp(json['publishedAt']),
      // The API's documented default: `savedAt` falls back to `updatedAt`.
      savedAt: savedAt ?? updatedAt,
      updatedAt: updatedAt ?? syncEpoch,
      deleted: _flag(json['deleted']),
    );
  }

  /// Equality is the identity key: an `updatedAt` bump must not make the row a
  /// different entry in a map keyed by id.
  @override
  bool operator ==(Object other) =>
      other is SyncBookmark && other.itemId == itemId;

  @override
  int get hashCode => itemId.hashCode;

  @override
  String toString() =>
      'SyncBookmark($itemId, updatedAt: ${syncTimestamp(updatedAt)}'
      '${deleted ? ', deleted' : ''})';
}
