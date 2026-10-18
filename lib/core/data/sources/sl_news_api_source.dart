import 'package:flutter/foundation.dart';

import '../../domain/models/article.dart';
import '../../domain/models/news_category.dart';
import '../../domain/models/publisher.dart';
import 'api_client.dart';
import 'feed_source.dart';
import 'wire_date.dart';

/// Where the SLNews scraper API lives and how to authenticate to it.
///
/// Two credentials are accepted by the deployed service: a static API key (which
/// is embedded in the build and therefore extractable from the APK) and a Clerk
/// session token (minted after sign-in, never stored in the binary). The client
/// this source shares already attaches the session token to allow-listed hosts,
/// so a signed-in reader authenticates with a credential that is not shipped
/// inside the app; the static key remains supported for builds and environments
/// that have no identity configured.
@immutable
class SlNewsApiConfig {
  /// Creates a configuration for an explicitly supplied host and key.
  ///
  /// [sessionTokenAvailable] says whether the app can mint a session token at
  /// all (i.e. an identity is configured); it lets the source run without a
  /// static key instead of disabling itself.
  const SlNewsApiConfig({
    required this.baseUrl,
    required this.apiKey,
    this.sessionTokenAvailable = false,
    this.pageSize = 20,
    this.preferVersioned = true,
    this.timeout = const Duration(seconds: 10),
  });

  /// Reads compile-time configuration:
  ///   `--dart-define=SLNEWS_API_URL=…`      (default: the deployed Render host)
  ///   `--dart-define=SLNEWS_API_KEY=…`      (default: empty → key-less, tokens only)
  ///   `--dart-define=SLNEWS_API_PAGE_SIZE=…`
  factory SlNewsApiConfig.fromEnvironment({
    bool sessionTokenAvailable = false,
  }) {
    const String url = String.fromEnvironment(
      'SLNEWS_API_URL',
      defaultValue: defaultBaseUrl,
    );
    const String key = String.fromEnvironment('SLNEWS_API_KEY');
    const String rawPageSize = String.fromEnvironment('SLNEWS_API_PAGE_SIZE');
    return SlNewsApiConfig(
      baseUrl: url,
      apiKey: key,
      sessionTokenAvailable: sessionTokenAvailable,
      pageSize: _clampPageSize(
        int.tryParse(rawPageSize.trim()) ?? defaultPageSize,
      ),
    );
  }

  /// Host the scraper API is deployed on when no override is provided.
  static const String defaultBaseUrl = 'https://slnewsapiscapper.onrender.com';

  /// Page size used when neither the environment nor a caller picks one.
  static const int defaultPageSize = 20;

  /// Lower/upper bound accepted for a page size.
  static const int minPageSize = 1;

  /// Upper bound accepted for a page size; the API refuses larger pages.
  static const int maxPageSize = 100;

  /// Origin plus optional path prefix, e.g. `https://host`. Never has a
  /// trailing slash.
  final String baseUrl;

  /// Bearer token for every authenticated endpoint. Never logged.
  ///
  /// Empty in a build that relies on the Clerk session token instead; the
  /// shared client attaches that token per request, so nothing has to be
  /// embedded in the APK.
  final String apiKey;

  /// Whether an identity is configured, so a session token can be supplied.
  final bool sessionTokenAvailable;

  /// Default number of stories per page.
  final int pageSize;

  /// Whether `/v1/news` is attempted before falling back to `/api/news`.
  final bool preferVersioned;

  /// Per-request budget for the injected [ApiClient].
  final Duration timeout;

  /// True when the scraper can be reached and authenticated somehow: either a
  /// static key is embedded, or the reader can sign in for a session token.
  ///
  /// A configured source without either credential would only ever receive 401s,
  /// which is why this gate exists rather than checking [apiKey] alone.
  bool get isConfigured =>
      baseUrl.trim().isNotEmpty &&
      (apiKey.trim().isNotEmpty || sessionTokenAvailable);

  /// Copy of this configuration with the given fields replaced.
  SlNewsApiConfig copyWith({
    String? baseUrl,
    String? apiKey,
    bool? sessionTokenAvailable,
    int? pageSize,
    bool? preferVersioned,
    Duration? timeout,
  }) => SlNewsApiConfig(
    baseUrl: baseUrl ?? this.baseUrl,
    apiKey: apiKey ?? this.apiKey,
    sessionTokenAvailable: sessionTokenAvailable ?? this.sessionTokenAvailable,
    pageSize: pageSize == null ? this.pageSize : _clampPageSize(pageSize),
    preferVersioned: preferVersioned ?? this.preferVersioned,
    timeout: timeout ?? this.timeout,
  );

  /// Host of [baseUrl], used by [toString] so the key is never printed.
  String get host {
    final String trimmed = baseUrl.trim();
    if (trimmed.isEmpty) return '';
    try {
      final String host = Uri.parse(trimmed).host;
      if (host.isNotEmpty) return host;
    } on FormatException {
      // Fall through to the textual form below.
    }
    return trimmed;
  }

  /// Never logs or exposes the key.
  @override
  String toString() =>
      'SlNewsApiConfig($host, key: ${isConfigured ? '***' : '<unset>'}, '
      'pageSize: $pageSize)';

  /// Clamps [value] into the range the API accepts.
  static int _clampPageSize(int value) => value < minPageSize
      ? minPageSize
      : (value > maxPageSize ? maxPageSize : value);
}

/// One page of the scraper API.
@immutable
class SlNewsApiPage {
  /// Wraps a decoded page of [articles] and its pagination facts.
  const SlNewsApiPage({
    required this.articles,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.hasMore,
  });

  /// Stories on this page, already mapped to domain objects.
  final List<Article> articles;

  /// 1-based page index that produced [articles].
  final int page;

  /// Page size the API was asked for.
  final int pageSize;

  /// Total stories matching the query, or the page length when unknown.
  final int total;

  /// Whether a further page exists.
  final bool hasMore;

  /// Empty page used for every degraded path.
  static SlNewsApiPage empty({int page = 1, int pageSize = 20}) =>
      SlNewsApiPage(
        articles: const <Article>[],
        page: page,
        pageSize: pageSize,
        total: 0,
        hasMore: false,
      );
}

/// Aggregated Sierra Leone feed served by the SLNews scraper API.
///
/// The scraper is a *content source*, not an outlet: every row carries the
/// publisher it was scraped from, so each story is attributed to that outlet
/// while the endpoint itself is described by one synthetic [FeedSourceConfig].
///
/// Two routes exist because the service evolved:
/// * `/v1/news` — the versioned, metadata-only contract (id, title, summary,
///   source, category, url, published_at),
/// * `/api/news` — the legacy raw row (adds author, imageUrl, paragraphs) with
///   the total in the `X-Total-Count` header.
///
/// Nothing here throws: a wrong key, an outage or a shape change degrades to an
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

  /// Path of the legacy raw-row route.
  static const String legacyPath = '/api/news';

  /// Path of the open health probe (no bearer token).
  static const String healthPath = '/api/health';

  /// Publisher used when a row carries no `source` at all.
  static const Publisher unknownPublisher = Publisher(
    id: 'publisher:unknown',
    name: 'Unknown source',
    wordmark: 'SLNEWS',
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
        if (error.statusCode != 404) {
          debugPrint('SlNewsApiSource(${config.id}): /v1/news failed ($error)');
          return SlNewsApiPage.empty(page: page, pageSize: size);
        }
        debugPrint(
          'SlNewsApiSource(${config.id}): /v1/news absent (404), using $legacyPath',
        );
      } catch (error) {
        debugPrint('SlNewsApiSource(${config.id}): /v1/news failed ($error)');
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
      debugPrint('SlNewsApiSource(${config.id}): $legacyPath failed ($error)');
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
      debugPrint(
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
      debugPrint('SlNewsApiSource(${config.id}): health probe failed ($error)');
      return false;
    }
  }

  /// Publisher for a raw outlet name, deterministic across runs.
  ///
  /// The id is a slug so the same outlet keeps one identity whichever row it
  /// arrived in; the wordmark is the uppercase name when it fits the badge and
  /// its initials otherwise.
  static Publisher publisherFor(String sourceName) {
    final String name = _collapse(sourceName);
    if (name.isEmpty) return unknownPublisher;

    final bool isWire = _isWire(name);
    final bool shortEnough = name.length <= 18;
    return Publisher(
      id: 'publisher:${_slug(name)}',
      name: name,
      wordmark: shortEnough ? name.toUpperCase() : _initials(name),
      isWire: isWire,
    );
  }

  /// Maps scraper category strings onto the curated SLNews category ids.
  ///
  /// Rows carry free-form labels (`Politics & Law`, `Business`, `World News`),
  /// sometimes several at once; the first recognised one wins and anything
  /// unrecognised lands in `top`.
  static String categoryIdFor(List<String> categories) {
    for (final String raw in categories) {
      for (final String part in _splitCategories(raw)) {
        final String? id = _categoryIdForToken(part);
        if (id != null) return id;
      }
    }
    return 'top';
  }

  /// Always [FeedSourceKind.restJson] with the configured host and page size.
  static FeedSourceConfig configFor(SlNewsApiConfig config) => FeedSourceConfig(
    id: 'slnews-api',
    outlet: 'SLNews',
    publisherId: 'publisher:slnews',
    wordmark: 'SLNEWS',
    url: '${_normalizeBase(config.baseUrl)}$versionedPath',
    kind: FeedSourceKind.restJson,
    categoryId: 'top',
    websiteUrl: 'https://slnews.net',
  );

  Future<SlNewsApiPage> _fetchVersioned({
    required int page,
    required int pageSize,
    String? source,
    String? query,
  }) async {
    final ApiResponse response = await _api.get(
      '${_base()}$versionedPath',
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

    return Article(
      id: '$idPrefix${_idOf(json['id'])}',
      title: title.isEmpty ? _truncate(summary) : title,
      summary: summary,
      // The scraper API deliberately exposes no body: the reader shows the
      // summary and links out to the publisher.
      bodyHtml: '',
      author: _nullable(json['author']),
      imageUrl: _nullable(json['imageUrl']),
      sourceUrl: _nullable(json['url'] ?? json['link']),
      publisher: publisherFor(source),
      publishedAt: publishedAt,
      categoryId: categoryIdFor(categories),
      tags: categories,
      isBreaking: false,
      isLive: false,
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
      debugPrint(
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

  static bool _isNumeric(String value) =>
      value.isNotEmpty && int.tryParse(value) != null;

  static bool _present(String? value) =>
      value != null && value.trim().isNotEmpty;

  static String _normalizeBase(String baseUrl) {
    String working = baseUrl.trim();
    while (working.endsWith('/')) {
      working = working.substring(0, working.length - 1);
    }
    return working;
  }

  static int _clampPageSize(int value) => value < SlNewsApiConfig.minPageSize
      ? SlNewsApiConfig.minPageSize
      : (value > SlNewsApiConfig.maxPageSize
            ? SlNewsApiConfig.maxPageSize
            : value);

  static String _idOf(Object? value) {
    if (value is num) {
      final int asInt = value.toInt();
      return value == asInt ? '$asInt' : value.toString();
    }
    return _text(value);
  }

  static Map<String, dynamic> _stringKeyed(Map<dynamic, dynamic> raw) {
    final Map<String, dynamic> json = <String, dynamic>{};
    raw.forEach((Object? key, Object? value) {
      if (key is String) json[key] = value;
    });
    return json;
  }

  /// Picks the raw row out of either a bare object or a `{data: {...}}` wrapper.
  static Object? _rowOf(Object? payload) {
    if (payload is Map) {
      final Object? nested = payload['data'];
      return nested is Map ? nested : payload;
    }
    if (payload is List) return payload.isEmpty ? null : payload.first;
    return null;
  }

  static String _firstText(Map<String, dynamic> json, List<String> keys) {
    for (final String key in keys) {
      final String value = _text(json[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  /// Strips markup, decodes entities and collapses whitespace.
  ///
  /// Tags are removed before entities are decoded so a summary containing
  /// `&lt;script&gt;` can never become live markup downstream.
  static String _text(Object? value) {
    if (value is num || value is bool) return value.toString();
    if (value is! String) return '';
    final String withoutTags = value.replaceAll(RegExp(r'<[^>]*>'), ' ');
    return _collapse(_decodeEntities(withoutTags));
  }

  /// Same normalisation, but `null` for an empty result.
  static String? _nullable(Object? value) {
    final String text = _text(value);
    return text.isEmpty ? null : text;
  }

  static String _collapse(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _truncate(String text) {
    if (text.length <= 240) return text;
    final int cut = text.lastIndexOf(' ', 240);
    return '${text.substring(0, cut <= 0 ? 240 : cut).trimRight()}…';
  }

  static final RegExp _numericEntity = RegExp(r'&#(x?)([0-9a-fA-F]+);');

  static const Map<String, String> _namedEntities = <String, String>{
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': ' ',
    'hellip': '…',
    'mdash': '—',
    'ndash': '–',
    'rsquo': '’',
    'lsquo': '‘',
    'rdquo': '”',
    'ldquo': '“',
  };

  static String _decodeEntities(String value) {
    if (!value.contains('&')) return value;
    String decoded = value.replaceAllMapped(_numericEntity, (Match match) {
      final bool hex = match.group(1) == 'x';
      final int? code = int.tryParse(match.group(2)!, radix: hex ? 16 : 10);
      if (code == null || code < 0 || code > 0x10FFFF) return match.group(0)!;
      return String.fromCharCode(code);
    });
    for (final MapEntry<String, String> entry in _namedEntities.entries) {
      decoded = decoded.replaceAll('&${entry.key};', entry.value);
    }
    return decoded;
  }

  /// Whether [name] belongs to a wire service.
  ///
  /// Checked as a whole word (so `Apex News` is not `AP`) as well as a plain
  /// containment (so `The Associated Press` is), because wires are abbreviated
  /// inconsistently in scraped source labels.
  static bool _isWire(String name) {
    final String needle = name.toLowerCase();
    for (final String wire in _wireNames) {
      if (needle.contains(wire)) return true;
    }
    // Abbreviations such as `AP` also appear as standalone tokens.
    return RegExp(r'\bAP\b').hasMatch(name);
  }

  static const List<String> _wireNames = <String>[
    'reuters',
    'associated press',
    'afp',
    'bbc',
  ];

  static const Set<String> _stopWords = <String>{
    'the',
    'a',
    'an',
    'of',
    'and',
    'for',
  };

  static String _slug(String name) {
    final String lower = name.toLowerCase();
    final StringBuffer buffer = StringBuffer();
    for (final int unit in lower.runes) {
      final String char = String.fromCharCode(unit);
      if (RegExp(r'[a-z0-9]').hasMatch(char)) {
        buffer.write(char);
      } else if (RegExp(r'\s').hasMatch(char)) {
        buffer.write(' ');
      }
    }
    final String joined = buffer.toString().trim().replaceAll(
      RegExp(r'\s+'),
      '-',
    );
    return joined;
  }

  /// Initials of the significant words, e.g. `The Sierra Leone Telegraph` →
  /// `TSLT`.
  ///
  /// A leading article is kept — it is the first letter a reader scans for —
  /// while articles elsewhere are dropped, so `News of the World` → `NW`.
  static String _initials(String name) {
    final List<String> words = <String>[];
    for (final String word in name.split(RegExp(r'\s+'))) {
      final String cleaned = word.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
      if (cleaned.isEmpty) continue;
      if (words.isNotEmpty && _stopWords.contains(cleaned.toLowerCase())) {
        continue;
      }
      words.add(cleaned);
    }
    if (words.isEmpty) return name.toUpperCase();
    final StringBuffer initials = StringBuffer();
    for (final String word in words) {
      initials.write(word[0].toUpperCase());
    }
    return initials.toString();
  }

  /// Splits a raw label on the separators outlets use to pack two categories.
  static List<String> _splitCategories(String raw) {
    final List<String> parts = <String>[];
    for (final String chunk in raw.split(RegExp(r'[&,;]| / |/|\|'))) {
      final String part = _collapse(chunk).replaceAll(RegExp(r'\s+'), ' ');
      if (part.isNotEmpty && !parts.contains(part)) parts.add(part);
    }
    return parts;
  }

  /// Labels seen in the wild that do not match a curated label verbatim.
  static const Map<String, String> _categoryAliases = <String, String>{
    'politics': 'politics',
    'politics & law': 'politics',
    'politics and law': 'politics',
    'political': 'politics',
    'government': 'politics',
    'governance': 'politics',
    'business': 'business',
    'economy': 'business',
    'economic': 'business',
    'finance': 'business',
    'sports': 'sports',
    'sport': 'sports',
    'football': 'sports',
    'health': 'health',
    'healthcare': 'health',
    'medicine': 'health',
    'tech': 'tech',
    'technology': 'tech',
    'ict': 'tech',
    'education': 'education',
    'school': 'education',
    'mining': 'mining',
    'minerals': 'mining',
    'world': 'world',
    'international': 'world',
    'global': 'world',
    'culture': 'culture',
    'arts': 'culture',
    'entertainment': 'culture',
    'music': 'music',
    'cars': 'cars',
    'cars and vehicles': 'cars',
    'vehicles': 'cars',
    'automotive': 'cars',
    'top': 'top',
    'top stories': 'top',
    'news': 'top',
    'general': 'top',
    'breaking news': 'top',
    'local news': 'top',
    'national news': 'top',
  };

  static String? _categoryIdForToken(String token) {
    final String needle = token.toLowerCase().trim();
    if (needle.isEmpty) return null;

    final String? alias = _categoryAliases[needle];
    if (alias != null) return alias;

    for (final NewsCategory category in NewsCategories.all) {
      if (category.id.toLowerCase() == needle) return category.id;
      if (category.label.toLowerCase() == needle) return category.id;
    }
    // Fuzzy: `World News` and `Business & Finance` still belong to a curated
    // category when a whole word of the label is present.
    for (final NewsCategory category in NewsCategories.all) {
      final Set<String> words = _words(category.label);
      for (final String word in _words(token)) {
        if (words.contains(word)) return category.id;
      }
    }
    return null;
  }

  static Set<String> _words(String value) => value
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((String word) => word.length > 2)
      .toSet();

  static List<String> _stringList(Object? value) {
    final List<String> values = <String>[];
    if (value is List) {
      for (final Object? entry in value) {
        final String text = _text(entry);
        if (text.isNotEmpty && !values.contains(text)) values.add(text);
      }
    } else {
      final String text = _text(value);
      if (text.isNotEmpty) values.add(text);
    }
    return values;
  }

  static int? _integer(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static bool? _boolean(Object? value) {
    if (value is bool) return value;
    if (value is String) {
      final String text = value.trim().toLowerCase();
      if (text == 'true') return true;
      if (text == 'false') return false;
    }
    return null;
  }

  /// Parses ISO-8601, RFC-822 and epoch seconds/millis through [WireDate].
  static DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    if (value is num) return WireDate.fromEpoch(value);
    if (value is String) return WireDate.parse(value);
    return null;
  }
}
