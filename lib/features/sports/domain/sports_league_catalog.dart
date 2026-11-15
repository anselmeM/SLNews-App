/// Curated sports feed order and league identities.
///
/// Sections used to exist only when the scoreboard returned a fixture, so
/// off-season leagues disappeared entirely and only the five backend-scoreboard
/// competitions ever appeared. This catalogue is the feed's minimum coverage:
/// a section appears when its news feed or the scoreboard has content.
library;

class SportsLeague {
  const SportsLeague({required this.label, required this.id});

  final String label;
  final String id;
}

const List<SportsLeague> kFeaturedSportsLeagues = <SportsLeague>[
  SportsLeague(label: 'NBA', id: 'nba'),
  SportsLeague(label: 'NFL', id: 'nfl'),
  SportsLeague(label: 'MLB', id: 'mlb'),
  SportsLeague(label: 'NHL', id: 'nhl'),
  SportsLeague(label: 'Premier League', id: 'epl'),
  SportsLeague(label: 'UEFA Champions League', id: 'champions-league'),
  SportsLeague(label: 'European Leagues', id: 'european-leagues'),
  SportsLeague(label: 'Sierra Leone Premier League', id: 'spl'),
  SportsLeague(label: 'AFCON Qualifier', id: 'afcon'),
  SportsLeague(label: 'Formula 1', id: 'f1'),
  SportsLeague(label: 'Tennis', id: 'tennis'),
  SportsLeague(label: 'Cricket', id: 'cricket'),
  SportsLeague(label: 'Golf', id: 'golf'),
];

/// Id for a league label, including labels returned by scoreboard providers.
String? featuredLeagueId(String label) {
  final String trimmed = label.trim();
  for (final SportsLeague league in kFeaturedSportsLeagues) {
    if (league.label == trimmed) return league.id;
  }
  return null;
}

/// Index used to sort section labels; unknown labels go after the catalogue.
int featuredLeagueOrder(String label) {
  final String? id = featuredLeagueId(label);
  if (id == null) return kFeaturedSportsLeagues.length;
  return kFeaturedSportsLeagues.indexWhere((SportsLeague l) => l.id == id);
}
