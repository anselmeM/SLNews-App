import 'package:flutter/foundation.dart';

import '../../utils/time_ago.dart';

/// Lifecycle of a fixture.
enum GameStatus {
  scheduled,
  live,
  finalScore,
  postponed;

  static GameStatus fromWire(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'live':
      case 'in_progress':
        return GameStatus.live;
      case 'final':
      case 'finished':
        return GameStatus.finalScore;
      case 'postponed':
      case 'cancelled':
        return GameStatus.postponed;
      default:
        return GameStatus.scheduled;
    }
  }

  String get wireValue => switch (this) {
    GameStatus.scheduled => 'scheduled',
    GameStatus.live => 'live',
    GameStatus.finalScore => 'final',
    GameStatus.postponed => 'postponed',
  };
}

/// A club, national side or franchise.
@immutable
class Team {
  const Team({
    required this.id,
    required this.name,
    required this.code,
    this.logoUrl,
    this.colourHex = '#000000',
  });

  final String id;
  final String name;

  /// Three letter code shown next to the crest, e.g. "LAL".
  final String code;
  final String? logoUrl;
  final String colourHex;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'code': code,
    'logoUrl': logoUrl,
    'colourHex': colourHex,
  };

  factory Team.fromJson(Map<String, dynamic> json) => Team(
    id: json['id'] as String,
    name: json['name'] as String,
    code: json['code'] as String,
    logoUrl: json['logoUrl'] as String?,
    colourHex: json['colourHex'] as String? ?? '#000000',
  );

  @override
  bool operator ==(Object other) =>
      other is Team && other.id == id && other.code == code;

  @override
  int get hashCode => Object.hash(id, code);
}

/// One row in the live scoreboard widget.
@immutable
class GameScore {
  const GameScore({
    required this.id,
    required this.leagueLabel,
    required this.away,
    required this.home,
    required this.status,
    this.awayScore,
    this.homeScore,
    this.startsAt,
    this.periodLabel,
    this.venue,
  });

  final String id;

  /// Competition label drawn above the fixture, e.g. "NBA", "Sierra Leone Premier League".
  final String leagueLabel;

  final Team away;
  final Team home;
  final GameStatus status;
  final int? awayScore;
  final int? homeScore;
  final DateTime? startsAt;

  /// "Q3 04:12", "72'", "3rd set" — only for live fixtures.
  final String? periodLabel;

  final String? venue;

  bool get hasScores => awayScore != null && homeScore != null;

  /// "FINAL" / "10:30PM" / "LIVE" label used by the score card.
  String get statusLabel => switch (status) {
    GameStatus.finalScore => 'FINAL',
    GameStatus.live => periodLabel ?? 'LIVE',
    GameStatus.postponed => 'POSTPONED',
    GameStatus.scheduled => startsAt?.clockLabel ?? 'TBC',
  };

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'leagueLabel': leagueLabel,
    'away': away.toJson(),
    'home': home.toJson(),
    'status': status.wireValue,
    'awayScore': awayScore,
    'homeScore': homeScore,
    'startsAt': startsAt?.toIso8601String(),
    'periodLabel': periodLabel,
    'venue': venue,
  };

  factory GameScore.fromJson(Map<String, dynamic> json) => GameScore(
    id: json['id'] as String,
    leagueLabel: json['leagueLabel'] as String,
    away: Team.fromJson(json['away'] as Map<String, dynamic>),
    home: Team.fromJson(json['home'] as Map<String, dynamic>),
    status: GameStatus.fromWire(json['status'] as String?),
    awayScore: (json['awayScore'] as num?)?.toInt(),
    homeScore: (json['homeScore'] as num?)?.toInt(),
    startsAt: json['startsAt'] == null
        ? null
        : DateTime.parse(json['startsAt'] as String),
    periodLabel: json['periodLabel'] as String?,
    venue: json['venue'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is GameScore &&
      other.id == id &&
      other.status == status &&
      other.awayScore == awayScore &&
      other.homeScore == homeScore;

  @override
  int get hashCode => Object.hash(id, status, awayScore, homeScore);
}

/// Payload of the Sports tab's scoreboard strip.
@immutable
class ScoreboardSnapshot {
  const ScoreboardSnapshot({
    required this.games,
    required this.providerLabel,
    required this.updatedAt,
  });

  final List<GameScore> games;

  /// Attribution rendered under the strip, e.g. "Powered by yahoo/sports".
  final String providerLabel;

  final DateTime updatedAt;

  bool get isEmpty => games.isEmpty;
}

/// Standings row used by the "Following" sports section.
@immutable
class TeamStanding {
  const TeamStanding({
    required this.team,
    required this.leagueId,
    required this.leagueLabel,
    required this.record,
    required this.rank,
  });

  final Team team;

  /// Slug of the league, e.g. `spl` for the Sierra Leone Premier League.
  final String leagueId;

  final String leagueLabel;
  final String record;
  final int rank;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'team': team.toJson(),
    'leagueId': leagueId,
    'leagueLabel': leagueLabel,
    'record': record,
    'rank': rank,
  };

  factory TeamStanding.fromJson(Map<String, dynamic> json) => TeamStanding(
    team: Team.fromJson(json['team'] as Map<String, dynamic>),
    leagueId: json['leagueId'] as String? ?? 'spl',
    leagueLabel: json['leagueLabel'] as String,
    record: json['record'] as String,
    rank: (json['rank'] as num).toInt(),
  );
}
