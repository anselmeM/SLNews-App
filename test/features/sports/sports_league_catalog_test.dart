import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/features/sports/domain/sports_league_catalog.dart';

void main() {
  test('featured catalogue covers the major sports and leagues once', () {
    expect(kFeaturedSportsLeagues, isNotEmpty);
    final Set<String> labels = <String>{};
    final Set<String> ids = <String>{};
    for (final SportsLeague league in kFeaturedSportsLeagues) {
      expect(labels.add(league.label), isTrue, reason: league.label);
      expect(ids.add(league.id), isTrue, reason: league.id);
    }
    expect(
      labels,
      containsAll(<String>[
        'NBA',
        'NFL',
        'MLB',
        'NHL',
        'Premier League',
        'UEFA Champions League',
        'European Leagues',
        'Sierra Leone Premier League',
        'AFCON Qualifier',
        'Formula 1',
        'Tennis',
        'Cricket',
        'Golf',
      ]),
    );
    expect(featuredLeagueId('European Leagues'), 'european-leagues');
    expect(featuredLeagueId('unknown'), isNull);
    expect(featuredLeagueOrder('NBA'), lessThan(featuredLeagueOrder('Golf')));
    expect(featuredLeagueOrder('unknown'), kFeaturedSportsLeagues.length);
  });
}
