import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/domain/models/sports_models.dart';
import 'package:slnews_mobile/features/sports/presentation/viewmodels/sports_view_model.dart';

import 'support/fakes.dart';

/// The Sports view model is pure Dart, so these cases pin the derivation rules
/// without pumping a widget: ordering, bucketing, null scores, postponed
/// fixtures, empty/null snapshots and the followed-team selection.
void main() {
  final DateTime oct15 = DateTime(2026, 10, 15, 22);
  final DateTime oct16 = DateTime(2026, 10, 16, 20);
  final DateTime oct10 = DateTime(2026, 10, 10, 18);
  final DateTime oct14 = DateTime(2026, 10, 14, 18);

  ScoreboardSnapshot snapshotOf(List<GameScore> games) => ScoreboardSnapshot(
    games: games,
    providerLabel: 'yahoo/sports',
    updatedAt: oct15,
  );

  group('SportsViewModel ordering', () {
    test(
      'orders live, then scheduled by start time, then finals, then postponed',
      () {
        final GameScore live = buildGame(
          id: 'g-live',
          status: GameStatus.live,
          startsAt: oct15,
          periodLabel: 'Q3 04:12',
          homeScore: 72,
          awayScore: 68,
        );
        final GameScore scheduledLate = buildGame(
          id: 'g-sched-late',
          startsAt: oct16,
        );
        final GameScore scheduledEarly = buildGame(
          id: 'g-sched-early',
          startsAt: DateTime(2026, 10, 15, 20),
        );
        final GameScore finalNew = buildGame(
          id: 'g-final-new',
          status: GameStatus.finalScore,
          startsAt: oct14,
          homeScore: 101,
          awayScore: 99,
        );
        final GameScore finalOld = buildGame(
          id: 'g-final-old',
          status: GameStatus.finalScore,
          startsAt: oct10,
          homeScore: 90,
          awayScore: 95,
        );
        final GameScore postponed = buildGame(
          id: 'g-postponed',
          status: GameStatus.postponed,
          startsAt: oct14,
        );

        final SportsViewModel model = SportsViewModel.from(
          snapshot: snapshotOf(<GameScore>[
            finalOld,
            scheduledLate,
            postponed,
            live,
            finalNew,
            scheduledEarly,
          ]),
        );

        expect(
          model.ordered.map((GameScore game) => game.id).toList(),
          <String>[
            'g-live',
            'g-sched-early',
            'g-sched-late',
            'g-final-new',
            'g-final-old',
            'g-postponed',
          ],
        );
      },
    );

    test('splits fixtures into live, upcoming and results buckets', () {
      final SportsViewModel model = SportsViewModel.from(
        snapshot: snapshotOf(<GameScore>[
          buildGame(id: 'live-1', status: GameStatus.live, startsAt: oct15),
          buildGame(
            id: 'final-1',
            status: GameStatus.finalScore,
            startsAt: oct10,
            homeScore: 1,
            awayScore: 0,
          ),
          buildGame(id: 'sched-1', startsAt: oct16),
          buildGame(id: 'postponed-1', status: GameStatus.postponed),
        ]),
      );

      expect(model.live.map((GameScore game) => game.id), <String>['live-1']);
      expect(model.upcoming.map((GameScore game) => game.id), <String>[
        'sched-1',
      ]);
      // Postponed fixtures are neither live nor upcoming, so they sit with the
      // results while still sorting after them.
      expect(model.results.map((GameScore game) => game.id), <String>[
        'final-1',
        'postponed-1',
      ]);
      expect(model.hasGames, isTrue);
      expect(model.gameCount, 4);
    });

    test(
      'keeps undated fixtures behind dated ones and reports missing scores',
      () {
        final GameScore undated = buildGame(id: 'g-undated');
        final GameScore dated = buildGame(id: 'g-dated', startsAt: oct16);

        final SportsViewModel model = SportsViewModel.from(
          snapshot: snapshotOf(<GameScore>[undated, dated]),
        );

        expect(model.ordered.map((GameScore game) => game.id), <String>[
          'g-dated',
          'g-undated',
        ]);
        expect(undated.hasScores, isFalse);
        expect(undated.homeScore, isNull);
        expect(undated.awayScore, isNull);
        expect(undated.statusLabel, 'TBC');
        expect(dated.statusLabel, '8:00PM');
      },
    );

    test('is deterministic when two fixtures tie on status and start time', () {
      final SportsViewModel model = SportsViewModel.from(
        snapshot: snapshotOf(<GameScore>[
          buildGame(id: 'b', startsAt: oct16),
          buildGame(id: 'a', startsAt: oct16),
        ]),
      );

      // `List.sort` is not stable, so ties fall back to the id.
      expect(model.ordered.map((GameScore game) => game.id), <String>[
        'a',
        'b',
      ]);
    });
  });

  group('SportsViewModel snapshots', () {
    test('empty snapshot yields empty buckets and no hero team', () {
      final SportsViewModel model = SportsViewModel.from(
        snapshot: snapshotOf(const <GameScore>[]),
        following: const FollowingSnapshot.empty(),
      );

      expect(model.hasGames, isFalse);
      expect(model.ordered, isEmpty);
      expect(model.live, isEmpty);
      expect(model.upcoming, isEmpty);
      expect(model.results, isEmpty);
      expect(model.hasFollowedSports, isFalse);
      expect(model.heroTeam, isNull);
      expect(model.newsSectionTitle, 'Latest in sport');
      expect(model.fixturesSectionTitle, 'Fixtures & results');
    });

    test('a null snapshot and null following snapshot behave like empty', () {
      final SportsViewModel model = SportsViewModel.from();

      expect(model.hasGames, isFalse);
      expect(model.followedSports, isEmpty);
      expect(model.hasFollowedSports, isFalse);
      expect(model.heroTeam, isNull);
    });
  });

  group('SportsViewModel following', () {
    const FollowTarget lakers = FollowTarget(
      id: 'team:lal',
      kind: FollowKind.team,
      label: 'Los Angeles Lakers',
      imageUrl: 'https://example.test/lal.png',
    );
    const FollowTarget spl = FollowTarget(
      id: 'league:spl',
      kind: FollowKind.league,
      label: 'Sierra Leone Premier League',
    );
    const FollowTarget freetown = FollowTarget(
      id: 'city:freetown',
      kind: FollowKind.location,
      label: 'Freetown',
    );

    test('keeps only followed teams and leagues, repairing labels from the catalogue', () {
      const FollowTarget followedLakers = FollowTarget(
        id: 'team:lal',
        kind: FollowKind.team,
        label: 'Lakers',
      );
      const FollowTarget catalogueLakers = FollowTarget(
        id: 'team:lal',
        kind: FollowKind.team,
        label: 'Los Angeles Lakers',
        imageUrl: 'https://example.test/lal.png',
      );
      final SportsViewModel model = SportsViewModel.from(
        following: const FollowingSnapshot(
          followed: <FollowTarget>[followedLakers, freetown],
          suggested: <FollowTarget>[],
          // The catalogue holds both; only the followed id may appear.
          sports: <FollowTarget>[spl, catalogueLakers],
        ),
      );

      expect(
        model.followedSports.map((FollowTarget target) => target.id),
        <String>['team:lal'],
      );
      // The catalogue entry supplies the full label and crest.
      expect(model.followedSports.single.label, 'Los Angeles Lakers');
      expect(
        model.followedSports.single.imageUrl,
        'https://example.test/lal.png',
      );
      expect(model.hasFollowedSports, isTrue);
      expect(model.heroTeam?.id, 'team:lal');
      expect(model.newsSectionTitle, 'Los Angeles Lakers news');
    });

    test('a catalogue nobody follows is not treated as followed', () {
      final SportsViewModel model = SportsViewModel.from(
        following: const FollowingSnapshot(
          followed: <FollowTarget>[],
          suggested: <FollowTarget>[],
          sports: <FollowTarget>[spl, lakers],
        ),
      );

      expect(model.followedSports, isEmpty);
      expect(model.hasFollowedSports, isFalse);
      expect(model.heroTeam, isNull);
      expect(model.newsSectionTitle, 'Latest in sport');
    });

    test('the hero prefers a followed team ESPN actually covers', () {
      const FollowTarget boRangers = FollowTarget(
        id: 'team:bo-rangers',
        kind: FollowKind.team,
        label: 'Bo Rangers',
      );
      final SportsViewModel model = SportsViewModel.from(
        following: const FollowingSnapshot(
          // Bo Rangers is first in follow order but has no ESPN feed, so the
          // Lakers must lead: the header promises "news" and fixtures.
          followed: <FollowTarget>[boRangers, lakers],
          suggested: <FollowTarget>[],
        ),
      );

      expect(model.heroTeam?.id, 'team:lal');
    });

    test('a followed league alone does not become the hero team', () {
      final SportsViewModel model = SportsViewModel.from(
        following: const FollowingSnapshot(
          followed: <FollowTarget>[spl],
          suggested: <FollowTarget>[],
        ),
      );

      expect(model.hasFollowedSports, isTrue);
      expect(model.heroTeam, isNull);
      expect(model.newsSectionTitle, 'Latest in sport');
    });

    test('shortLabel prefers a glyph code and otherwise derives initials', () {
      expect(SportsViewModel.shortLabel(lakers), 'LAL');
      expect(SportsViewModel.shortLabel(spl), 'SLP');
      expect(
        SportsViewModel.shortLabel(
          const FollowTarget(
            id: 'team:x',
            kind: FollowKind.team,
            label: 'Leone Stars',
            emojiOrGlyph: 'LNS',
          ),
        ),
        'LNS',
      );
      expect(
        SportsViewModel.shortLabel(
          const FollowTarget(id: 'team:y', kind: FollowKind.team, label: 'Bo'),
        ),
        'BO',
      );
    });
  });
}
