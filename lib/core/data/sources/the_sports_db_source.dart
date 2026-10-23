import 'package:flutter/foundation.dart';

import 'dart:math' as math;

import '../../domain/models/sports_models.dart';
import 'api_client.dart';

/// A league TheSportsDB can supply scores and standings for.
class SportsDbLeague {
  const SportsDbLeague({
    required this.dbId,
    required this.slug,
    required this.label,
    required this.season,
    this.hasTable = false,
  });

  /// TheSportsDB league id (e.g. 4387 for the NBA).
  final String dbId;

  /// App league slug, matching `SportsLinks` ids (`nba`, `epl`, ...).
  final String slug;

  final String label;

  /// Season string TheSportsDB expects, e.g. `2026-2027`.
  final String season;

  /// True when the league exposes `lookuptable.php` standings.
  final bool hasTable;
}

/// Live scores, fixtures and standings from TheSportsDB (v1 free key).
///
/// News is deliberately not sourced here: TheSportsDB has no articles. This
/// only replaces the stale seed for the scoreboard and league tables; RSS stays
/// responsible for sports journalism.
class TheSportsDbSource {
  TheSportsDbSource({required ApiClient client, String? baseUrl, String? key})
    : _api = client,
      _base =
          (baseUrl ??
                  const String.fromEnvironment(
                    'THESPORTSDB_BASE',
                    defaultValue: 'https://www.thesportsdb.com/api/v1/json',
                  ))
              .replaceAll(RegExp(r'/+$'), ''),
      _key =
          key ??
          const String.fromEnvironment('THESPORTSDB_KEY', defaultValue: '123'),
      _fetch = null;

  /// Test seam: no HTTP client, no env.
  @visibleForTesting
  TheSportsDbSource.forFetcher(Future<Object?> Function(String url) fetch)
    : _api = null,
      _base = '',
      _key = '',
      _fetch = fetch;

  final ApiClient? _api;
  final String _base;
  final String _key;
  final Future<Object?> Function(String url)? _fetch;

  static const List<SportsDbLeague> leagues = <SportsDbLeague>[
    SportsDbLeague(
      dbId: '4387',
      slug: 'nba',
      label: 'NBA',
      season: '2026-2027',
      hasTable: true,
    ),
    SportsDbLeague(
      dbId: '4328',
      slug: 'epl',
      label: 'Premier League',
      season: '2026-2027',
      hasTable: true,
    ),
    SportsDbLeague(dbId: '4391', slug: 'nfl', label: 'NFL', season: '2026'),
    SportsDbLeague(
      dbId: '4380',
      slug: 'nhl',
      label: 'NHL',
      season: '2026-2027',
    ),
    SportsDbLeague(dbId: '4424', slug: 'mlb', label: 'MLB', season: '2026'),
  ];

  /// Last results and next fixtures for a league, newest first.
  Future<List<GameScore>> games(SportsDbLeague league) async {
    final List<GameScore> games = <GameScore>[];
    for (final String path in <String>[
      'eventspastleague.php?id=${league.dbId}',
      'eventsnextleague.php?id=${league.dbId}',
    ]) {
      final Object? payload = await _getJson(path);
      final Object? rows = payload is Map ? payload['events'] : null;
      if (rows is! List) continue;
      for (final Object? row in rows) {
        if (row is! Map) continue;
        final GameScore? game = _toGame(row.cast<String, dynamic>(), league);
        if (game != null) games.add(game);
      }
    }
    return games;
  }

  /// League table for a league, or an empty list when unavailable.
  Future<List<TeamStanding>> table(SportsDbLeague league) async {
    if (!league.hasTable) return const <TeamStanding>[];
    final Object? payload = await _getJson(
      'lookuptable.php?l=${league.dbId}&s=${league.season}',
    );
    final Object? rows = payload is Map ? payload['table'] : null;
    if (rows is! List) return const <TeamStanding>[];
    final List<TeamStanding> table = <TeamStanding>[];
    for (final Object? row in rows) {
      if (row is! Map) continue;
      final Map<String, dynamic> data = row.cast<String, dynamic>();
      final int rank = _int(data['intRank']) ?? 0;
      final String name = _text(data['strTeam']);
      if (rank <= 0 || name.isEmpty) continue;
      final int? win = _int(data['intWin']);
      final int? draw = _int(data['intDraw']);
      final int? loss = _int(data['intLoss']);
      final String record = draw != null
          ? '${win ?? 0}-$draw-${loss ?? 0}'
          : '${win ?? 0}-${loss ?? 0}';
      table.add(
        TeamStanding(
          team: Team(
            id: 'team:thesportsdb-${data['idTeam'] ?? name}',
            name: name,
            code: _initials(name),
            logoUrl: _textOrNull(data['strTeamBadge']),
            colourHex: '#0B6FD1',
          ),
          leagueId: 'league:${league.slug}',
          leagueLabel: league.label,
          record: record,
          rank: rank,
        ),
      );
    }
    table.sort((TeamStanding a, TeamStanding b) => a.rank.compareTo(b.rank));
    return table;
  }

  Future<Object?> _getJson(String path) async {
    final String url = '$_base/$_key/$path';
    try {
      final Future<Object?> Function(String url)? fetch = _fetch;
      final ApiClient? api = _api;
      if (fetch != null) {
        return await fetch(url).timeout(const Duration(seconds: 3));
      }
      if (api == null) return null;
      return await api.getJson(url).timeout(const Duration(seconds: 3));
    } catch (_) {
      return null;
    }
  }

  GameScore? _toGame(Map<String, dynamic> data, SportsDbLeague league) {
    final String home = _text(data['strHomeTeam']);
    final String away = _text(data['strAwayTeam']);
    final String id = _text(data['idEvent']);
    if (home.isEmpty || away.isEmpty || id.isEmpty) return null;

    final String status = _text(data['strStatus']).toLowerCase();
    final String progress = _text(data['strProgress']);
    final bool finished = status.contains('ft') || status.contains('finished');
    final bool live =
        !finished &&
        (status.contains('1h') ||
            status.contains('2h') ||
            status.contains('live') ||
            status.contains('halftime') ||
            status.contains('q') ||
            progress.isNotEmpty);
    final DateTime? startsAt = DateTime.tryParse(
      '${_text(data['dateEvent'])}T${_text(data['strTime'])}Z',
    );

    return GameScore(
      id: 'thesportsdb:$id',
      leagueLabel: league.label,
      away: Team(
        id: 'team:thesportsdb-${data['idAwayTeam'] ?? away}',
        name: away,
        code: _initials(away),
        logoUrl: _textOrNull(data['strAwayTeamBadge']),
        colourHex: '#C8102E',
      ),
      home: Team(
        id: 'team:thesportsdb-${data['idHomeTeam'] ?? home}',
        name: home,
        code: _initials(home),
        logoUrl: _textOrNull(data['strHomeTeamBadge']),
        colourHex: '#1E7A3C',
      ),
      status: finished
          ? GameStatus.finalScore
          : live
          ? GameStatus.live
          : GameStatus.scheduled,
      awayScore: _int(data['intAwayScore']),
      homeScore: _int(data['intHomeScore']),
      startsAt: startsAt,
      periodLabel: progress.isEmpty ? null : progress,
      venue: _textOrNull(data['strVenue']),
    );
  }

  static String _text(Object? value) => value is String ? value.trim() : '';

  static String? _textOrNull(Object? value) {
    final String text = _text(value);
    return text.isEmpty ? null : text;
  }

  static int? _int(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String _initials(String name) {
    final List<String> words = name
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first
          .substring(0, math.min(3, words.first.length))
          .toUpperCase();
    }
    return words.take(3).map((String w) => w[0]).join().toUpperCase();
  }
}
