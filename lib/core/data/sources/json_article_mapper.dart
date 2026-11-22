import '../../domain/breaking_news_policy.dart';
import '../../domain/models/article.dart';
import '../../domain/models/publisher.dart';
import '../../utils/stable_id.dart';
import '../../utils/url_normalizer.dart';
import 'feed_source.dart';
import 'wire_date.dart';

/// Normalises loosely-shaped JSON payloads into [Article]s.
///
/// REST and GraphQL outlets disagree about field names, publisher shape and
/// timestamp encoding. Doing that translation once here keeps the two JSON
/// sources thin and keeps `Article.fromJson` (used by the seed) strict.
abstract final class JsonArticleMapper {
  /// Envelope keys tried, in order, when the payload is not already a list.
  static const List<String> defaultPaths = <String>[
    'items',
    'articles',
    'data',
    'results',
    'stories',
    'docs',
    'entries',
  ];

  /// Finds the article list inside [payload].
  ///
  /// Accepts a bare array, an envelope keyed by [paths], or one extra level of
  /// nesting such as `{"data": {"articles": [...]}}`.
  static List<Object?> extractEntries(Object? payload, {List<String>? paths}) {
    if (payload is List) return payload;
    if (payload is! Map) return const <Object?>[];

    final List<String> candidates = paths ?? defaultPaths;
    for (final String path in candidates) {
      final Object? found = _dig(payload, path);
      if (found is List) return found;
    }

    final Object? nested = payload['data'];
    if (nested is Map) return extractEntries(nested, paths: candidates);
    if (nested is List) return nested;
    return const <Object?>[];
  }

  /// Maps every usable entry of [payload], capped at [limit].
  static List<Article> toArticles(
    Object? payload,
    FeedSourceConfig config, {
    int limit = 20,
    List<String>? paths,
    DateTime? now,
  }) {
    final DateTime reference = now ?? DateTime.now();
    final List<Article> articles = <Article>[];
    for (final Object? entry in extractEntries(payload, paths: paths)) {
      if (articles.length >= limit) break;
      final Article? article = map(entry, config, now: reference);
      if (article != null) articles.add(article);
    }
    return articles;
  }

  /// Maps one wire object, or returns `null` when it cannot describe a story.
  static Article? map(Object? entry, FeedSourceConfig config, {DateTime? now}) {
    if (entry is! Map) return null;

    final Map<String, dynamic> json = <String, dynamic>{};
    entry.forEach((Object? key, Object? value) {
      if (key is String) json[key] = value;
    });

    final String title = _string(
      json['title'] ?? json['headline'] ?? json['name'],
    );
    if (title.isEmpty) return null;

    final String base = config.websiteUrl ?? config.url;
    final String? rawLink = _nullableString(
      json['sourceUrl'] ?? json['url'] ?? json['link'] ?? json['permalink'],
    );
    final String? link = rawLink == null
        ? null
        : (UrlNormalizer.absolute(rawLink, base: base) ?? rawLink);

    final DateTime publishedAt =
        _date(
          json['publishedAt'] ??
              json['published_at'] ??
              json['pubDate'] ??
              json['date'] ??
              json['createdAt'],
        ) ??
        now ??
        DateTime.now();

    final String wireId = _string(json['id']);
    final String id = wireId.isNotEmpty
        ? wireId
        : link != null
        ? StableId.fromUrl(link)
        : StableId.fromParts(<String>[
            config.id,
            title,
            publishedAt.toIso8601String(),
          ]);

    final String bodyHtml = _string(
      json['bodyHtml'] ??
          json['content'] ??
          json['body'] ??
          json['description'],
    );
    final String summary = _string(
      json['summary'] ??
          json['standfirst'] ??
          json['description'] ??
          json['excerpt'],
    );

    final String categoryId =
        _nullableString(
          json['categoryId'] ?? json['category'] ?? json['section'],
        ) ??
        config.categoryId;
    final List<String> tags = _tags(json['tags'] ?? json['keywords']);
    final Publisher publisher = _publisher(
      json['publisher'] ?? json['source'],
      config,
    );
    final bool editorFlagged = json['isBreaking'] == true;
    final BreakingAssessment breaking = BreakingNewsPolicy.assess(
      title: title,
      summary: summary.isEmpty ? _truncate(bodyHtml) : summary,
      categoryId: categoryId,
      tags: tags,
      publishedAt: publishedAt,
      isWire: publisher.isWire,
      editorFlagged: editorFlagged,
      now: now,
    );

    return Article(
      id: id,
      title: title,
      summary: summary.isEmpty ? _truncate(bodyHtml) : summary,
      bodyHtml: bodyHtml,
      author: _nullableString(
        json['author'] ?? json['byline'] ?? json['creator'],
      ),
      imageUrl: _nullableString(
        json['imageUrl'] ??
            json['image'] ??
            json['thumbnail'] ??
            json['image_url'],
      ),
      imageCaption: _nullableString(json['imageCaption']),
      imageCredit: _nullableString(json['imageCredit']),
      sourceUrl: link,
      publisher: publisher,
      publishedAt: publishedAt,
      categoryId: categoryId,
      tags: tags,
      isBreaking: breaking.isBreaking,
      isLive: json['isLive'] == true,
      readingMinutes: _int(json['readingMinutes']) ?? 0,
    );
  }

  static Publisher _publisher(Object? raw, FeedSourceConfig config) {
    if (raw is Map) {
      final Map<String, dynamic> json = <String, dynamic>{};
      raw.forEach((Object? key, Object? value) {
        if (key is String) json[key] = value;
      });
      final String name = _string(json['name'] ?? json['outlet']);
      if (name.isNotEmpty) {
        return Publisher(
          id: _string(json['id']).isEmpty
              ? config.publisherId
              : _string(json['id']),
          name: name,
          wordmark: _nullableString(json['wordmark']) ?? config.wordmark,
          logoUrl: _nullableString(json['logoUrl']),
          websiteUrl: _nullableString(json['websiteUrl']) ?? config.websiteUrl,
          country: _nullableString(json['country']) ?? config.country,
          isWire: json['isWire'] is bool
              ? json['isWire'] as bool
              : config.isWire,
        );
      }
    }
    final String inline = _string(raw);
    if (inline.isNotEmpty) {
      return Publisher(
        id: config.publisherId,
        name: inline,
        wordmark: config.wordmark,
        websiteUrl: config.websiteUrl,
        isWire: config.isWire,
        country: config.country,
      );
    }
    // Missing publisher: fall back to the outlet the endpoint belongs to.
    return Publisher(
      id: config.publisherId,
      name: config.outlet,
      wordmark: config.wordmark,
      websiteUrl: config.websiteUrl,
      isWire: config.isWire,
      country: config.country,
    );
  }

  static Object? _dig(Map<dynamic, dynamic> root, String path) {
    Object? current = root;
    for (final String segment in path.split('.')) {
      if (current is! Map) return null;
      current = current[segment];
    }
    return current;
  }

  static DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    if (value is num) return WireDate.fromEpoch(value);
    if (value is String) return WireDate.parse(value);
    return null;
  }

  static String _string(Object? value) {
    if (value is String) return value.trim();
    if (value is num || value is bool) return value.toString();
    return '';
  }

  static String? _nullableString(Object? value) {
    final String text = _string(value);
    return text.isEmpty ? null : text;
  }

  static int? _int(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static List<String> _tags(Object? value) {
    final List<String> tags = <String>[];
    if (value is List) {
      for (final Object? entry in value) {
        final String tag = _string(entry);
        if (tag.isNotEmpty && !tags.contains(tag)) tags.add(tag);
      }
    } else if (value is String) {
      for (final String part in value.split(',')) {
        final String tag = part.trim();
        if (tag.isNotEmpty && !tags.contains(tag)) tags.add(tag);
      }
    }
    return tags.length > 8 ? tags.sublist(0, 8) : tags;
  }

  static String _truncate(String html) {
    final String text = html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.length <= 240) return text;
    final int cut = text.lastIndexOf(' ', 240);
    return '${text.substring(0, cut <= 0 ? 240 : cut).trimRight()}…';
  }
}
