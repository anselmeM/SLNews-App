import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/sports_models.dart';
import '../../domain/repositories/sports_repository.dart';
import '../seed/seed_data.dart';
import '../seed/seed_loader.dart';
import '../sources/api_client.dart';
import '../sources/espn_source.dart';
import '../sources/the_sports_db_source.dart';

/// Fixtures, scores and standings backed by the seed, with an optional live
/// scoreboard endpoint.
///
/// The seed always answers first, so the Sports tab renders immediately; a
/// configured [scoreboardUrl] then replaces the strip in the background when it
/// answers with usable games.
class DefaultSportsRepository implements SportsRepository {
  /// Creates a repository over [seedLoader], optionally polling [scoreboardUrl].
  DefaultSportsRepository({
    required SeedLoader seedLoader,
    ApiClient? client,
    String? scoreboardUrl,
    TheSportsDbSource? liveSource,
    this.espn,
  }) : _seeds = seedLoader,
       _api = client,
       _endpoint = scoreboardUrl,
       _live = liveSource {
    unawaited(_ready);
  }

  final SeedLoader _seeds;
  final ApiClient? _api;
  final String? _endpoint;
  final TheSportsDbSource? _live;
  final EspnSource? espn;
  Future<void>? _liveRefresh;
  DateTime? _liveFetchedAt;
  static const Duration _liveTtl = Duration(minutes: 5);
  final Map<String, List<TeamStanding>> _liveTables =
      <String, List<TeamStanding>>{};

  ScoreboardSnapshot _scoreboard = ScoreboardSnapshot(
    games: const <GameScore>[],
    providerLabel: 'slnews',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
  List<TeamStanding> _standings = const <TeamStanding>[];

  late final Future<void> _ready = _hydrate();

  /// Resolves once the seeded fixtures are loaded.
  Future<void> ready() => _ready;

  @override
  Future<ScoreboardSnapshot> scoreboard({int limit = 8}) async {
    await _ready;
    // Seed paints immediately; wait briefly for live scores rather than block
    // the tab on a slow third party.
    await _ensureLive().timeout(const Duration(seconds: 6), onTimeout: () {});
    final List<GameScore> games = _sorted(_scoreboard.games);
    return ScoreboardSnapshot(
      games: games.length > limit ? games.sublist(0, limit) : games,
      providerLabel: _scoreboard.providerLabel,
      updatedAt: _scoreboard.updatedAt,
    );
  }

  @override
  Future<List<GameScore>> gamesForTeam(String teamId, {int limit = 10}) async {
    await _ready;
    final List<GameScore> matches = <GameScore>[
      for (final GameScore game in _sorted(_scoreboard.games))
        if (_isTeam(game.away, teamId) || _isTeam(game.home, teamId)) game,
    ];
    return matches.length > limit ? matches.sublist(0, limit) : matches;
  }

  @override
  Future<List<TeamStanding>> standings(String leagueId) async {
    await _ready;
    final EspnSource? source = espn;
    // Keep tests and key-less builds fully offline.
    if (const bool.fromEnvironment('THESPORTSDB_ENABLED') &&
        source != null &&
        EspnSource.supportsLeagueId(leagueId)) {
      try {
        final List<TeamStanding> liveTable = await source.standings(leagueId);
        if (liveTable.isNotEmpty) return liveTable;
      } catch (error) {
        debugPrint(
          'DefaultSportsRepository: ESPN standings unavailable: $error',
        );
      }
    }
    // Seed paints immediately; wait briefly for live scores rather than block
    // the tab on a slow third party.
    await _ensureLive().timeout(const Duration(seconds: 6), onTimeout: () {});
    final String slug = leagueId.split(':').last.toLowerCase();
    final List<TeamStanding>? live = _liveTables[slug];
    if (live != null && live.isNotEmpty) return live;
    final List<TeamStanding> matches = <TeamStanding>[
      for (final TeamStanding row in _standings)
        if (row.leagueId.toLowerCase().split(':').last == slug) row,
    ];
    final List<TeamStanding> rows = matches.isEmpty
        ? List<TeamStanding>.of(_standings)
        : matches;
    rows.sort((TeamStanding a, TeamStanding b) => a.rank.compareTo(b.rank));
    return rows;
  }

  /// Fetches the live leagues once; concurrent callers share the same future.
  Future<void> _ensureLive() {
    final TheSportsDbSource? live = _live;
    if (live == null) return Future<void>.value();
    final DateTime? fetchedAt = _liveFetchedAt;
    final bool stale =
        fetchedAt == null || DateTime.now().difference(fetchedAt) > _liveTtl;
    if (!stale) return _liveRefresh ?? Future<void>.value();
    return _liveRefresh ??= _refreshLive(live).whenComplete(() {
      // Cache even a failed attempt: no hammering a struggling third party.
      _liveFetchedAt = DateTime.now();
    });
  }

  Future<void> _refreshLive(TheSportsDbSource live) async {
    final Map<String, List<GameScore>> liveGames = <String, List<GameScore>>{};
    await Future.wait(<Future<void>>[
      for (final SportsDbLeague league in TheSportsDbSource.leagues)
        () async {
          final List<GameScore> games = await live.games(league);
          if (games.isNotEmpty) liveGames[league.label] = games;
          if (league.hasTable) {
            final List<TeamStanding> table = await live.table(league);
            // The free key returns at most 5 rows and no NBA table at all. A
            // truncated table is worse than the cached seed, so only accept a
            // plausible full table.
            if (table.length >= 10) _liveTables[league.slug] = table;
          }
        }(),
    ]);
    if (liveGames.isEmpty) return;
    _scoreboard = ScoreboardSnapshot(
      games: <GameScore>[
        // Keep Sierra Leone fixtures from the seed; replace only the leagues
        // TheSportsDB actually answered for.
        for (final GameScore game in _scoreboard.games)
          if (!liveGames.containsKey(game.leagueLabel)) game,
        for (final List<GameScore> games in liveGames.values) ...games,
      ],
      providerLabel: 'thesportsdb',
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _hydrate() async {
    try {
      final SeedData seed = await _seeds.load();
      _scoreboard = seed.scoreboard;
      _standings = seed.standings;
    } catch (error) {
      debugPrint('DefaultSportsRepository: seed unavailable: $error');
    }
    final ApiClient? client = _api;
    final String? url = _endpoint;
    // Deliberately not awaited: a slow scoreboard must not delay the first frame.
    if (client != null && url != null && url.isNotEmpty) {
      unawaited(_refreshFromNetwork(client, url));
    }
  }

  Future<void> _refreshFromNetwork(ApiClient client, String url) async {
    try {
      final Object? payload = await client.getJson(url);
      final Object? node = payload is Map
          ? payload['games'] ??
                payload['items'] ??
                payload['data'] ??
                payload['events']
          : payload;
      if (node is! List) return;

      final List<GameScore> games = <GameScore>[];
      for (final Object? entry in node) {
        if (entry is! Map) continue;
        try {
          games.add(GameScore.fromJson(_stringKeyed(entry)));
        } catch (error) {
          debugPrint('DefaultSportsRepository: skipping wire game: $error');
        }
      }
      if (games.isEmpty) return;
      _scoreboard = ScoreboardSnapshot(
        games: games,
        providerLabel: _scoreboard.providerLabel,
        updatedAt: DateTime.now(),
      );
    } catch (error) {
      debugPrint('DefaultSportsRepository: scoreboard refresh failed: $error');
    }
  }

  static bool _isTeam(Team team, String teamId) {
    if (team.id == teamId) return true;
    final EspnTeamRef? espnTeam = EspnSource.teams[teamId];
    if (espnTeam != null) {
      final String live = team.name.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
      final String wanted = espnTeam.label.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
      if (live == wanted || live.contains(wanted) || wanted.contains(live)) {
        return true;
      }
    }
    final String seed = teamId.split(':').last.toLowerCase();
    if (team.id.split(':').last.toLowerCase() == seed) return true;

    // Live rows carry TheSportsDB ids, so a followed seed team (`team:lakers`)
    // would never match `team:thesportsdb-134860` by id. Fall back to name
    // tokens: every significant token of the seed slug must appear in the live
    // name ("man-city" -> "manchestercity").
    final String normalised = team.name.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    final List<String> tokens = seed
        .split(RegExp(r'[^a-z0-9]+'))
        .where((String token) => token.length >= 3)
        .toList();
    if (tokens.isEmpty) return false;
    return tokens.every(normalised.contains);
  }

  /// Live fixtures first, then upcoming, then results — which is how the strip
  /// reads best and keeps a live game from being pushed off screen.
  static List<GameScore> _sorted(List<GameScore> games) {
    final List<GameScore> sorted = List<GameScore>.of(games);
    sorted.sort((GameScore a, GameScore b) {
      final int byStatus = _statusRank(a.status)
          .compareTo(_statusRank(b.status));
      if (byStatus != 0) return byStatus;
      final DateTime? left = a.startsAt;
      final DateTime? right = b.startsAt;
      if (left == null || right == null) return 0;
      return a.status == GameStatus.finalScore
          ? right.compareTo(left)
          : left.compareTo(right);
    });
    return sorted;
  }

  static int _statusRank(GameStatus status) => switch (status) {
    GameStatus.live => 0,
    GameStatus.scheduled => 1,
    GameStatus.finalScore => 2,
    GameStatus.postponed => 3,
  };

  static Map<String, dynamic> _stringKeyed(Map<dynamic, dynamic> value) {
    final Map<String, dynamic> mapped = <String, dynamic>{};
    value.forEach((Object? key, Object? entry) {
      if (key is String) mapped[key] = entry;
    });
    return mapped;
  }
}
