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

/// The European competitions the Sports feed renders as one section.
///
/// They share a single combined news stream and a single "European Leagues"
/// block, so they are never followed separately: the id below is the only
/// follow target, and this list only says what that section contains.
const List<SportsLeague> kEuropeanLeagueMembers = <SportsLeague>[
  SportsLeague(label: 'La Liga', id: 'la-liga'),
  SportsLeague(label: 'Serie A', id: 'serie-a'),
  SportsLeague(label: 'Bundesliga', id: 'bundesliga'),
  SportsLeague(label: 'Ligue 1', id: 'ligue-1'),
];

/// Members merged into the competition [id]; empty for a standalone league.
List<SportsLeague> mergedLeagueMembers(String id) =>
    id == 'european-leagues' ? kEuropeanLeagueMembers : const <SportsLeague>[];

/// Index used to sort section labels; unknown labels go after the catalogue.
int featuredLeagueOrder(String label) {
  final String? id = featuredLeagueId(label);
  if (id == null) return kFeaturedSportsLeagues.length;
  return kFeaturedSportsLeagues.indexWhere((SportsLeague l) => l.id == id);
}
