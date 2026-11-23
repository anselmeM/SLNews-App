import 'package:flutter/foundation.dart';

import '../../domain/breaking_news_policy.dart';
import '../../domain/models/article.dart';
import '../../domain/models/news_category.dart';
import '../../domain/models/publisher.dart';
import 'api_client.dart';
import 'feed_source.dart';
import 'wire_date.dart';

import 'package:slnews_mobile/core/utils/app_log.dart';

part 'sl_news_api_config.dart';
part 'sl_news_api_mapping.dart';

/// Where the SLNews scraper API lives and how to authenticate to it.
///
/// Two credentials are accepted by the deployed service: a static API key (which
/// is embedded in the build and therefore extractable from the APK) and a Clerk
/// session token (minted after sign-in, never stored in the binary). The client
/// this source shares already attaches the session token to allow-listed hosts,
/// so a signed-in reader authenticates with a credential that is not shipped
/// inside the app; the static key remains supported for builds and environments
/// that have no identity configured.
/// empty page so the reader keeps its cache and seed content.
class SlNewsApiSource implements FeedSource {
  /// Creates a source for `config` fetching through [client].
  ///
  /// Two configurations are in play and they are not the same thing: the
  /// `config` parameter is how to reach the scraper (host, key, page size,
  /// budget) while the [config] field is the aggregate feed the registry and
  /// reader see. The scraper runs on a cold-starting free tier, so
  /// [SlNewsApiConfig.timeout] is applied to [client] here rather than relying
  /// on the default the app happened to build the client with.
  SlNewsApiSource({required SlNewsApiConfig config, required ApiClient client})
    : _apiConfig = config,
      _api = client,
      // Shadows the parameter deliberately: the field is the derived
      // aggregate feed config, not the [SlNewsApiConfig] passed in.
      // ignore: prefer_initializing_formals
      config = configFor(config) {
    _api.setTimeout(config.timeout);
  }

  /// Synthetic aggregate configuration: the endpoint is one feed whose stories
  /// are attributed to the outlets they were scraped from.
  @override
  final FeedSourceConfig config;

  final SlNewsApiConfig _apiConfig;
  final ApiClient _api;

  /// Identifier prefix that namespaces scraper ids away from RSS url-hash ids.
  static const String idPrefix = 'slnews-api:';

  /// Path of the versioned, metadata-only route.
  static const String versionedPath = '/v1/news';

  /// Public read-only variant used when the reader has no session token.
  static const String publicVersionedPath = '/v1/public/news';

  /// Path of the legacy raw-row route.
  static const String legacyPath = '/api/news';

  /// Path of the open health probe (no bearer token).
  static const String healthPath = '/api/health';

  /// Publisher used when a row carries no `source` at all.
  static const Publisher unknownPublisher = Publisher(
    id: 'publisher:unknown',
    name: 'Unknown source',
    wordmark: 'SLNEWS',
    country: '',
  );

  /// One page of stories, or `[]` when disabled or the API failed.
  @override
  Future<List<Article>> fetch({int limit = 20}) async {
    final SlNewsApiPage page = await fetchPage(page: 1, pageSize: limit);
    return page.articles;
  }

  /// Reads one page, preferring the versioned route.
  ///
  /// `/api/news` is only attempted when `/v1/news` answers 404 (an older
  /// deploy). Any other failure — notably 401/403 from a bad key — reports an
  /// empty page instead of retrying a route that would fail identically.
  Future<SlNewsApiPage> fetchPage({
    int page = 1,
    int? pageSize,
    String? source,
    String? query,
  }) async {
    final int size = _clampPageSize(pageSize ?? _apiConfig.pageSize);
    if (!_apiConfig.isConfigured) {
      // Unconfigured builds must not touch the network at all.
      return SlNewsApiPage.empty(page: page, pageSize: size);
    }

    if (_apiConfig.preferVersioned) {
      try {
        return await _fetchVersioned(
          page: page,
          pageSize: size,
          source: source,
          query: query,
        );
      } on ApiException catch (error) {
        if (error.statusCode == 401 || error.statusCode == 403) {
          try {
            return await _fetchVersioned(
              page: page,
              pageSize: size,
              source: source,
              query: query,
              path: publicVersionedPath,
            );
          } catch (publicError) {
            AppLog.debug(
              'SlNewsApiSource(${config.id}): public news fallback failed '
              '($publicError)',
            );
            return SlNewsApiPage.empty(page: page, pageSize: size);
          }
        }
        if (error.statusCode != 404) {
          AppLog.debug(
            'SlNewsApiSource(${config.id}): /v1/news failed ($error)',
          );
          return SlNewsApiPage.empty(page: page, pageSize: size);
        }
        AppLog.debug(
          'SlNewsApiSource(${config.id}): /v1/news absent (404), using $legacyPath',
        );
      } catch (error) {
        AppLog.debug('SlNewsApiSource(${config.id}): /v1/news failed ($error)');
        return SlNewsApiPage.empty(page: page, pageSize: size);
      }
    }

    try {
      return await _fetchLegacy(
        page: page,
        pageSize: size,
        source: source,
        query: query,
      );
    } catch (error) {
      AppLog.debug(
        'SlNewsApiSource(${config.id}): $legacyPath failed ($error)',
      );
      return SlNewsApiPage.empty(page: page, pageSize: size);
    }
  }

  /// Reads one raw row through `/api/news/<id>`.
  ///
  /// Accepts both the namespaced id (`slnews-api:123`) and the bare numeric id;
  /// anything else is `null` without a request.
  Future<Article?> articleById(String id) async {
    final String raw = id.trim();
    final String digits = raw.startsWith(idPrefix)
        ? raw.substring(idPrefix.length)
        : raw;
    if (!_isNumeric(digits)) return null;
    if (!_apiConfig.isConfigured) return null;

    try {
      final ApiResponse response = await _api.get(
        '${_base()}$legacyPath/$digits',
        headers: _authHeaders(),
      );
      return _mapLegacyRow(_rowOf(response.data));
    } catch (error) {
      AppLog.debug(
        'SlNewsApiSource(${config.id}): article $digits failed ($error)',
      );
      return null;
    }
  }

  /// Whether the API reports a healthy database. Never throws.
  ///
  /// The probe is open, so it must not carry the bearer token.
  Future<bool> health() async {
    if (!_apiConfig.isConfigured) return false;
    try {
      final ApiResponse response = await _api.get(
        '${_base()}$healthPath',
        headers: const <String, String>{},
      );
      final Object? data = response.data;
      return data is Map && _text(data['status']).toLowerCase() == 'ok';
    } catch (error) {
      AppLog.debug(
        'SlNewsApiSource(${config.id}): health probe failed ($error)',
      );
      return false;
    }
  }

  /// Publisher for a raw outlet name, deterministic across runs.
  ///
  /// The id is a slug so the same outlet keeps one identity whichever row it
  /// arrived in; the wordmark is the uppercase name when it fits the badge and
  /// its initials otherwise.
  static Publisher publisherFor(String sourceName) =>
      _publisherFor(sourceName, unknownPublisher);

  /// Maps scraper category strings onto the curated SLNews category ids.
  ///
  /// Rows carry free-form labels (`Politics & Law`, `Business`, `World News`),
  /// sometimes several at once; the first recognised one wins and anything
  /// unrecognised lands in `top`.
  static String categoryIdFor(List<String> categories) =>
      _categoryIdFor(categories);

  /// Always [FeedSourceKind.restJson] with the configured host and page size.
  static FeedSourceConfig configFor(SlNewsApiConfig config) =>
      _configFor(config, versionedPath);

  Future<SlNewsApiPage> _fetchVersioned({
    required int page,
    required int pageSize,
    String? source,
    String? query,
    String path = versionedPath,
  }) async {
    final ApiResponse response = await _api.get(
      '${_base()}$path',
      query: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        if (_present(source)) 'source': source!.trim(),
        if (_present(query)) 'q': query!.trim(),
      },
      headers: _authHeaders(),
    );

    final Object? data = response.data;
    final Map<String, dynamic> envelope = data is Map
        ? _stringKeyed(data)
        : <String, dynamic>{};
    final List<Object?> rows = envelope['data'] is List
        ? envelope['data'] as List<Object?>
        : const <Object?>[];
    final Map<String, dynamic> meta = envelope['meta'] is Map
        ? _stringKeyed(envelope['meta'] as Map)
        : <String, dynamic>{};

    final List<Article> articles = <Article>[];
    for (final Object? row in rows) {
      final Article? article = _mapVersionedRow(row);
      if (article != null) articles.add(article);
    }

    final int total = _integer(meta['total']) ?? articles.length;
    final int responsePage = _integer(meta['page']) ?? page;
    final int responsePageSize = _clampPageSize(
      _integer(meta['page_size']) ?? pageSize,
    );
    final bool hasMore =
        _boolean(meta['has_more']) ?? responsePage * responsePageSize < total;

    return SlNewsApiPage(
      articles: articles,
      page: responsePage,
      pageSize: responsePageSize,
      total: total,
      hasMore: hasMore,
    );
  }

  Future<SlNewsApiPage> _fetchLegacy({
    required int page,
    required int pageSize,
    String? source,
    String? query,
  }) async {
    final ApiResponse response = await _api.get(
      '${_base()}$legacyPath',
      query: <String, dynamic>{
        'limit': pageSize,
        'page': page,
        if (_present(source)) 'source': source!.trim(),
        if (_present(query)) 'q': query!.trim(),
      },
      headers: _authHeaders(),
    );

    final Object? data = response.data;
    final List<Object?> rows = data is List
        ? data
        : (data is Map && data['data'] is List
              ? data['data'] as List<Object?>
              : const <Object?>[]);

    final List<Article> articles = <Article>[];
    for (final Object? row in rows) {
      final Article? article = _mapLegacyRow(row);
      if (article != null) articles.add(article);
    }

    // The legacy route reports the corpus size in a header, not the body.
    final int? headerTotal = response.intHeader('X-Total-Count');
    final int total = headerTotal ?? articles.length;
    final bool hasMore = headerTotal == null
        ? articles.length == pageSize
        : page * pageSize < total;

    return SlNewsApiPage(
      articles: articles,
      page: page,
      pageSize: pageSize,
      total: total,
      hasMore: hasMore,
    );
  }

  Article? _mapVersionedRow(Object? row) =>
      _mapRow(row, summaryKeys: const <String>['summary']);

  Article? _mapLegacyRow(Object? row) =>
      _mapRow(row, summaryKeys: const <String>['description', 'summary']);

  /// Shared row mapping: `/v1` and `/api/news` describe the same story with
  /// different field names, and both are metadata-only for the reader.
  Article? _mapRow(Object? row, {required List<String> summaryKeys}) {
    if (row is! Map) return null;
    final Map<String, dynamic> json = _stringKeyed(row);

    final String summary = _firstText(json, summaryKeys);
    final String title = _firstText(json, const <String>['title']);
    if (title.isEmpty && summary.isEmpty) return null;

    final List<String> categories = _stringList(json['category']);
    final String source = _text(json['source']);
    // `/v1` exposes only `published_at`; the legacy row uses `pubDate`.
    final DateTime publishedAt =
        _date(json['published_at']) ??
        _date(json['pubDate']) ??
        _date(json['createdAt']) ??
        _fallbackDate(json);

    final Publisher publisher = publisherFor(source);
    final List<String> tags = categories;
    final String categoryId = categoryIdFor(tags);
    final BreakingAssessment breaking = BreakingNewsPolicy.assess(
      title: title.isEmpty ? _truncate(summary) : title,
      summary: summary,
      categoryId: categoryId,
      tags: tags,
      publishedAt: publishedAt,
      isWire: publisher.isWire,
    );

    return Article(
      id: '$idPrefix${_idOf(json['id'])}',
      title: title.isEmpty ? _truncate(summary) : title,
      summary: summary,
      // The scraper API deliberately exposes no body: the reader shows the
      // summary and links out to the publisher.
      bodyHtml: '',
      author: _nullable(json['author']),
      // Summary-only contract: no body and no publisher-hosted image until a
      // source-specific licence is recorded.
      imageUrl: null,
      sourceUrl: _nullable(json['url'] ?? json['link']),
      publisher: publisher,
      publishedAt: publishedAt,
      categoryId: categoryId,
      tags: tags,
      isBreaking: breaking.isBreaking,
      isLive: false,
      previewOnly: true,
    );
  }

  /// Date to use when a row carries no usable timestamp; logs the mismatch
  /// because a silent `now()` would hide a wire-format change.
  DateTime _fallbackDate(Map<String, dynamic> json) {
    final bool hadCandidate =
        json['published_at'] != null ||
        json['pubDate'] != null ||
        json['createdAt'] != null;
    if (hadCandidate) {
      AppLog.debug(
        'SlNewsApiSource(${config.id}): unparseable date, using now()',
      );
    }
    return DateTime.now();
  }

  /// Static credential, when this build carries one.
  ///
  /// Blank in a signed-in-only build: the shared [ApiClient] then attaches the
  /// reader's session token, which it is allowed to send to this host, and the
  /// request goes out with no embedded secret at all.
  Map<String, String> _authHeaders() {
    final String key = _apiConfig.apiKey.trim();
    if (key.isEmpty) return const <String, String>{};
    return <String, String>{'Authorization': 'Bearer $key'};
  }

  String _base() => _normalizeBase(_apiConfig.baseUrl);
}
