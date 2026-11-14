/// Slug/label helpers for the sports surfaces.
///
/// Fixtures carry a league *label* ("Sierra Leone Premier League") but the
/// standings endpoint is keyed by a league *id* (`spl`), and follow targets can
/// arrive either way. Keeping the mapping in one place means a league page, a
/// team page and a score card cannot disagree about which league they mean.
library;

abstract final class SportsLinks {
  static const Map<String, String> _idByLabel = <String, String>{
    'Sierra Leone Premier League': 'spl',
    'Premier League': 'epl',
    'UEFA Champions League': 'champions-league',
    'La Liga': 'la-liga',
    'Serie A': 'serie-a',
    'Bundesliga': 'bundesliga',
    'Ligue 1': 'ligue-1',
    'NBA': 'nba',
    'NFL': 'nfl',
    'MLB': 'mlb',
    'NHL': 'nhl',
    'AFCON Qualifier': 'afcon',
    'Formula 1': 'f1',
    'Tennis': 'tennis',
    'Cricket': 'cricket',
    'Golf': 'golf',
  };

  /// League id for a fixture label; unknown labels get a stable slug so the
  /// page still opens (the standings endpoint then falls back to all rows).
  static String leagueIdForLabel(String label) {
    final String trimmed = label.trim();
    if (trimmed.isEmpty) return 'league';
    return _idByLabel[trimmed] ?? slug(trimmed);
  }

  /// Human label for a league id, including ids like `league:spl`.
  static String leagueLabelForId(String id) {
    final String slugged = _suffix(id).toLowerCase();
    for (final MapEntry<String, String> entry in _idByLabel.entries) {
      if (entry.value == slugged) return entry.key;
    }
    return titleFromId(id);
  }

  /// Display name for a team id such as `team:lal` → "Lal".
  ///
  /// Only a fallback: pages pushed from a row pass the real label as route
  /// extra, so deep links are the only place this appears.
  static String titleFromId(String id) {
    final String raw = _suffix(id).replaceAll(RegExp(r'[-_]+'), ' ').trim();
    if (raw.isEmpty) return 'Sports';
    return raw
        .split(' ')
        .where((String word) => word.isNotEmpty)
        .map(
          (String word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  /// URL/id-safe slug, e.g. "Sierra Leone Premier League" → `sierra-leone-premier-league`.
  static String slug(String label) => label
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  static String _suffix(String id) {
    final List<String> parts = id.split(':');
    return parts.length > 1 ? parts.last : id;
  }
}
