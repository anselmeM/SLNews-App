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
    final Map<String, dynamic>? json = _asMap(entry);
    if (json == null) return null;
    final String title = _title(json);
    if (title.isEmpty) return null;

    final String? link = _sourceLink(json, config);
    final DateTime publishedAt = _publishedAt(json, now);
    final String bodyHtml = _bodyHtml(json);
    final String summary = _summary(json);
    final String categoryId = _categoryId(json, config);
    final List<String> tags = _tags(json['tags'] ?? json['keywords']);
    final Publisher publisher = _publisher(
      json['publisher'] ?? json['source'],
      config,
    );
    return Article(
      id: _articleId(json, config, link: link, title: title, at: publishedAt),
      title: title,
      summary: summary.isEmpty ? _truncate(bodyHtml) : summary,
      bodyHtml: config.isPreviewOnly ? '' : bodyHtml,
      author: _nullableString(
        json['author'] ?? json['byline'] ?? json['creator'],
      ),
      imageUrl: _remoteImage(
        json['imageUrl'] ??
            json['image'] ??
            json['thumbnail'] ??
            json['image_url'],
        config,
      ),
      imageCaption: _remoteImage(json['imageCaption'], config),
      imageCredit: _remoteImage(json['imageCredit'], config),
      sourceUrl: link,
      publisher: publisher,
      publishedAt: publishedAt,
      categoryId: categoryId,
      tags: tags,
      isBreaking: _breaking(
        json: json,
        title: title,
        summary: summary,
        bodyHtml: bodyHtml,
        categoryId: categoryId,
        tags: tags,
        publishedAt: publishedAt,
        publisher: publisher,
        now: now,
      ),
      isLive: json['isLive'] == true,
      readingMinutes: _int(json['readingMinutes']) ?? 0,
      previewOnly: config.isPreviewOnly,
    );
  }

  static Map<String, dynamic>? _asMap(Object? entry) {
    if (entry is! Map) return null;
    final Map<String, dynamic> json = <String, dynamic>{};
    entry.forEach((Object? key, Object? value) {
      if (key is String) json[key] = value;
    });
    return json;
  }

  static String _title(Map<String, dynamic> json) =>
      _string(json['title'] ?? json['headline'] ?? json['name']);

  static String _bodyHtml(Map<String, dynamic> json) => _string(
    json['bodyHtml'] ?? json['content'] ?? json['body'] ?? json['description'],
  );

  static String _summary(Map<String, dynamic> json) => _string(
    json['summary'] ??
        json['standfirst'] ??
        json['description'] ??
        json['excerpt'],
  );

  static String _categoryId(
    Map<String, dynamic> json,
    FeedSourceConfig config,
  ) =>
      _nullableString(
        json['categoryId'] ?? json['category'] ?? json['section'],
      ) ??
      config.categoryId;

  static String? _remoteImage(Object? raw, FeedSourceConfig config) =>
      config.allowsRemoteImages ? _nullableString(raw) : null;

  static String? _sourceLink(
    Map<String, dynamic> json,
    FeedSourceConfig config,
  ) {
    final String? raw = _nullableString(
      json['sourceUrl'] ?? json['url'] ?? json['link'] ?? json['permalink'],
    );
    if (raw == null) return null;
    final String base = config.websiteUrl ?? config.url;
    return UrlNormalizer.absolute(raw, base: base) ?? raw;
  }

  static DateTime _publishedAt(Map<String, dynamic> json, DateTime? now) =>
      _date(
        json['publishedAt'] ??
            json['published_at'] ??
            json['pubDate'] ??
            json['date'] ??
            json['createdAt'],
      ) ??
      now ??
      DateTime.now();

  static String _articleId(
    Map<String, dynamic> json,
    FeedSourceConfig config, {
    required String? link,
    required String title,
    required DateTime at,
  }) {
    final String wireId = _string(json['id']);
    if (wireId.isNotEmpty) return wireId;
    if (link != null) return StableId.fromUrl(link);
    return StableId.fromParts(<String>[config.id, title, at.toIso8601String()]);
  }

  static bool _breaking({
    required Map<String, dynamic> json,
    required String title,
    required String summary,
    required String bodyHtml,
    required String categoryId,
    required List<String> tags,
    required DateTime publishedAt,
    required Publisher publisher,
    required DateTime? now,
  }) => BreakingNewsPolicy.assess(
    title: title,
    summary: summary.isEmpty ? _truncate(bodyHtml) : summary,
    categoryId: categoryId,
    tags: tags,
    publishedAt: publishedAt,
    isWire: publisher.isWire,
    editorFlagged: json['isBreaking'] == true,
    now: now,
  ).isBreaking;

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
          logoUrl: config.allowsRemoteImages
              ? _nullableString(json['logoUrl'])
              : null,
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
