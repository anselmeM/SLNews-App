import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/sources/league_news_source.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/publisher.dart';

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
