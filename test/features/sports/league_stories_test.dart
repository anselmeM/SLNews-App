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

  test('assigns stories for the expanded major-league catalogue', () {
    final stories = <Article>[
      article('Champions League final draw', summary: 'UCL last eight'),
      article('La Liga title race tightens'),
      article('Serie A leaders drop points'),
      article('Bundesliga matchday review'),
      article('Ligue 1 round-up'),
      article('Verstappen wins Las Vegas Grand Prix', summary: 'F1'),
      article('Wimbledon champion returns', summary: 'Tennis'),
      article('Ashes test ends in a draw', summary: 'Cricket'),
      article('Ryder Cup captain named', summary: 'Golf'),
    ];

    expect(
      LeagueStories.forLeague('UEFA Champions League', stories).single.title,
      'Champions League final draw',
    );
    expect(
      LeagueStories.forLeague('La Liga', stories).single.title,
      'La Liga title race tightens',
    );
    expect(
      LeagueStories.forLeague('Serie A', stories).single.title,
      'Serie A leaders drop points',
    );
    expect(
      LeagueStories.forLeague('Bundesliga', stories).single.title,
      'Bundesliga matchday review',
    );
    expect(
      LeagueStories.forLeague('Ligue 1', stories).single.title,
      'Ligue 1 round-up',
    );
    expect(
      LeagueStories.forLeague('Formula 1', stories).single.title,
      'Verstappen wins Las Vegas Grand Prix',
    );
    expect(
      LeagueStories.forLeague('Tennis', stories).single.title,
      'Wimbledon champion returns',
    );
    expect(
      LeagueStories.forLeague('Cricket', stories).single.title,
      'Ashes test ends in a draw',
    );
    expect(
      LeagueStories.forLeague('Golf', stories).single.title,
      'Ryder Cup captain named',
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
