import 'package:flutter/foundation.dart';

import '../../domain/models/article.dart';
import '../../../features/sports/domain/league_stories.dart';
import 'api_client.dart';
import 'feed_source.dart';
import 'rss_feed_source.dart';

/// League-specific news, never the generic sports feed.
///
/// US leagues use their Yahoo Sports RSS channel; competitions without a Yahoo
/// channel use a Google News query. Results are passed through [LeagueStories]
/// again, so even a broad query cannot leak an NBA story into the MLB block.
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
      label: 'NBA',
    ),
    'nfl': _LeagueFeed(
      url: 'https://sports.yahoo.com/nfl/rss.xml',
      outlet: 'Yahoo Sports',
      publisherId: 'yahoo-sports',
      wordmark: 'YAHOO',
      website: 'https://sports.yahoo.com/nfl/',
      label: 'NFL',
    ),
    'mlb': _LeagueFeed(
      url: 'https://sports.yahoo.com/mlb/rss.xml',
      outlet: 'Yahoo Sports',
      publisherId: 'yahoo-sports',
      wordmark: 'YAHOO',
      website: 'https://sports.yahoo.com/mlb/',
      label: 'MLB',
    ),
    'nhl': _LeagueFeed(
      url: 'https://sports.yahoo.com/nhl/rss.xml',
      outlet: 'Yahoo Sports',
      publisherId: 'yahoo-sports',
      wordmark: 'YAHOO',
      website: 'https://sports.yahoo.com/nhl/',
      label: 'NHL',
    ),
    'epl': _LeagueFeed(
      url: 'https://news.google.com/rss/search?q=%22Premier+League%22&hl=en-US&gl=US&ceid=US:en',
      outlet: 'Google News',
      publisherId: 'google-news',
      wordmark: 'NEWS',
      website: 'https://news.google.com/',
      label: 'Premier League',
    ),
    'spl': _LeagueFeed(
      url: 'https://news.google.com/rss/search?q=%22Sierra+Leone+Premier+League%22&hl=en-US&gl=US&ceid=US:en',
      outlet: 'Google News',
      publisherId: 'google-news',
      wordmark: 'NEWS',
      website: 'https://news.google.com/',
      label: 'Sierra Leone Premier League',
    ),
    'afcon': _LeagueFeed(
      url: 'https://news.google.com/rss/search?q=AFCON&hl=en-US&gl=US&ceid=US:en',
      outlet: 'Google News',
      publisherId: 'google-news',
      wordmark: 'NEWS',
      website: 'https://news.google.com/',
      label: 'AFCON',
    ),
  };

  static bool supports(String leagueId) =>
      _feeds.containsKey(leagueId.split(':').last.toLowerCase());

  Future<List<Article>> fetch(String leagueId, {int limit = 6}) async {
    final String slug = leagueId.split(':').last.toLowerCase();
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
      final List<Article> filtered = LeagueStories.forLeague(
        feed.label,
        parsed,
        limit: limit,
      );
      final List<Article> result = List<Article>.unmodifiable(filtered);
      _cache[slug] = result;
      return result;
    } catch (error) {
      debugPrint('LeagueNewsSource($slug): $error');
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
    required this.label,
  });

  final String url;
  final String outlet;
  final String publisherId;
  final String wordmark;
  final String website;
  final String label;
}

/// True for stories that must open on the publisher, not in the local reader.
bool isExternalSportsArticle(Article article) =>
    article.id.startsWith('espn:') ||
    article.publisher.id == 'yahoo-sports' ||
    article.publisher.id == 'google-news';
