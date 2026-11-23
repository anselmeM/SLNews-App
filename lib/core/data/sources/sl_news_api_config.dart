part of 'sl_news_api_source.dart';

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

  /// True when the scraper host is configured.
  ///
  /// Read-only content is public, so a build without an embedded key or an
  /// identity still uses the public fallback routes. Authentication only adds
  /// account sync; it is not a content gate.
  bool get isConfigured => baseUrl.trim().isNotEmpty;

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
