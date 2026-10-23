import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/repositories/default_sports_repository.dart';
import 'package:slnews_mobile/core/data/seed/seed_loader.dart';
import 'package:slnews_mobile/core/data/sources/the_sports_db_source.dart';
import 'package:slnews_mobile/core/domain/models/sports_models.dart';

import 'fakes.dart';

const Map<String, dynamic> lakersEvent = <String, dynamic>{
  'events': <Map<String, dynamic>>[
    <String, dynamic>{
      'idEvent': '9001',
      'strHomeTeam': 'Los Angeles Lakers',
      'strAwayTeam': 'Denver Nuggets',
      'idHomeTeam': '134860',
      'idAwayTeam': '134867',
      'intHomeScore': '121',
      'intAwayScore': '110',
      'strStatus': 'FT',
      'dateEvent': '2026-10-22',
      'strTime': '02:30:00',
    },
  ],
};

void main() {
  test('a followed seed team finds its live rows by name', () async {
    final TheSportsDbSource live = TheSportsDbSource.forFetcher(
      (String url) async => lakersEvent,
    );
    final DefaultSportsRepository repository = DefaultSportsRepository(
      seedLoader: InMemorySeedLoader(seedData()),
      liveSource: live,
    );

    final ScoreboardSnapshot board = await repository.scoreboard();
    expect(board.providerLabel, 'thesportsdb');
    expect(
      board.games.any((GameScore g) => g.home.name == 'Los Angeles Lakers'),
      isTrue,
    );

    final List<GameScore> followed = await repository.gamesForTeam(
      'team:lakers',
    );
    expect(followed, isNotEmpty);
    expect(followed.first.home.name, 'Los Angeles Lakers');
  });
}
