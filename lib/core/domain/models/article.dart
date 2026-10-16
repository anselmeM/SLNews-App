import 'package:flutter/foundation.dart';

import '../../utils/time_ago.dart';
import 'publisher.dart';

/// The central domain entity: a single news story.
///
/// `Article` is intentionally storage-agnostic. The data layer normalises RSS
/// items, REST payloads and bundled JSON into this shape exactly once, so every
/// presentation layer consumes the same fields.
@immutable
class Article {
  const Article({
    required this.id,
    required this.title,
    required this.publisher,
    required this.publishedAt,
    this.summary = '',
    this.bodyHtml = '',
    this.author,
    this.imageUrl,
    this.imageCaption,
    this.imageCredit,
    this.sourceUrl,
    this.categoryId = 'top',
    this.tags = const <String>[],
    this.isBreaking = false,
    this.isLive = false,
    this.readingMinutes = 0,
  });

  /// Deterministic id derived from the canonical link when the feed omits one.
  final String id;

  final String title;

  /// 1-2 sentence standfirst shown on hero cards and in search results.
  final String summary;

  /// Full body markup (HTML). Rendered by the article reader.
  final String bodyHtml;

  final String? author;
  final String? imageUrl;
  final String? imageCaption;
  final String? imageCredit;
  final String? sourceUrl;
  final Publisher publisher;
  final DateTime publishedAt;

  /// Slug of the [NewsCategory] this story belongs to.
  final String categoryId;

  final List<String> tags;

  /// Promoted to the "Top stories" carousel and marked with a breaking label.
  final bool isBreaking;

  /// Continuously updating story (elections, disasters, live scores).
  final bool isLive;

  /// Estimated reading time in minutes; 0 when unknown.
  final int readingMinutes;

  /// "3 hours ago" style label, resolved against the current clock.
  String get relativeAge => TimeAgo.format(publishedAt);

  /// Rough reading time derived from the body when the feed did not provide one.
  int get estimatedReadingMinutes {
    if (readingMinutes > 0) return readingMinutes;
    final int words = bodyHtml
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .length;
    if (words <= 1) return 1;
    return (words / 220).ceil();
  }

  Article copyWith({
    String? title,
    String? summary,
    String? bodyHtml,
    String? author,
    String? imageUrl,
    String? imageCaption,
    String? imageCredit,
    String? sourceUrl,
    Publisher? publisher,
    DateTime? publishedAt,
    String? categoryId,
    List<String>? tags,
    bool? isBreaking,
    bool? isLive,
    int? readingMinutes,
  }) {
    return Article(
      id: id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      bodyHtml: bodyHtml ?? this.bodyHtml,
      author: author ?? this.author,
      imageUrl: imageUrl ?? this.imageUrl,
      imageCaption: imageCaption ?? this.imageCaption,
      imageCredit: imageCredit ?? this.imageCredit,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      publisher: publisher ?? this.publisher,
      publishedAt: publishedAt ?? this.publishedAt,
      categoryId: categoryId ?? this.categoryId,
      tags: tags ?? this.tags,
      isBreaking: isBreaking ?? this.isBreaking,
      isLive: isLive ?? this.isLive,
      readingMinutes: readingMinutes ?? this.readingMinutes,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'summary': summary,
    'bodyHtml': bodyHtml,
    'author': author,
    'imageUrl': imageUrl,
    'imageCaption': imageCaption,
    'imageCredit': imageCredit,
    'sourceUrl': sourceUrl,
    'publisher': publisher.toJson(),
    'publishedAt': publishedAt.toIso8601String(),
    'categoryId': categoryId,
    'tags': tags,
    'isBreaking': isBreaking,
    'isLive': isLive,
    'readingMinutes': readingMinutes,
  };

  factory Article.fromJson(Map<String, dynamic> json) => Article(
    id: json['id'] as String,
    title: json['title'] as String,
    summary: json['summary'] as String? ?? '',
    bodyHtml: json['bodyHtml'] as String? ?? '',
    author: json['author'] as String?,
    imageUrl: json['imageUrl'] as String?,
    imageCaption: json['imageCaption'] as String?,
    imageCredit: json['imageCredit'] as String?,
    sourceUrl: json['sourceUrl'] as String?,
    publisher: Publisher.fromJson(json['publisher'] as Map<String, dynamic>),
    publishedAt: DateTime.parse(json['publishedAt'] as String),
    categoryId: json['categoryId'] as String? ?? 'top',
    tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[]).cast<String>(),
    isBreaking: json['isBreaking'] as bool? ?? false,
    isLive: json['isLive'] as bool? ?? false,
    readingMinutes: (json['readingMinutes'] as num?)?.toInt() ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      other is Article &&
      other.id == id &&
      other.title == title &&
      other.publisher == publisher &&
      other.publishedAt == publishedAt &&
      other.imageUrl == imageUrl &&
      other.categoryId == categoryId &&
      other.isBreaking == isBreaking &&
      other.isLive == isLive;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    publisher,
    publishedAt,
    imageUrl,
    categoryId,
    isBreaking,
    isLive,
  );

  @override
  String toString() => 'Article($id, "$title")';
}
