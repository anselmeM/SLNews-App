import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/features/sports/domain/sports_links.dart';

/// League labels and ids are two vocabularies for the same competition; this is
/// the only place that translates between them.
void main() {
  group('leagueIdForLabel', () {
    test('maps the seeded competitions to their standings ids', () {
      expect(
        SportsLinks.leagueIdForLabel('Sierra Leone Premier League'),
        'spl',
      );
      expect(SportsLinks.leagueIdForLabel('Premier League'), 'epl');
      expect(SportsLinks.leagueIdForLabel('NBA'), 'nba');
      expect(
        SportsLinks.leagueIdForLabel('UEFA Champions League'),
        'champions-league',
      );
      expect(
        SportsLinks.leagueIdForLabel('European Leagues'),
        'european-leagues',
      );
      expect(SportsLinks.leagueIdForLabel('La Liga'), 'la-liga');
      expect(SportsLinks.leagueIdForLabel('Serie A'), 'serie-a');
      expect(SportsLinks.leagueIdForLabel('Bundesliga'), 'bundesliga');
      expect(SportsLinks.leagueIdForLabel('Ligue 1'), 'ligue-1');
      expect(SportsLinks.leagueIdForLabel('Formula 1'), 'f1');
      expect(SportsLinks.leagueIdForLabel('Tennis'), 'tennis');
      expect(SportsLinks.leagueIdForLabel('Cricket'), 'cricket');
      expect(SportsLinks.leagueIdForLabel('Golf'), 'golf');
      expect(SportsLinks.leagueIdForLabel('AFCON Qualifier'), 'afcon');
    });

    test('slugs unknown labels and tolerates edges', () {
      expect(
        SportsLinks.leagueIdForLabel('CAF Champions League'),
        'caf-champions-league',
      );
      expect(SportsLinks.leagueIdForLabel('  '), 'league');
      expect(SportsLinks.leagueIdForLabel('  NBA  '), 'nba');
    });
  });

  group('leagueLabelForId', () {
    test('reverses known ids, including prefixed ones', () {
      expect(
        SportsLinks.leagueLabelForId('spl'),
        'Sierra Leone Premier League',
      );
      expect(SportsLinks.leagueLabelForId('league:epl'), 'Premier League');
    });

    test('title-cases unknown ids for deep links', () {
      expect(
        SportsLinks.leagueLabelForId('caf-champions-league'),
        'Caf Champions League',
      );
      expect(SportsLinks.leagueLabelForId(''), 'Sports');
    });
  });

  group('titleFromId', () {
    test('strips the kind prefix and title-cases', () {
      expect(
        SportsLinks.titleFromId('team:mighty-blackpool'),
        'Mighty Blackpool',
      );
      expect(SportsLinks.titleFromId('LAL'), 'Lal');
    });
  });
}
