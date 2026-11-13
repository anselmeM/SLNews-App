import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/publisher.dart';
import 'package:slnews_mobile/core/domain/models/sports_models.dart';
import 'package:slnews_mobile/features/sports/domain/league_stories.dart';

Article article(String title, {String summary = ''}) => Article(
  id: title,
  title: title,
  summary: summary,
  publisher: const Publisher(id: 'test', name: 'Test'),
  publishedAt: DateTime.utc(2026, 11, 12),
  categoryId: 'sports',
);

const Team bills = Team(id: 'bills', name: 'Buffalo Bills', code: 'BUF');
const Team niners = Team(id: 'sf', name: 'San Francisco 49ers', code: 'SF');
const GameScore nflGame = GameScore(
  id: 'g1',
  leagueLabel: 'NFL',
  away: bills,
  home: niners,
  status: GameStatus.finalScore,
  awayScore: 24,
  homeScore: 20,
);

void main() {
  test('only assigns matching league stories', () {
    final stories = <Article>[
      article('Lakers rally past Celtics', summary: 'NBA thriller'),
      article('Bills edge 49ers in overtime', summary: 'NFL result'),
      article('Yankees sign new pitcher', summary: 'MLB move'),
      article('Leone Stars draw with Guinea', summary: 'AFCON qualifier'),
    ];
    expect(
      LeagueStories.forLeague('NBA', stories).map((a) => a.title),
      <String>['Lakers rally past Celtics'],
    );
    final nfl = LeagueStories.forLeague(
      'NFL',
      stories,
      games: <GameScore>[nflGame],
    );
    expect(nfl.map((a) => a.title), <String>['Bills edge 49ers in overtime']);
    expect(
      LeagueStories.forLeague('MLB', stories).map((a) => a.title),
      <String>['Yankees sign new pitcher'],
    );
    expect(
      LeagueStories.forLeague(
        'Sierra Leone Premier League',
        stories,
      ).map((a) => a.title),
      <String>['Leone Stars draw with Guinea'],
    );
  });

  test('returns nothing when no story clearly matches', () {
    final stories = <Article>[article('Weather improves across Freetown')];
    expect(
      LeagueStories.forLeague('NFL', stories, games: <GameScore>[nflGame]),
      isEmpty,
    );
    expect(LeagueStories.forLeague('MLB', stories), isEmpty);
    expect(LeagueStories.forLeague('NBA', stories), isEmpty);
  });
}
