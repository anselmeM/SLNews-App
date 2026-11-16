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

  test('member competitions fold onto the section that renders them', () {
    // These four are the competitions the merged "European Leagues" block covers.
    expect(mergedLeagueLabelFor('La Liga'), 'European Leagues');
    expect(mergedLeagueLabelFor('  serie a '), 'European Leagues');
    expect(mergedLeagueLabelFor('Bundesliga'), 'European Leagues');
    expect(mergedLeagueLabelFor('Ligue 1'), 'European Leagues');

    // Standalone competitions are left alone, and nothing matches empty input.
    expect(mergedLeagueLabelFor('NBA'), isNull);
    expect(mergedLeagueLabelFor('Premier League'), isNull);
    expect(mergedLeagueLabelFor('  '), isNull);

    // The merged id itself never maps onto itself.
    expect(mergedLeagueLabelFor('European Leagues'), isNull);
  });
}
