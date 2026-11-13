import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/sources/espn_source.dart';

void main() {
  test('maps the Lakers catalogue id to ESPN NBA', () {
    expect(EspnSource.supportsTeamId('team:lal'), isTrue);
    expect(EspnSource.leagueIdForTeam('team:lal'), 'nba');
    expect(EspnSource.refForTeam('team:lal')!.teamId, '13');
    expect(EspnSource.supportsTeamId('team:leone-stars'), isFalse);
  });

  test('maps followed leagues to ESPN standings paths', () {
    expect(EspnSource.supportsLeagueId('league:nba'), isTrue);
    expect(EspnSource.supportsLeagueId('league:epl'), isTrue);
    expect(EspnSource.supportsLeagueId('league:spl'), isFalse);
    expect(EspnSource.leagueLabel('nba'), 'NBA');
  });
}
