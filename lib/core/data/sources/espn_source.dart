import 'package:flutter/foundation.dart';

import '../../domain/models/article.dart';
import '../../domain/models/publisher.dart';
import '../../domain/models/sports_models.dart';
import 'api_client.dart';

import 'package:slnews_mobile/core/utils/app_log.dart';

/// Live team news and league tables from ESPN's public JSON endpoints.
///
/// The seed catalogue only knows a handful of clubs; ESPN fills the gap for the
/// ones it covers (starting with the Lakers) without adding a backend key. Every
/// method is best-effort: an empty list means "no live data", never a crash.
@immutable
class EspnTeamRef {
  const EspnTeamRef({
    required this.sport,
    required this.league,
    required this.teamId,
    required this.label,
  });

  final String sport;
  final String league;
  final String teamId;
  final String label;
}

@immutable
class EspnLeagueRef {
  const EspnLeagueRef({
    required this.sport,
    required this.league,
    required this.label,
  });

  final String sport;
  final String league;
  final String label;
}

class EspnSource {
  EspnSource({required this.client, this.timeout = const Duration(seconds: 8)});

  final ApiClient client;
  final Duration timeout;
  final Map<String, List<TeamStanding>> _standingsCache =
      <String, List<TeamStanding>>{};

  static const String _base = 'https://site.api.espn.com/apis';

  /// Teams in the bundled follow catalogue that ESPN can serve news for.
  static const Map<String, EspnTeamRef> teams = <String, EspnTeamRef>{
    'team:lal': EspnTeamRef(
      sport: 'basketball',
      league: 'nba',
      teamId: '13',
      label: 'Los Angeles Lakers',
    ),
  };

  static const Map<String, EspnLeagueRef> leagues = <String, EspnLeagueRef>{
    'nba': EspnLeagueRef(sport: 'basketball', league: 'nba', label: 'NBA'),
    'epl': EspnLeagueRef(
      sport: 'soccer',
      league: 'eng.1',
      label: 'Premier League',
    ),
    'nfl': EspnLeagueRef(sport: 'football', league: 'nfl', label: 'NFL'),
    'nhl': EspnLeagueRef(sport: 'hockey', league: 'nhl', label: 'NHL'),
    'mlb': EspnLeagueRef(sport: 'baseball', league: 'mlb', label: 'MLB'),
  };

  /// Team refs discovered from standings. Keyed by `team:espn-<numeric id>` so
  /// a followed standings team can resolve its sport/league on later launches.
  static final Map<String, EspnTeamRef> _discoveredTeams =
      <String, EspnTeamRef>{};

  static bool supportsTeamId(String teamId) => _refFor(teamId) != null;

  static EspnTeamRef? refForTeam(String teamId) => _refFor(teamId);

  /// League slug (e.g. `nba`) for a followed ESPN team, for standings.
  static String? leagueIdForTeam(String teamId) => _refFor(teamId)?.league;

  static EspnTeamRef? _refFor(String teamId) {
    final EspnTeamRef? direct = teams[teamId];
    if (direct != null) return direct;
    final EspnTeamRef? discovered = _discoveredTeams[teamId];
    if (discovered != null) return discovered;
    // `team:espn-13` is the standings form of the catalogue's `team:lal`.
    final RegExpMatch? numeric = RegExp(r'^team:espn-(\d+)$')
        .firstMatch(teamId);
    if (numeric == null) return null;
    final String espnId = numeric.group(1)!;
    for (final EspnTeamRef ref in teams.values) {
      if (ref.teamId == espnId) return ref;
    }
    return null;
  }

  /// Adds the standings alias to the known catalogue id when possible.
  static String? _catalogueIdForNumeric(String espnId) {
    for (final MapEntry<String, EspnTeamRef> entry in teams.entries) {
      if (entry.value.teamId == espnId) return entry.key;
    }
    return null;
  }

  static String leagueLabel(String slug) =>
      leagues[slug.toLowerCase()]?.label ?? slug.toUpperCase();

  static bool supportsLeagueId(String leagueId) =>
      leagues.containsKey(_leagueSlug(leagueId));

  static String _leagueSlug(String leagueId) =>
      leagueId.split(':').last.toLowerCase();

  Future<List<Article>> teamNews(String teamId, {int limit = 8}) async {
    final EspnTeamRef? ref = _refFor(teamId);
    if (ref == null) return const <Article>[];
    final Object? payload = await client.getJson(
      '$_base/site/v2/sports/${ref.sport}/${ref.league}/news',
      query: <String, dynamic>{'team': ref.teamId, 'limit': limit},
    );
    final Object? raw = payload is Map ? payload['articles'] : null;
    if (raw is! List) return const <Article>[];
    final List<Article> tagged = <Article>[];
    final List<Article> all = <Article>[];
    for (final Object? item in raw) {
      if (item is! Map) continue;
      final Map<String, dynamic> json = Map<String, dynamic>.from(item);
      try {
        final Article article = _articleFromJson(json);
        all.add(article);
        if (_mentionsTeam(json, ref.teamId)) tagged.add(article);
      } catch (error) {
        AppLog.debug('EspnSource: skipping malformed article: $error');
      }
    }
    final String leagueTag = 'league:${ref.league}';
    // `teamId` is the follow-catalogue id (`team:lal`), not ESPN's numeric id.
    final String followTeamTag = teamId;
    final List<Article> chosen = (tagged.isNotEmpty ? tagged : all)
        .take(limit)
        .map((Article article) {
          final Set<String> tags = <String>{...article.tags};
          tags
            ..add(leagueTag)
            ..add(followTeamTag);
          return article.copyWith(tags: List<String>.unmodifiable(tags));
        })
        .toList(growable: false);
    return List<Article>.unmodifiable(chosen);
  }

  Future<List<TeamStanding>> standings(
    String leagueId, {
    int limit = 20,
  }) async {
    final String slug = _leagueSlug(leagueId);
    final EspnLeagueRef? ref = leagues[slug];
    if (ref == null) return const <TeamStanding>[];
    final List<TeamStanding>? cached = _standingsCache[slug];
    if (cached != null) return cached;

    final Object? payload = await client.getJson(
      '$_base/v2/sports/${ref.sport}/${ref.league}/standings',
    );
    if (payload is! Map) return const <TeamStanding>[];

    final List<Map<String, dynamic>> entries = <Map<String, dynamic>>[];
    void collect(Object? node) {
      if (node is! Map) return;
      final Object? standings = node['standings'];
      if (standings is Map && standings['entries'] is List) {
        for (final Object? entry in standings['entries'] as List) {
          if (entry is Map) entries.add(Map<String, dynamic>.from(entry));
        }
      }
      final Object? children = node['children'];
      if (children is List) {
        for (final Object? child in children) {
          collect(child);
        }
      }
    }

    collect(payload);

    final List<TeamStanding> rows = <TeamStanding>[];
    final Set<String> seen = <String>{};
    for (final Map<String, dynamic> entry in entries) {
      final Object? team = entry['team'];
      if (team is! Map) continue;
      final String? id = team['id']?.toString();
      if (id == null || !seen.add(id)) continue;
      final String name =
          (team['displayName'] ?? team['name'] ?? team['shortDisplayName'])
              ?.toString() ??
          '';
      if (name.isEmpty) continue;
      final String code =
          (team['abbreviation'] ?? team['shortDisplayName'] ?? name)
              .toString()
              .toUpperCase();
      final Map<String, dynamic> stats = <String, dynamic>{};
      final Object? statList = entry['stats'];
      if (statList is List) {
        for (final Object? stat in statList) {
          if (stat is Map && stat['name'] is String) {
            stats[stat['name'] as String] = stat;
          }
        }
      }
      double number(String name) {
        final Object? stat = stats[name];
        final Object? value = stat is Map ? stat['value'] : null;
        return value is num ? value.toDouble() : 0;
      }

      final int wins = number('wins').round();
      final int losses = number('losses').round();
      final String record = (wins + losses) > 0
          ? '$wins-$losses'
          : _recordFromSummary(stats) ?? '0-0';
      rows.add(
        TeamStanding(
          team: Team(
            id: 'team:espn-$id',
            name: name,
            code: code.length > 4 ? code.substring(0, 4) : code,
            logoUrl: null,
            colourHex: '#0B6FD1',
          ),
          leagueId: slug,
          leagueLabel: ref.label,
          record: record,
          rank: number('rank').round(),
        ),
      );
    }

    // ESPN orders entries by conference/division; rank by win pct for a single
    // combined table, then fall back to the source order.
    rows.sort((a, b) => _winPct(b).compareTo(_winPct(a)));
    for (int i = 0; i < rows.length; i += 1) {
      rows[i] = TeamStanding(
        team: rows[i].team,
        leagueId: rows[i].leagueId,
        leagueLabel: rows[i].leagueLabel,
        record: rows[i].record,
        rank: i + 1,
      );
    }
    final List<TeamStanding> result = List<TeamStanding>.unmodifiable(
      rows.take(limit),
    );
    _standingsCache[slug] = result;
    return result;
  }

  static double _winPct(TeamStanding row) {
    final List<String> parts = row.record.split('-');
    final int wins = int.tryParse(parts.first) ?? 0;
    final int losses = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final int total = wins + losses;
    return total == 0 ? 0 : wins / total;
  }

  static String? _recordFromSummary(Map<String, dynamic> stats) {
    for (final Object? stat in stats.values) {
      if (stat is Map && stat['type'] == 'total') {
        final String? summary = stat['summary']?.toString();
        if (summary != null && summary.contains('-')) return summary;
      }
    }
    return null;
  }

  /// ESPN categories tag every team a story touches.
  static bool _mentionsTeam(Map<String, dynamic> json, String teamId) {
    final Object? categories = json['categories'];
    if (categories is! List) return false;
    for (final Object? category in categories) {
      if (category is Map &&
          category['type'] == 'team' &&
          category['teamId']?.toString() == teamId) {
        return true;
      }
    }
    return false;
  }

  Article _articleFromJson(Map<String, dynamic> json) {
    final String headline = (json['headline'] ?? json['title'] ?? '')
        .toString();
    if (headline.isEmpty) throw const FormatException('missing headline');
    final Object? links = json['links'];
    final String? sourceUrl = links is Map && links['web'] is Map
        ? (links['web'] as Map)['href']?.toString()
        : null;
    // ESPN is an unlicensed external wire: the card carries the headline and
    // excerpt, and the story opens at ESPN. No publisher-hosted art is embedded.
    final DateTime published =
        DateTime.tryParse((json['published'] ?? '').toString()) ??
        DateTime.now().toUtc();
    final Set<String> tags = <String>{'sports'};
    final Object? categories = json['categories'];
    if (categories is List) {
      for (final Object? category in categories) {
        if (category is! Map) continue;
        final String type = (category['type'] ?? '').toString().toLowerCase();
        if (type == 'team' && category['teamId'] != null) {
          final String espnId = category['teamId'].toString();
          tags.add('team:espn-$espnId');
          final String? catalogueId = _catalogueIdForNumeric(espnId);
          if (catalogueId != null) tags.add(catalogueId);
        }
        if (type == 'league') {
          final Object? leagueId = category['leagueId'] ?? category['id'];
          if (leagueId != null) tags.add('league:$leagueId');
        }
      }
    }
    return Article(
      id: 'espn:${json['id']}',
      title: headline,
      summary: (json['description'] ?? '').toString(),
      publisher: const Publisher(
        id: 'espn',
        name: 'ESPN',
        wordmark: 'ESPN',
        websiteUrl: 'https://www.espn.com',
        country: 'United States',
      ),
      publishedAt: published,
      sourceUrl: sourceUrl,
      categoryId: 'sports',
      tags: List<String>.unmodifiable(tags),
      previewOnly: true,
    );
  }
}
