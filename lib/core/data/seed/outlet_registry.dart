import '../sources/api_client.dart';
import '../sources/feed_source.dart';
import '../sources/json_endpoint_source.dart';
import '../sources/rest_api_source.dart';
import '../sources/rss_feed_source.dart';

/// The outlets SLNews aggregates, with provenance for every URL.
///
/// `VERIFIED` entries were fetched from the build environment and returned a
/// parseable feed. `UNVERIFIED` entries point at the outlet's site root and are
/// configured as [FeedSourceKind.restJson] until a public feed is confirmed —
/// promoting one to `rss` without checking it would silently cost the reader
/// that outlet. Probable feed URLs are recorded in comments for the next pass.
abstract final class OutletRegistry {
  /// Every configured outlet, ordered as it appears in the Following tab.
  static const List<FeedSourceConfig> all = <FeedSourceConfig>[
    // VERIFIED 2026-10-15: WordPress RSS 2.0 (HTTP 200) with content:encoded and dc:creator.
    FeedSourceConfig(
      id: 'sltelegraph',
      outlet: 'The Sierra Leone Telegraph',
      publisherId: 'sltelegraph',
      wordmark: 'SLT',
      url: 'https://www.thesierraleonetelegraph.com/feed/',
      kind: FeedSourceKind.rss,
      categoryId: 'top',
      websiteUrl: 'https://www.thesierraleonetelegraph.com',
      authorityScore: 1.1,
    ),
    // VERIFIED 2026-10-15: WordPress RSS 2.0 (HTTP 200); bodies carry inline <img>.
    FeedSourceConfig(
      id: 'sierraloaded',
      outlet: 'Sierraloaded',
      publisherId: 'sierraloaded',
      wordmark: 'SIERRA LOADED',
      url: 'https://sierraloaded.sl/feed/',
      kind: FeedSourceKind.rss,
      categoryId: 'top',
      websiteUrl: 'https://sierraloaded.sl',
      authorityScore: 1.0,
    ),
    // VERIFIED 2026-10-15: BBC News Africa RSS 2.0 (HTTP 200) with media:thumbnail.
    FeedSourceConfig(
      id: 'bbcafrica',
      outlet: 'BBC News Africa',
      publisherId: 'bbcafrica',
      wordmark: 'BBC',
      url: 'https://feeds.bbci.co.uk/news/world/africa/rss.xml',
      kind: FeedSourceKind.rss,
      categoryId: 'world',
      websiteUrl: 'https://www.bbc.co.uk/news/world/africa',
      authorityScore: 1.4,
      isWire: true,
    ),
    // UNVERIFIED endpoint 2026-10-15: awoko.org did not resolve from the build network.
    // Probable WordPress feed: https://awoko.org/feed/ (unconfirmed).
    FeedSourceConfig(
      id: 'awoko',
      outlet: 'Awoko Newspaper',
      publisherId: 'awoko',
      wordmark: 'AWOKO',
      url: 'https://awoko.org',
      kind: FeedSourceKind.restJson,
      categoryId: 'top',
      websiteUrl: 'https://awoko.org',
      authorityScore: 1.0,
    ),
    // UNVERIFIED endpoint 2026-10-15: concordtimes.net did not resolve from the build network.
    // Probable WordPress feed: https://concordtimes.net/feed/ (unconfirmed).
    FeedSourceConfig(
      id: 'concordtimes',
      outlet: 'Concord Times',
      publisherId: 'concordtimes',
      wordmark: 'CONCORD',
      url: 'https://concordtimes.net',
      kind: FeedSourceKind.restJson,
      categoryId: 'politics',
      websiteUrl: 'https://concordtimes.net',
      authorityScore: 1.0,
    ),
    // UNVERIFIED endpoint 2026-10-15: politicosl.com answered 404 for /feed/;
    // no public feed path confirmed yet, so the site root is used as a stub.
    FeedSourceConfig(
      id: 'politicosl',
      outlet: 'Politico SL',
      publisherId: 'politicosl',
      wordmark: 'POLITICO',
      url: 'https://politicosl.com',
      kind: FeedSourceKind.restJson,
      categoryId: 'politics',
      websiteUrl: 'https://politicosl.com',
      authorityScore: 1.0,
    ),
    // UNVERIFIED endpoint 2026-10-15: standardtimespress.net did not resolve.
    FeedSourceConfig(
      id: 'standardtimes',
      outlet: 'Standard Times',
      publisherId: 'standardtimes',
      wordmark: 'STANDARD TIMES',
      url: 'https://standardtimespress.net',
      kind: FeedSourceKind.restJson,
      categoryId: 'politics',
      websiteUrl: 'https://standardtimespress.net',
      authorityScore: 0.9,
    ),
    // UNVERIFIED endpoint 2026-10-15: domain not confirmed; the newswire also
    // syndicates by email and social, so a feed may not exist at all.
    FeedSourceConfig(
      id: 'kallon',
      outlet: "Kallon's Newswire",
      publisherId: 'kallon',
      wordmark: 'KALLON',
      url: 'https://kallonsnewswire.com',
      kind: FeedSourceKind.restJson,
      categoryId: 'top',
      websiteUrl: 'https://kallonsnewswire.com',
      authorityScore: 0.9,
    ),
    // UNVERIFIED endpoint 2026-10-15: no public RSS feed; Reuters retired them.
    // Wire copy is expected to arrive through a licensed JSON endpoint instead.
    FeedSourceConfig(
      id: 'reuters',
      outlet: 'Reuters Africa',
      publisherId: 'reuters',
      wordmark: 'REUTERS',
      url: 'https://www.reuters.com/world/africa/',
      kind: FeedSourceKind.restJson,
      categoryId: 'world',
      websiteUrl: 'https://www.reuters.com/world/africa/',
      authorityScore: 1.5,
      isWire: true,
    ),
    // UNVERIFIED endpoint 2026-10-15: AP publishes no public RSS; site root used.
    FeedSourceConfig(
      id: 'ap',
      outlet: 'AP Africa',
      publisherId: 'ap',
      wordmark: 'AP',
      url: 'https://apnews.com/hub/africa',
      kind: FeedSourceKind.restJson,
      categoryId: 'world',
      websiteUrl: 'https://apnews.com/hub/africa',
      authorityScore: 1.5,
      isWire: true,
    ),
    // VERIFIED 2026-10-22: BBC Sport all-sport RSS (HTTP 200) — football,
    // cricket, F1, tennis, rugby, athletics, boxing, golf, basketball, cycling,
    // darts and more. Summary-only; BBC's feed terms do not allow republishing.
    FeedSourceConfig(
      id: 'bbcsport',
      outlet: 'BBC Sport',
      publisherId: 'bbcsport',
      wordmark: 'BBC SPORT',
      url: 'https://feeds.bbci.co.uk/sport/rss.xml',
      kind: FeedSourceKind.rss,
      categoryId: 'sports',
      websiteUrl: 'https://www.bbc.co.uk/sport',
      authorityScore: 1.4,
      isWire: true,
      summaryOnly: true,
    ),
    // VERIFIED 2026-10-22: BBC Sport Africa RSS (HTTP 200) — African sport
    // across codes, the closest wire coverage to a Sierra Leonean audience.
    FeedSourceConfig(
      id: 'bbcsportafrica',
      outlet: 'BBC Sport Africa',
      publisherId: 'bbcsportafrica',
      wordmark: 'BBC AFRICA',
      url: 'https://feeds.bbci.co.uk/sport/africa/rss.xml',
      kind: FeedSourceKind.rss,
      categoryId: 'sports',
      websiteUrl: 'https://www.bbc.co.uk/sport/africa',
      authorityScore: 1.35,
      isWire: true,
      summaryOnly: true,
    ),
    // VERIFIED 2026-10-22: Football Sierra Leone (HTTP 200). Local football:
    // national teams, WAFU, AFCON qualifiers, players abroad.
    FeedSourceConfig(
      id: 'footballsierraleone',
      outlet: 'Football Sierra Leone',
      publisherId: 'footballsierraleone',
      wordmark: 'FSL',
      url: 'https://footballsierraleone.com/feed/',
      kind: FeedSourceKind.rss,
      categoryId: 'sports',
      websiteUrl: 'https://footballsierraleone.com',
      authorityScore: 1.2,
      summaryOnly: true,
    ),
    // VERIFIED 2026-10-22: ESPN league RSS (HTTP 200) — the four major North
    // American leagues, which BBC's all-sport feed only covers occasionally.
    // Summary-only: ESPN's feed terms do not allow republishing the body.
    FeedSourceConfig(
      id: 'espn-nba',
      outlet: 'ESPN NBA',
      publisherId: 'espn-nba',
      wordmark: 'NBA',
      url: 'https://www.espn.com/espn/rss/nba/news',
      kind: FeedSourceKind.rss,
      categoryId: 'sports',
      websiteUrl: 'https://www.espn.com/nba/',
      authorityScore: 1.3,
      isWire: true,
      summaryOnly: true,
    ),
    FeedSourceConfig(
      id: 'espn-nfl',
      outlet: 'ESPN NFL',
      publisherId: 'espn-nfl',
      wordmark: 'NFL',
      url: 'https://www.espn.com/espn/rss/nfl/news',
      kind: FeedSourceKind.rss,
      categoryId: 'sports',
      websiteUrl: 'https://www.espn.com/nfl/',
      authorityScore: 1.3,
      isWire: true,
      summaryOnly: true,
    ),
    FeedSourceConfig(
      id: 'espn-nhl',
      outlet: 'ESPN NHL',
      publisherId: 'espn-nhl',
      wordmark: 'NHL',
      url: 'https://www.espn.com/espn/rss/nhl/news',
      kind: FeedSourceKind.rss,
      categoryId: 'sports',
      websiteUrl: 'https://www.espn.com/nhl/',
      authorityScore: 1.3,
      isWire: true,
      summaryOnly: true,
    ),
    FeedSourceConfig(
      id: 'espn-mlb',
      outlet: 'ESPN MLB',
      publisherId: 'espn-mlb',
      wordmark: 'MLB',
      url: 'https://www.espn.com/espn/rss/mlb/news',
      kind: FeedSourceKind.rss,
      categoryId: 'sports',
      websiteUrl: 'https://www.espn.com/mlb/',
      authorityScore: 1.3,
      isWire: true,
      summaryOnly: true,
    ),
  ];

  /// Looks up an outlet by its [FeedSourceConfig.id] or `publisherId`.
  ///
  /// Throws [ArgumentError] for an unknown id: callers pass ids that came from
  /// this registry, so a miss is a programming error rather than user input.
  static FeedSourceConfig byId(String id) {
    for (final FeedSourceConfig config in all) {
      if (config.id == id || config.publisherId == id) return config;
    }
    throw ArgumentError.value(id, 'id', 'Unknown outlet id');
  }

  /// Builds one ingestible source per configured outlet.
  static List<FeedSource> buildSources(ApiClient client) => <FeedSource>[
    for (final FeedSourceConfig config in all) _sourceFor(config, client),
  ];

  static FeedSource _sourceFor(FeedSourceConfig config, ApiClient client) {
    switch (config.kind) {
      case FeedSourceKind.rss:
        return RssFeedSource(config: config, client: client);
      case FeedSourceKind.restJson:
        return RestApiSource(config: config, client: client);
      case FeedSourceKind.graphql:
        // A GraphQL outlet needs a query document, which FeedSourceConfig does
        // not carry yet; the JSON GET form is the safe default.
        return JsonEndpointSource(config: config, client: client);
    }
  }
}
