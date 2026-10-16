import '../models/sports_models.dart';

/// Fixtures, live scores and standings for the Sports tab.
abstract interface class SportsRepository {
  /// Scorecards for the live/recent strip, newest first.
  Future<ScoreboardSnapshot> scoreboard({int limit = 8});

  /// Fixtures involving a followed team (`team:leone-stars`, ...).
  Future<List<GameScore>> gamesForTeam(String teamId, {int limit = 10});

  /// Standings table for a league (`league:spl`, ...).
  Future<List<TeamStanding>> standings(String leagueId);
}
