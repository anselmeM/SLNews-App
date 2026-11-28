import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/sources/api_client.dart';
import 'package:slnews_mobile/core/data/sources/league_news_source.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/publisher.dart';

import '../../data/fakes.dart';

void main() {
  test('league feeds are mapped only for known competitions', () {
    expect(LeagueNewsSource.supports('league:nba'), isTrue);
    expect(LeagueNewsSource.supports('nfl'), isTrue);
    expect(LeagueNewsSource.supports('mlb'), isTrue);
    expect(LeagueNewsSource.supports('nhl'), isTrue);
    expect(LeagueNewsSource.supports('league:epl'), isTrue);
    expect(LeagueNewsSource.supports('league:spl'), isTrue);
    expect(LeagueNewsSource.supports('league:afcon'), isTrue);
    expect(LeagueNewsSource.supports('league:champions-league'), isTrue);
    expect(LeagueNewsSource.supports('league:european-leagues'), isTrue);
    expect(LeagueNewsSource.supports('league:la-liga'), isTrue);
    expect(LeagueNewsSource.supports('league:serie-a'), isTrue);
    expect(LeagueNewsSource.supports('league:bundesliga'), isTrue);
    expect(LeagueNewsSource.supports('league:ligue-1'), isTrue);
    expect(LeagueNewsSource.supports('league:f1'), isTrue);
    expect(LeagueNewsSource.supports('league:tennis'), isTrue);
    expect(LeagueNewsSource.supports('league:cricket'), isTrue);
    expect(LeagueNewsSource.supports('league:golf'), isTrue);
    expect(LeagueNewsSource.supports('league:unknown'), isFalse);
  });

  group('league feed parsing', () {
    const String rss = '''<?xml version="1.0"?>
<rss version="2.0"><channel><title>Yahoo NBA</title>
<item><title>Lakers win again</title><link>https://sports.yahoo.com/nba/lakers-win</link>
<pubDate>Tue, 24 Nov 2026 10:00:00 +0000</pubDate><description>NBA round-up.</description></item>
</channel></rss>''';

    ResponseBody xmlBody(String body) => ResponseBody.fromString(
      body,
      200,
      headers: <String, List<String>>{
        'content-type': <String>['application/rss+xml; charset=utf-8'],
      },
    );

    test('fetches, tags and caches one league feed', () async {
      final fake = dioWith((RequestOptions options) async => xmlBody(rss));
      final LeagueNewsSource source = LeagueNewsSource(
        client: ApiClient(dio: fake.dio),
      );

      final List<Article> first = await source.fetch('league:nba', limit: 1);
      final List<Article> second = await source.fetch('league:nba', limit: 1);

      expect(first, hasLength(1));
      expect(first.single.tags, contains('league:nba'));
      expect(first.single.previewOnly, isTrue);
      expect(second, same(first));
      expect(fake.adapter.requests, hasLength(1));

      source.clearCache();
      await source.fetch('league:nba', limit: 1);
      expect(fake.adapter.requests, hasLength(2));
    });

    test('combined European feed fetches each competition', () async {
      final fake = dioWith((RequestOptions options) async {
        final String label = options.uri.query.contains('European')
            ? 'european'
            : options.uri.query.contains('La+Liga')
            ? 'laliga'
            : options.uri.query.contains('Serie')
            ? 'seriea'
            : options.uri.query.contains('Bundesliga')
            ? 'bundesliga'
            : 'ligue1';
        return xmlBody(
          '''<?xml version="1.0"?><rss version="2.0"><channel><title>$label</title>
<item><title>$label story</title><link>https://example.com/$label</link>
<pubDate>Tue, 24 Nov 2026 10:00:00 +0000</pubDate><description>$label.</description></item>
</channel></rss>''',
        );
      });
      final LeagueNewsSource source = LeagueNewsSource(
        client: ApiClient(dio: fake.dio),
      );

      final List<Article> stories = await source.fetch(
        'league:european-leagues',
        limit: 4,
      );

      expect(fake.adapter.requests, hasLength(4));
      expect(stories, hasLength(4));
      expect(
        stories.every(
          (Article article) =>
              article.tags.any((String tag) => tag.startsWith('league:')),
        ),
        isTrue,
      );
    });

    test('failed league requests return empty instead of throwing', () async {
      final fake = dioWith(
        (RequestOptions options) async => throw StateError('offline'),
      );
      final LeagueNewsSource source = LeagueNewsSource(
        client: ApiClient(dio: fake.dio),
      );

      expect(await source.fetch('league:nba'), isEmpty);
      expect(await source.fetch('league:european-leagues'), isEmpty);
    });
  });

  test('feed stories open externally', () {
    Article story(Publisher publisher) => Article(
      id: 'x',
      title: 'x',
      publisher: publisher,
      publishedAt: DateTime.utc(2026, 11, 12),
      categoryId: 'sports',
    );
    expect(
      isExternalSportsArticle(
        story(const Publisher(id: 'yahoo-sports', name: 'Yahoo Sports')),
      ),
      isTrue,
    );
    expect(
      isExternalSportsArticle(
        story(const Publisher(id: 'google-news', name: 'Google News')),
      ),
      isTrue,
    );
    expect(
      isExternalSportsArticle(
        story(const Publisher(id: 'awoko', name: 'Awoko')),
      ),
      isFalse,
    );
  });
}
