import '../../domain/models/article.dart';
import 'api_client.dart';
import 'feed_source.dart';
import 'rss_feed_source.dart';

import 'package:slnews_mobile/core/utils/app_log.dart';

/// League-specific news, never the generic sports feed.
///
/// US leagues use their Yahoo Sports RSS channel; competitions without a Yahoo
/// channel use a Google News query. The feed itself is the authoritative league
/// label: an NBA endpoint can only return NBA stories, so no keyword matching is
/// applied here. Anything else would reintroduce the cross-league guessing this
/// replaced.
class LeagueNewsSource {
  LeagueNewsSource({required this.client});

  final ApiClient client;
  final Map<String, List<Article>> _cache = <String, List<Article>>{};

  static const Map<String, _LeagueFeed> _feeds = <String, _LeagueFeed>{
    'nba': _LeagueFeed(
      url: 'https://sports.yahoo.com/nba/rss.xml',
      outlet: 'Yahoo Sports',
      publisherId: 'yahoo-sports',
      wordmark: 'YAHOO',
      website: 'https://sports.yahoo.com/nba/',
    ),
    'nfl': _LeagueFeed(
      url: 'https://sports.yahoo.com/nfl/rss.xml',
      outlet: 'Yahoo Sports',
      publisherId: 'yahoo-sports',
      wordmark: 'YAHOO',
      website: 'https://sports.yahoo.com/nfl/',
    ),
    'mlb': _LeagueFeed(
      url: 'https://sports.yahoo.com/mlb/rss.xml',
      outlet: 'Yahoo Sports',
      publisherId: 'yahoo-sports',
      wordmark: 'YAHOO',
      website: 'https://sports.yahoo.com/mlb/',
    ),
    'nhl': _LeagueFeed(
      url: 'https://sports.yahoo.com/nhl/rss.xml',
      outlet: 'Yahoo Sports',
      publisherId: 'yahoo-sports',
      wordmark: 'YAHOO',
      website: 'https://sports.yahoo.com/nhl/',
    ),
    'epl': _LeagueFeed(
      url: 'https://news.google.com/rss/search?q=%22Premier+League%22&hl=en-US&gl=US&ceid=US:en',
      outlet: 'Google News',
      publisherId: 'google-news',
      wordmark: 'NEWS',
      website: 'https://news.google.com/',
    ),
    'spl': _LeagueFeed(
      url: 'https://news.google.com/rss/search?q=%22Sierra+Leone+Premier+League%22&hl=en-US&gl=US&ceid=US:en',
      outlet: 'Google News',
      publisherId: 'google-news',
      wordmark: 'NEWS',
      website: 'https://news.google.com/',
    ),
    'afcon': _LeagueFeed(
      url: 'https://news.google.com/rss/search?q=AFCON&hl=en-US&gl=US&ceid=US:en',
      outlet: 'Google News',
      publisherId: 'google-news',
      wordmark: 'NEWS',
      website: 'https://news.google.com/',
    ),
    'champions-league': _LeagueFeed(
      url: 'https://news.google.com/rss/search?q=%22UEFA+Champions+League%22&hl=en-US&gl=US&ceid=US:en',
      outlet: 'Google News',
      publisherId: 'google-news',
      wordmark: 'NEWS',
      website: 'https://news.google.com/',
    ),
    'la-liga': _LeagueFeed(
      url: 'https://news.google.com/rss/search?q=%22La+Liga%22&hl=en-US&gl=US&ceid=US:en',
      outlet: 'Google News',
      publisherId: 'google-news',
      wordmark: 'NEWS',
      website: 'https://news.google.com/',
    ),
    'serie-a': _LeagueFeed(
      url: 'https://news.google.com/rss/search?q=%22Serie+A%22&hl=en-US&gl=US&ceid=US:en',
      outlet: 'Google News',
      publisherId: 'google-news',
      wordmark: 'NEWS',
      website: 'https://news.google.com/',
    ),
    'bundesliga': _LeagueFeed(
      url: 'https://news.google.com/rss/search?q=Bundesliga&hl=en-US&gl=US&ceid=US:en',
      outlet: 'Google News',
      publisherId: 'google-news',
      wordmark: 'NEWS',
      website: 'https://news.google.com/',
    ),
    'ligue-1': _LeagueFeed(
      url: 'https://news.google.com/rss/search?q=%22Ligue+1%22&hl=en-US&gl=US&ceid=US:en',
      outlet: 'Google News',
      publisherId: 'google-news',
      wordmark: 'NEWS',
      website: 'https://news.google.com/',
    ),
    'european-leagues': _LeagueFeed(
      url: 'https://news.google.com/rss/search?q=%22European+Leagues%22&hl=en-US&gl=US&ceid=US:en',
      outlet: 'Google News',
      publisherId: 'google-news',
      wordmark: 'NEWS',
      website: 'https://news.google.com/',
    ),
    'f1': _LeagueFeed(
      url: 'https://news.google.com/rss/search?q=%22Formula+1%22&hl=en-US&gl=US&ceid=US:en',
      outlet: 'Google News',
      publisherId: 'google-news',
      wordmark: 'NEWS',
      website: 'https://news.google.com/',
    ),
    'tennis': _LeagueFeed(
      url: 'https://news.google.com/rss/search?q=tennis&hl=en-US&gl=US&ceid=US:en',
      outlet: 'Google News',
      publisherId: 'google-news',
      wordmark: 'NEWS',
      website: 'https://news.google.com/',
    ),
    'cricket': _LeagueFeed(
      url: 'https://news.google.com/rss/search?q=cricket&hl=en-US&gl=US&ceid=US:en',
      outlet: 'Google News',
      publisherId: 'google-news',
      wordmark: 'NEWS',
      website: 'https://news.google.com/',
    ),
    'golf': _LeagueFeed(
      url:
          'https://news.google.com/rss/search?q=golf&hl=en-US&gl=US&ceid=US:en',
      outlet: 'Google News',
      publisherId: 'google-news',
      wordmark: 'NEWS',
      website: 'https://news.google.com/',
    ),
  };

  static bool supports(String leagueId) =>
      _feeds.containsKey(leagueId.split(':').last.toLowerCase());

  /// Drops session caches so pull-to-refresh can retry a failed league feed.
  void clearCache() => _cache.clear();

  static const List<String> _europeanLeagueSlugs = <String>[
    'la-liga',
    'serie-a',
    'bundesliga',
    'ligue-1',
  ];

  Future<List<Article>> fetch(String leagueId, {int limit = 6}) async {
    final String slug = leagueId.split(':').last.toLowerCase();
    if (slug == 'european-leagues') {
      return _fetchEuropeanLeagues(limit: limit);
    }
    final _LeagueFeed? feed = _feeds[slug];
    if (feed == null) return const <Article>[];
    final List<Article>? cached = _cache[slug];
    if (cached != null) return cached;

    final FeedSourceConfig config = FeedSourceConfig(
      id: 'league-${feed.publisherId}-$slug',
      outlet: feed.outlet,
      publisherId: feed.publisherId,
      wordmark: feed.wordmark,
      url: feed.url,
      kind: FeedSourceKind.rss,
      categoryId: 'sports',
      websiteUrl: feed.website,
      summaryOnly: true,
    );
    try {
      final String document = await client.getText(feed.url);
      final List<Article> parsed = RssParser.parse(
        document,
        config: config,
        limit: 16,
      );
      // The endpoint is league-scoped; take its stories as they come.
      final List<Article> result = List<Article>.unmodifiable(
        parsed.take(limit),
      );
      _cache[slug] = result;
      return result;
    } catch (error) {
      AppLog.debug('LeagueNewsSource($slug): $error');
      return const <Article>[];
    }
  }

  Future<List<Article>> _fetchEuropeanLeagues({required int limit}) async {
    final List<Article>? cached = _cache['european-leagues'];
    if (cached != null) return cached;

    final List<FeedSourceConfig> configs = <FeedSourceConfig>[
      for (final String slug in _europeanLeagueSlugs)
        FeedSourceConfig(
          id: 'league-google-news-$slug',
          outlet: _feeds[slug]!.outlet,
          publisherId: _feeds[slug]!.publisherId,
          wordmark: _feeds[slug]!.wordmark,
          url: _feeds[slug]!.url,
          kind: FeedSourceKind.rss,
          categoryId: 'sports',
          websiteUrl: _feeds[slug]!.website,
          summaryOnly: true,
        ),
    ];

    final List<List<Article>> batches = await Future.wait(
      <Future<List<Article>>>[
        for (int i = 0; i < _europeanLeagueSlugs.length; i++)
          _fetchOne(_europeanLeagueSlugs[i], configs[i]),
      ],
    );
    final Map<String, Article> byId = <String, Article>{};
    for (final List<Article> batch in batches) {
      for (final Article article in batch) {
        byId[article.id] = article;
      }
    }
    final List<Article> combined = byId.values.toList(growable: false)
      ..sort((Article a, Article b) => b.publishedAt.compareTo(a.publishedAt));
    final List<Article> result = List<Article>.unmodifiable(
      combined.take(limit).toList(growable: false),
    );
    _cache['european-leagues'] = result;
    return result;
  }

  Future<List<Article>> _fetchOne(String slug, FeedSourceConfig config) async {
    try {
      final _LeagueFeed feed = _feeds[slug]!;
      final String document = await client.getText(feed.url);
      final List<Article> parsed = RssParser.parse(
        document,
        config: config,
        limit: 16,
      );
      return parsed.take(16).toList(growable: false);
    } catch (error) {
      AppLog.debug('LeagueNewsSource($slug, combined): $error');
      return const <Article>[];
    }
  }
}

class _LeagueFeed {
  const _LeagueFeed({
    required this.url,
    required this.outlet,
    required this.publisherId,
    required this.wordmark,
    required this.website,
  });

  final String url;
  final String outlet;
  final String publisherId;
  final String wordmark;
  final String website;
}

/// True for stories that must open on the publisher, not in the local reader.
bool isExternalSportsArticle(Article article) =>
    article.id.startsWith('espn:') ||
    article.publisher.id == 'yahoo-sports' ||
    article.publisher.id == 'google-news';
