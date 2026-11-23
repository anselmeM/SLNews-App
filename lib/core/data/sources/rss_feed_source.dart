import 'package:xml/xml.dart';

import '../../domain/breaking_news_policy.dart';
import '../../domain/models/article.dart';
import '../../domain/models/publisher.dart';
import '../../utils/stable_id.dart';
import '../../utils/url_normalizer.dart';
import 'api_client.dart';
import 'feed_source.dart';
import 'news_category_matcher.dart';
import 'wire_date.dart';

import 'package:slnews_mobile/core/utils/app_log.dart';

part 'rss_wire.dart';

/// RSS 2.0 / Atom reader for one outlet.
class RssFeedSource implements FeedSource {
  /// Creates a reader for [config] fetching through [client].
  RssFeedSource({required this.config, required ApiClient client})
    : _api = client;

  @override
  final FeedSourceConfig config;

  final ApiClient _api;

  @override
  Future<List<Article>> fetch({int limit = 20}) async {
    try {
      final String document = await _api.getText(config.url);
      return RssParser.parse(document, config: config, limit: limit);
    } catch (error) {
      // One unreachable outlet must not fail the whole refresh.
      AppLog.debug('RssFeedSource(${config.id}): $error');
      return const <Article>[];
    }
  }
}

/// Stateless RSS 2.0 / Atom parser.
///
/// Separated from I/O so the messy real-world cases — CDATA titles, undefined
/// HTML entities, relative links, inline `<img>` hero art, RFC-822 dates — are
/// covered by unit tests without a network or a mock adapter.
abstract final class RssParser {
  /// Parses [document], returning at most [limit] stories.
  ///
  /// Never throws: a malformed document yields an empty list. Missing dates fall
  /// back to [now] so a story can always be ordered and aged.
  static List<Article> parse(
    String document, {
    required FeedSourceConfig config,
    int limit = 20,
    DateTime? now,
  }) {
    if (limit <= 0 || document.trim().isEmpty) return const <Article>[];

    final XmlDocument? parsed = _parseDocument(document, config);
    if (parsed == null) return const <Article>[];

    final DateTime reference = now ?? DateTime.now();
    final List<Article> articles = <Article>[];
    for (final XmlElement element
        in parsed.descendants.whereType<XmlElement>()) {
      if (!_isItem(element)) continue;
      final Article? article = _toArticle(element, config, reference);
      if (article != null) articles.add(article);
      if (articles.length >= limit) break;
    }
    return articles;
  }

  static XmlDocument? _parseDocument(String document, FeedSourceConfig config) {
    try {
      return XmlDocument.parse(document);
    } catch (firstError) {
      // Many outlets emit HTML entities (`&nbsp;`, `&mdash;`) that are not
      // defined in XML. Retry once with those entities resolved.
      try {
        return XmlDocument.parse(_resolveUnknownEntities(document));
      } catch (error) {
        AppLog.debug(
          'RssParser(${config.id}): malformed feed document: $firstError / $error',
        );
        return null;
      }
    }
  }

  static bool _isItem(XmlElement element) {
    final String local = element.name.local.toLowerCase();
    return local == 'item' || local == 'entry';
  }

  static Article? _toArticle(
    XmlElement item,
    FeedSourceConfig config,
    DateTime reference,
  ) {
    final String title = _plainText(_firstText(item, const <String>['title']));
    if (title.isEmpty) return null;

    final String base = config.url;
    final String? link = UrlNormalizer.absolute(_linkOf(item), base: base);

    final String publishedRaw =
        _firstText(item, const <String>[
          'pubdate',
          'published',
          'updated',
          'dc:date',
          'date',
        ]) ??
        '';
    final DateTime publishedAt = WireDate.parse(publishedRaw) ?? reference;

    final String rawBody =
        _firstText(item, const <String>['content:encoded']) ??
        _firstText(item, const <String>['content', 'description', 'summary']) ??
        '';
    String bodyHtml = _cleanBody(rawBody, base);

    // Inline images are lifted out of the copy either way: the reader draws its
    // own hero from `imageUrl`, so leaving the tag would duplicate the picture.
    // A declared media element still wins over whatever the body embedded.
    final _InlineImage scan = _extractInlineImage(bodyHtml, base);
    bodyHtml = scan.body;

    final String summary = _summarise(
      _plainText(
        _firstText(item, const <String>['description', 'summary']) ?? '',
      ),
      fallback: bodyHtml,
    );

    // Default posture is excerpt + link-out. Full body and publisher-hosted
    // imagery are only used when the source carries an explicit licence.
    final bool previewOnly = config.isPreviewOnly;
    if (previewOnly) {
      bodyHtml = '<p>${_escapeHtml(summary)}</p>';
    }
    final String? imageUrl = config.allowsRemoteImages
        ? _mediaImage(item, base) ?? scan.src
        : null;

    final List<String> tags = _tags(item);
    final String categoryId = _categoryFor(item, config);
    final BreakingAssessment breaking = BreakingNewsPolicy.assess(
      title: title,
      summary: summary,
      categoryId: categoryId,
      tags: tags,
      publishedAt: publishedAt,
      isWire: config.isWire,
      now: reference,
    );

    return Article(
      id: link != null
          ? StableId.fromUrl(link)
          : StableId.fromParts(<String>[config.id, title, publishedRaw]),
      title: title,
      summary: summary,
      bodyHtml: bodyHtml,
      author: _author(item),
      imageUrl: imageUrl,
      sourceUrl: link ?? UrlNormalizer.canonical(base),
      publisher: _publisher(config),
      publishedAt: publishedAt,
      categoryId: categoryId,
      tags: tags,
      isBreaking: breaking.isBreaking,
      readingMinutes: _readingMinutes(bodyHtml),
      previewOnly: previewOnly,
    );
  }

  static String _categoryFor(XmlElement item, FeedSourceConfig config) {
    if (config.categoryId == 'sports') return 'sports';
    final List<String> labels = <String>[
      ..._tags(item),
      _firstText(item, const <String>['category']) ?? '',
    ];
    final String? explicit = categoryIdForTerms(labels);
    if (explicit != null) return explicit;

    // One combined outlet feed often has no category tags. Use the headline and
    // summary as a conservative fallback, then the outlet's default category.
    final String title = _plainText(
      _firstText(item, const <String>['title']) ?? '',
    );
    final String summary = _plainText(
      _firstText(item, const <String>['description', 'summary']) ?? '',
    );
    return categoryIdForTerms(<String>[title, summary]) ?? config.categoryId;
  }

  static Publisher _publisher(FeedSourceConfig config) => Publisher(
    id: config.publisherId,
    name: config.outlet,
    wordmark: config.wordmark,
    websiteUrl: config.websiteUrl,
    isWire: config.isWire,
    country: config.country,
  );
}
