import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/sources/the_sports_db_source.dart';
import 'package:slnews_mobile/core/domain/models/sports_models.dart';

const Map<String, dynamic> past = <String, dynamic>{
  'events': <Map<String, dynamic>>[
    <String, dynamic>{
      'idEvent': '1',
      'strHomeTeam': 'Los Angeles Lakers',
      'strAwayTeam': 'Denver Nuggets',
      'idHomeTeam': '134860',
      'idAwayTeam': '134867',
      'intHomeScore': '112',
      'intAwayScore': '104',
      'strStatus': 'FT',
      'dateEvent': '2026-10-22',
      'strTime': '02:30:00',
      'strVenue': 'Crypto.com Arena',
    },
  ],
};

const Map<String, dynamic> table = <String, dynamic>{
  'table': <Map<String, dynamic>>[
    <String, dynamic>{
      'intRank': '1',
      'strTeam': 'Los Angeles Lakers',
      'idTeam': '134860',
      'intWin': '5',
      'intLoss': '1',
    },
    <String, dynamic>{
      'intRank': '2',
      'strTeam': 'Denver Nuggets',
      'idTeam': '134867',
      'intWin': '4',
      'intLoss': '2',
    },
  ],
};

void main() {
  test('maps TheSportsDB events into a finished GameScore', () async {
    final source = TheSportsDbSource.forFetcher((String url) async {
      if (url.contains('eventspastleague')) return past;
      return <String, dynamic>{'events': null};
    });
    final List<GameScore> games = await source.games(
      TheSportsDbSource.leagues.first,
    );
    expect(games, hasLength(1));
    final GameScore game = games.single;
    expect(game.home.name, 'Los Angeles Lakers');
    expect(game.away.name, 'Denver Nuggets');
    expect(game.homeScore, 112);
    expect(game.awayScore, 104);
    expect(game.status, GameStatus.finalScore);
    expect(game.leagueLabel, 'NBA');
    expect(game.venue, 'Crypto.com Arena');
  });

  test('maps a league table with records', () async {
    final source = TheSportsDbSource.forFetcher((String url) async => table);
    final List<TeamStanding> rows = await source.table(
      TheSportsDbSource.leagues.first,
    );
    expect(rows, hasLength(2));
    expect(rows.first.rank, 1);
    expect(rows.first.team.name, 'Los Angeles Lakers');
    expect(rows.first.record, '5-1');
    expect(rows.first.leagueId, 'league:nba');
  });

  test('a failed request degrades to empty lists', () async {
    final source = TheSportsDbSource.forFetcher(
      (String url) async => throw StateError('offline'),
    );
    expect(await source.games(TheSportsDbSource.leagues.first), isEmpty);
    expect(await source.table(TheSportsDbSource.leagues.first), isEmpty);
  });
}
