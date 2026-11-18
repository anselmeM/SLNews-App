import '../../domain/models/article.dart';

/// How a configured endpoint is ingested.
enum FeedSourceKind {
  /// RSS 2.0 or Atom XML.
  rss,

  /// Plain REST endpoint returning articles as JSON.
  restJson,

  /// GraphQL endpoint queried with a stored query document.
  graphql;

  /// Parses the wire value used in seed JSON, defaulting to [rss].
  static FeedSourceKind fromWire(String? raw) =>
      switch (raw?.toLowerCase().replaceAll('_', '')) {
        'restjson' || 'json' || 'rest' => FeedSourceKind.restJson,
        'graphql' || 'gql' => FeedSourceKind.graphql,
        _ => FeedSourceKind.rss,
      };

  /// Serialised form used by [FeedSourceConfig.toJson].
  String get wireValue => name;
}

/// Everything the data layer needs to ingest one outlet endpoint.
///
/// Outlet metadata lives here rather than in the feed itself so a story keeps
/// the same publisher identity whether it arrived over RSS, JSON or the seed.
class FeedSourceConfig {
  /// Creates a source configuration.
  const FeedSourceConfig({
    required this.id,
    required this.outlet,
    required this.publisherId,
    required this.wordmark,
    required this.url,
    required this.kind,
    this.categoryId = 'top',
    this.websiteUrl,
    this.authorityScore = 1.0,
    this.isWire = false,
    this.summaryOnly = false,
    this.country = 'Sierra Leone',
  });

  /// Stable slug, e.g. `awoko`.
  final String id;

  /// Display name, e.g. "Awoko Newspaper".
  final String outlet;

  /// Publisher id used by `Article.publisher`.
  final String publisherId;

  /// Short uppercase mark drawn when no logo is available.
  final String wordmark;

  /// Feed or endpoint URL.
  final String url;

  final FeedSourceKind kind;

  /// Category slug that uncategorised items from this outlet fall into.
  final String categoryId;

  /// Human-facing homepage, also used to resolve relative links.
  final String? websiteUrl;

  /// Relative trust weight (1.0 = neutral) for future ranking merges.
  final double authorityScore;

  /// Wire services are labelled and skip the follow toggle.
  final bool isWire;

  /// Country the outlet reports from, e.g. `Sierra Leone` or `United
  /// Kingdom`. The home feed's Sierra Leone-first ordering reads this instead
  /// of matching publisher ids by hand.
  final String country;

  /// Keep only the feed summary in the reader and send the reader to the
  /// publisher for the full piece. Used for syndicated wires whose licence does
  /// not allow republishing the whole body.
  final bool summaryOnly;

  /// Serialises this configuration for seed storage.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'outlet': outlet,
    'publisherId': publisherId,
    'wordmark': wordmark,
    'url': url,
    'kind': kind.wireValue,
    'categoryId': categoryId,
    'websiteUrl': websiteUrl,
    'authorityScore': authorityScore,
    'isWire': isWire,
    'summaryOnly': summaryOnly,
    'country': country,
  };

  /// Rebuilds a configuration from seed JSON, tolerating missing optional keys.
  factory FeedSourceConfig.fromJson(Map<String, dynamic> json) =>
      FeedSourceConfig(
        id: json['id'] as String? ?? '',
        outlet: json['outlet'] as String? ?? '',
        publisherId:
            json['publisherId'] as String? ?? json['id'] as String? ?? '',
        wordmark: json['wordmark'] as String? ?? '',
        url: json['url'] as String? ?? '',
        kind: FeedSourceKind.fromWire(json['kind'] as String?),
        categoryId: json['categoryId'] as String? ?? 'top',
        websiteUrl: json['websiteUrl'] as String?,
        authorityScore: (json['authorityScore'] as num?)?.toDouble() ?? 1.0,
        isWire: json['isWire'] as bool? ?? false,
        summaryOnly: json['summaryOnly'] as bool? ?? false,
        country: json['country'] as String? ?? 'Sierra Leone',
      );

  @override
  bool operator ==(Object other) =>
      other is FeedSourceConfig && other.id == id && other.url == url;

  @override
  int get hashCode => Object.hash(id, url);
}

/// One ingestible endpoint.
abstract interface class FeedSource {
  /// Static description of the outlet and endpoint.
  FeedSourceConfig get config;

  /// Fetches up to [limit] stories. Implementations never throw: an unreachable
  /// outlet yields an empty list so one bad feed cannot blank the app.
  Future<List<Article>> fetch({int limit = 20});
}
