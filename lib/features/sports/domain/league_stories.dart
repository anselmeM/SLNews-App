import '../../../core/domain/models/article.dart';
import '../../../core/domain/models/sports_models.dart';

/// Assigns sports stories to a competition using explicit league cues.
///
/// The sports feed is not tagged by league, so guessing from a single word is
/// how MLB blocks ended up showing NBA stories. This keeps the rules in one
/// place and deliberately returns **nothing** when there is no clear match:
/// a score-only block is better than a wrong story.
abstract final class LeagueStories {
  static const Map<String, List<String>> _cues = <String, List<String>>{
    'NBA': <String>[
      'nba',
      'lakers',
      'celtics',
      'warriors',
      'bucks',
      'knicks',
      'bulls',
      'heat',
      'nuggets',
      'basketball',
      'lebron',
      'curry',
      'jokic',
    ],
    'NFL': <String>[
      'nfl',
      'quarterback',
      'touchdown',
      'super bowl',
      'bills',
      '49ers',
      'chiefs',
      'cowboys',
      'eagles',
      'ravens',
      'packers',
      'american football',
    ],
    'MLB': <String>[
      'mlb',
      'baseball',
      'pitcher',
      'world series',
      'yankees',
      'dodgers',
      'mets',
      'cubs',
      'red sox',
      'brewers',
      'braves',
      'home run',
    ],
    'NHL': <String>[
      'nhl',
      'hockey',
      'puck',
      'stanley cup',
      'canadiens',
      'maple leafs',
      'rangers',
      'bruins',
      'oilers',
      'hurricanes',
      'goalie',
    ],
    'PREMIER LEAGUE': <String>[
      'premier league',
      'epl',
      'arsenal',
      'liverpool',
      'manchester',
      'chelsea',
      'tottenham',
      'newcastle',
      'aston villa',
      'everton',
    ],
    'SIERRA LEONE PREMIER LEAGUE': <String>[
      'sierra leone premier league',
      'sierra leone league',
      'leone stars',
      'bo rangers',
      'east end lions',
      'mighty blackpool',
      'kamboi eagles',
      'fc kallon',
      'freetown derby',
      'spl',
    ],
    'AFCON': <String>[
      'afcon',
      'africa cup',
      'leone stars',
      'guinea',
      'sierra leone',
      'qualifier',
    ],
  };

  /// Stories clearly about [leagueLabel], newest first, at most [limit].
  ///
  /// [games] contributes today's club names/abbreviations so a story that only
  /// mentions "Bills" or "Lakers" is still assigned to the right league.
  static List<Article> forLeague(
    String leagueLabel,
    List<Article> articles, {
    List<GameScore> games = const <GameScore>[],
    int limit = 4,
  }) {
    if (articles.isEmpty || limit <= 0) return const <Article>[];
    final Set<String> terms = <String>{..._cuesFor(leagueLabel)};
    for (final GameScore game in games) {
      for (final Team team in <Team>[game.away, game.home]) {
        final String name = team.name.toLowerCase();
        terms.add(name);
        for (final String word in name.split(RegExp(r'[^a-z0-9]+'))) {
          if (word.length >= 4) terms.add(word);
        }
        if (team.code.trim().length >= 2) {
          terms.add(team.code.toLowerCase());
        }
      }
    }
    final List<Article> matches = <Article>[];
    for (final Article article in articles) {
      final String haystack = '${article.title} ${article.summary}'
          .toLowerCase();
      if (terms.any(haystack.contains)) matches.add(article);
    }
    matches.sort(
      (Article a, Article b) => b.publishedAt.compareTo(a.publishedAt),
    );
    return matches.take(limit).toList(growable: false);
  }

  static List<String> _cuesFor(String label) {
    final String value = label.toUpperCase();
    for (final MapEntry<String, List<String>> entry in _cues.entries) {
      if (value.contains(entry.key)) return entry.value;
    }
    if (value.contains('SOCCER') || value.contains('LEAGUE')) {
      return _cues['PREMIER LEAGUE']!;
    }
    return <String>[label.toLowerCase()];
  }
}
