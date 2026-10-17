import 'package:slnews_mobile/core/domain/models/ad_unit.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/domain/models/publisher.dart';
import 'package:slnews_mobile/core/domain/models/sports_models.dart';
import 'package:slnews_mobile/core/domain/repositories/ad_repository.dart';
import 'package:slnews_mobile/core/domain/repositories/article_repository.dart';
import 'package:slnews_mobile/core/domain/repositories/following_repository.dart';
import 'package:slnews_mobile/core/domain/repositories/sports_repository.dart';
import 'package:slnews_mobile/core/domain/repositories/user_state_repository.dart';

/// Hand-written in-memory doubles for the Sports tab.
///
/// `test/support/fakes.dart` does not exist in this checkout, so the Sports
/// tests own the small set of fakes they need (CONTRACT §7). Everything is
/// synchronous state behind `Future`-returning interfaces: enough to drive the
/// real providers without touching Hive, dio or the file system.

/// A [SportsRepository] backed by literal fixtures.
class FakeSportsRepository implements SportsRepository {
  FakeSportsRepository({
    ScoreboardSnapshot? scoreboard,
    Map<String, List<GameScore>>? gamesByTeam,
    this.error,
  }) : _scoreboard =
           scoreboard ??
           ScoreboardSnapshot(
             games: const <GameScore>[],
             providerLabel: 'slnews',
             updatedAt: DateTime(2026, 10, 15, 20, 30),
           ),
       _gamesByTeam = gamesByTeam ?? <String, List<GameScore>>{};

  final ScoreboardSnapshot _scoreboard;
  final Map<String, List<GameScore>> _gamesByTeam;

  /// When set, [scoreboard] throws it â€” used for the degraded-state tests.
  final Object? error;

  @override
  Future<ScoreboardSnapshot> scoreboard({int limit = 8}) async {
    final Object? failure = error;
    if (failure != null) throw failure;
    return _scoreboard;
  }

  @override
  Future<List<GameScore>> gamesForTeam(String teamId, {int limit = 10}) async =>
      _gamesByTeam[teamId] ?? const <GameScore>[];

  @override
  Future<List<TeamStanding>> standings(String leagueId) async =>
      const <TeamStanding>[];
}

/// An [ArticleRepository] serving literal per-category lists.
class FakeArticleRepository implements ArticleRepository {
  FakeArticleRepository({
    Map<String, List<Article>>? feeds,
    this.isOffline = false,
    this.lastSyncedAt,
  }) : feeds = feeds ?? <String, List<Article>>{};

  /// Category slug â†’ stories.
  final Map<String, List<Article>> feeds;

  @override
  final bool isOffline;

  @override
  final DateTime? lastSyncedAt;

  /// Seeds the feed returned by [byCategory].
  void seed(String categoryId, List<Article> articles) =>
      feeds[categoryId] = articles;

  @override
  Future<List<Article>> topStories({int limit = 8}) async =>
      feeds['top'] ?? const <Article>[];

  @override
  Future<List<Article>> byCategory(String categoryId, {int limit = 30}) async =>
      feeds[categoryId] ?? const <Article>[];

  @override
  Future<List<Article>> byLocation(String locationId, {int limit = 20}) async =>
      const <Article>[];

  @override
  Future<Article?> byId(String id) async => null;

  @override
  Future<List<Article>> search(String query, {int limit = 20}) async =>
      const <Article>[];

  @override
  Future<List<Article>> refresh() async => const <Article>[];
}

/// An [AdRepository] returning a fixed rotation for every placement.
class FakeAdRepository implements AdRepository {
  FakeAdRepository({List<AdUnit>? units}) : _units = units ?? const <AdUnit>[];

  final List<AdUnit> _units;

  @override
  Future<List<AdUnit>> units({String placement = 'default'}) async => _units;

  @override
  List<AdUnit> get cachedUnits => _units;
}

/// A [FollowingRepository] whose snapshot can be mutated through the API.
class FakeFollowingRepository implements FollowingRepository {
  FakeFollowingRepository({FollowingSnapshot? snapshot})
    : _snapshot = snapshot ?? const FollowingSnapshot.empty();

  FollowingSnapshot _snapshot;

  @override
  FollowingSnapshot load() => _snapshot;

  @override
  bool isFollowed(String targetId) => _snapshot.isFollowed(targetId);

  @override
  Future<FollowingSnapshot> follow(FollowTarget target) async {
    if (!_snapshot.isFollowed(target.id)) {
      _snapshot = _snapshot.copyWith(
        followed: <FollowTarget>[..._snapshot.followed, target],
      );
    }
    return _snapshot;
  }

  @override
  Future<FollowingSnapshot> unfollow(String targetId) async {
    _snapshot = _snapshot.copyWith(
      followed: _snapshot.followed
          .where((FollowTarget target) => target.id != targetId)
          .toList(growable: false),
    );
    return _snapshot;
  }

  @override
  Future<FollowingSnapshot> toggle(FollowTarget target) =>
      isFollowed(target.id) ? unfollow(target.id) : follow(target);
}

/// A [UserStateRepository] held entirely in memory.
class FakeUserStateRepository implements UserStateRepository {
  final Set<String> _bookmarks = <String>{};
  final Set<String> _likes = <String>{};

  @override
  Set<String> get bookmarkedIds => Set<String>.unmodifiable(_bookmarks);

  @override
  Set<String> get likedIds => Set<String>.unmodifiable(_likes);

  @override
  bool isBookmarked(String articleId) => _bookmarks.contains(articleId);

  @override
  bool isLiked(String articleId) => _likes.contains(articleId);

  @override
  Future<void> toggleBookmark(String articleId) async {
    if (!_bookmarks.remove(articleId)) _bookmarks.add(articleId);
  }

  @override
  Future<void> toggleLike(String articleId) async {
    if (!_likes.remove(articleId)) _likes.add(articleId);
  }

  @override
  String get themeMode => 'system';

  @override
  Future<void> setThemeMode(String mode) async {}

  @override
  double get textScale => 1;

  @override
  Future<void> setTextScale(double scale) async {}

  @override
  String get activeLocationId => 'city:freetown';

  @override
  Future<void> setActiveLocationId(String locationId) async {}

  @override
  bool get breakingNewsAlertsEnabled => true;

  @override
  Future<void> setBreakingNewsAlertsEnabled(bool enabled) async {}

  @override
  bool get editorsPicksEnabled => false;

  @override
  Future<void> setEditorsPicksEnabled(bool enabled) async {}

  @override
  bool get interactiveContentEnabled => false;

  @override
  Future<void> setInteractiveContentEnabled(bool enabled) async {}

  @override
  bool get sportsAlertsEnabled => true;

  @override
  Future<void> setSportsAlertsEnabled(bool enabled) async {}

  @override
  bool get weatherForecastEnabled => true;

  @override
  Future<void> setWeatherForecastEnabled(bool enabled) async {}
}

/// Convenience builders shared by the Sports tests.

/// An article with the minimum fields the tile needs.
Article buildArticle({
  required String id,
  required String title,
  String publisherName = 'Awoko Newspaper',
  DateTime? publishedAt,
}) {
  return Article(
    id: id,
    title: title,
    publisher: Publisher(id: 'awoko', name: publisherName, wordmark: 'AWOKO'),
    publishedAt: publishedAt ?? DateTime(2026, 10, 15, 18),
    categoryId: 'sports',
    summary: 'Match report and reaction.',
  );
}

/// A scoreboard fixture.
GameScore buildGame({
  required String id,
  String leagueLabel = 'NBA',
  Team? home,
  Team? away,
  GameStatus status = GameStatus.scheduled,
  int? homeScore,
  int? awayScore,
  DateTime? startsAt,
  String? periodLabel,
}) {
  return GameScore(
    id: id,
    leagueLabel: leagueLabel,
    home:
        home ??
        const Team(id: 'team:lal', name: 'Los Angeles Lakers', code: 'LAL'),
    away:
        away ?? const Team(id: 'team:bos', name: 'Boston Celtics', code: 'BOS'),
    status: status,
    homeScore: homeScore,
    awayScore: awayScore,
    startsAt: startsAt,
    periodLabel: periodLabel,
  );
}
