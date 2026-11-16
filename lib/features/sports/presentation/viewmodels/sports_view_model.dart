import '../../../../core/data/sources/espn_source.dart';
import '../../../../core/domain/models/follow_models.dart';
import '../../../../core/domain/models/sports_models.dart';

/// Pure-Dart derivation behind the Sports tab.
///
/// The page renders four independent streams (scoreboard, following, team news,
/// fixtures) and needs exactly three derived facts from them: a deterministic
/// ordering for the scoreboard strip, the reader's followed sports entities, and
/// which team owns the "… news" section. Keeping that logic here means the
/// widget tree stays declarative and the rules are unit-testable without a
/// `WidgetTester`.
///
/// Ordering rule for [ordered]: live fixtures first, then scheduled fixtures in
/// chronological order, then finals (most recent first) and postponed fixtures
/// last. Ties fall back to the fixture id so the order is stable even though
/// `List.sort` is not.
class SportsViewModel {
  /// Creates a view model from already-derived lists; prefer [SportsViewModel.from].
  const SportsViewModel({
    required this.ordered,
    required this.live,
    required this.upcoming,
    required this.results,
    required this.followedSports,
    required this.heroTeam,
  });

  /// Derives the display model from the two upstream snapshots.
  ///
  /// [snapshot] is `null` while the scoreboard is still loading or when it
  /// failed, which is a normal state: the page still renders the Following,
  /// news and fixture sections. [following] is `null` when no subscription
  /// snapshot is available yet.
  factory SportsViewModel.from({
    ScoreboardSnapshot? snapshot,
    FollowingSnapshot? following,
  }) {
    final List<GameScore> games = <GameScore>[...?snapshot?.games]
      ..sort(compareGames);
    final List<FollowTarget> followedSports = _followedSports(following);
    return SportsViewModel(
      ordered: List<GameScore>.unmodifiable(games),
      live: List<GameScore>.unmodifiable(
        games.where((GameScore game) => game.status == GameStatus.live),
      ),
      upcoming: List<GameScore>.unmodifiable(
        games.where((GameScore game) => game.status == GameStatus.scheduled),
      ),
      // Postponed fixtures are neither live nor upcoming, so they are grouped
      // with the results block while still sorting last.
      results: List<GameScore>.unmodifiable(
        games.where(
          (GameScore game) =>
              game.status == GameStatus.finalScore ||
              game.status == GameStatus.postponed,
        ),
      ),
      followedSports: followedSports,
      heroTeam: _heroTeam(followedSports),
    );
  }

  /// An empty model, used by callers that have no snapshot at all.
  static const SportsViewModel empty = SportsViewModel(
    ordered: <GameScore>[],
    live: <GameScore>[],
    upcoming: <GameScore>[],
    results: <GameScore>[],
    followedSports: <FollowTarget>[],
    heroTeam: null,
  );

  /// Every fixture, ordered for display (see the class docs).
  final List<GameScore> ordered;

  /// Fixtures currently in play.
  final List<GameScore> live;

  /// Fixtures that have not started yet, soonest first.
  final List<GameScore> upcoming;

  /// Finals (most recent first) plus postponed fixtures.
  final List<GameScore> results;

  /// The reader's followed sports entities: the sports catalogue merged with the
  /// followed teams and leagues, de-duplicated by id.
  final List<FollowTarget> followedSports;

  /// First followed *team*; drives the "… news" heading and the fixture query.
  /// Leagues are deliberately excluded because no fixture query can be made for
  /// them. `null` when the reader follows no team.
  final FollowTarget? heroTeam;

  /// True when the scoreboard returned at least one fixture.
  bool get hasGames => ordered.isNotEmpty;

  /// True when the reader follows at least one team or league.
  bool get hasFollowedSports => followedSports.isNotEmpty;

  /// "Leone Stars news" / "Latest in sport" when no team is followed.
  String get newsSectionTitle {
    final FollowTarget? team = heroTeam;
    return team == null ? 'Latest in sport' : '${team.label} news';
  }

  /// Heading above the per-team fixture list.
  String get fixturesSectionTitle => 'Fixtures & results';

  /// Total number of fixtures, used by the page to decide whether the screen has
  /// any content at all.
  int get gameCount => ordered.length;

  /// Comparator implementing the strip ordering contract.
  static int compareGames(GameScore a, GameScore b) {
    final int byStatus = _statusRank(a.status).compareTo(_statusRank(b.status));
    if (byStatus != 0) return byStatus;

    final DateTime? left = a.startsAt;
    final DateTime? right = b.startsAt;
    if (left != null && right != null) {
      // Results read backwards (newest first) so last night's game leads;
      // fixtures and live games read forwards.
      final bool newestFirst =
          a.status == GameStatus.finalScore || a.status == GameStatus.postponed;
      final int byTime = newestFirst
          ? right.compareTo(left)
          : left.compareTo(right);
      if (byTime != 0) return byTime;
    } else if (left != null) {
      return -1; // A dated fixture outranks an undated one.
    } else if (right != null) {
      return 1;
    }
    return a.id.compareTo(b.id);
  }

  /// Short chip label for a followed entity, e.g. "Los Angeles Lakers" → "LAL".
  ///
  /// A short alphabetic `emojiOrGlyph` (seed data sometimes stores the team code
  /// there) wins; otherwise one letter per word, or the first three letters of a
  /// single-word label, is used.
  static String shortLabel(FollowTarget target) {
    final String? glyph = target.emojiOrGlyph?.trim();
    if (glyph != null &&
        glyph.isNotEmpty &&
        glyph.length <= 4 &&
        RegExp(r'^[A-Za-z]+$').hasMatch(glyph)) {
      return glyph.toUpperCase();
    }

    final List<String> words = target.label
        .trim()
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final String word = words.first;
      return word
          .substring(0, word.length >= 3 ? 3 : word.length)
          .toUpperCase();
    }
    final StringBuffer buffer = StringBuffer();
    for (final String word in words.take(3)) {
      buffer.write(word[0]);
    }
    return buffer.toString().toUpperCase();
  }

  /// The reader's followed teams and leagues, repaired with catalogue labels.
  ///
  /// `FollowingSnapshot.sports` is the *catalogue* for those kinds, not the
  /// follow state — using it wholesale made every seeded team look followed and
  /// pinned the first catalogue team as the page's hero. Only ids in `followed`
  /// qualify; the catalogue entry supplies the label/crest when it has one.
  static List<FollowTarget> _followedSports(FollowingSnapshot? following) {
    if (following == null) return const <FollowTarget>[];
    final Map<String, FollowTarget> catalogue = <String, FollowTarget>{
      for (final FollowTarget target in following.sports) target.id: target,
    };
    final Set<String> seen = <String>{};
    return List<FollowTarget>.unmodifiable(<FollowTarget>[
      for (final FollowTarget target in following.followed)
        if ((target.kind == FollowKind.team ||
                target.kind == FollowKind.league) &&
            seen.add(target.id))
          catalogue[target.id] ?? target,
    ]);
  }

  /// The followed team the page leads with.
  ///
  /// A team ESPN covers wins, because that is what makes the "team news" and
  /// per-team fixture sections real; otherwise the first followed team is used.
  static FollowTarget? _heroTeam(List<FollowTarget> targets) {
    FollowTarget? fallback;
    for (final FollowTarget target in targets) {
      if (target.kind != FollowKind.team) continue;
      fallback ??= target;
      if (EspnSource.supportsTeamId(target.id)) return target;
    }
    return fallback;
  }

  /// Live fixtures lead, then scheduled, then finals, then postponed.
  static int _statusRank(GameStatus status) => switch (status) {
    GameStatus.live => 0,
    GameStatus.scheduled => 1,
    GameStatus.finalScore => 2,
    GameStatus.postponed => 3,
  };
}
