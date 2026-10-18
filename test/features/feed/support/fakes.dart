import 'package:slnews_mobile/core/domain/models/ad_unit.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/domain/models/notification_item.dart';
import 'package:slnews_mobile/core/domain/models/publisher.dart';
import 'package:slnews_mobile/core/domain/models/sports_models.dart';
import 'package:slnews_mobile/core/domain/models/weather_snapshot.dart';
import 'package:slnews_mobile/core/domain/repositories/ad_repository.dart';
import 'package:slnews_mobile/core/domain/repositories/article_repository.dart';
import 'package:slnews_mobile/core/domain/repositories/following_repository.dart';
import 'package:slnews_mobile/core/domain/repositories/notification_repository.dart';
import 'package:slnews_mobile/core/domain/repositories/sports_repository.dart';
import 'package:slnews_mobile/core/domain/repositories/user_state_repository.dart';
import 'package:slnews_mobile/core/domain/repositories/weather_repository.dart';

/// In-memory test doubles for every frozen repository interface.
///
/// The Feed agent owns these because `test/support/fakes.dart` is not created
/// by the Lead; everything is synchronous in-memory state with zero I/O so the
/// widget tests never touch Hive, `dio` or the network.

/// Shared outlet used by every fake article.
const Publisher testPublisher = Publisher(
  id: 'awoko',
  name: 'Awoko Newspaper',
  wordmark: 'AWOKO',
);

/// Builds a deterministic article; override only what a test cares about.
Article testArticle({
  required String id,
  String? title,
  DateTime? publishedAt,
  bool isBreaking = false,
  bool isLive = false,
  String? sourceUrl,
  String? author,
  String categoryId = 'top',
  String? imageUrl,
  String summary = '',
}) {
  return Article(
    id: id,
    title: title ?? 'Headline $id',
    summary: summary,
    publishedAt: publishedAt ?? DateTime(2026, 10, 15, 8),
    publisher: testPublisher,
    sourceUrl: sourceUrl,
    author: author,
    categoryId: categoryId,
    isBreaking: isBreaking,
    isLive: isLive,
    imageUrl: imageUrl,
  );
}

/// In-memory [ArticleRepository] driven by the lists a test hands it.
///
/// Fields are initialised in the constructor body rather than through
/// initializing formals because they are private and need defaults.
// ignore_for_file: prefer_initializing_formals
class FakeArticleRepository implements ArticleRepository {
  FakeArticleRepository({
    List<Article> topStories = const <Article>[],
    List<Article> localStories = const <Article>[],
    List<Article> categoryStories = const <Article>[],
    this.isOffline = false,
    this.lastSyncedAt,
    this.failTopStories = false,
  }) : _topStories = topStories,
       _localStories = localStories,
       _categoryStories = categoryStories;

  /// Mutable so a test can swap the top stories between pumps.
  List<Article> _topStories;

  final List<Article> _localStories;
  final List<Article> _categoryStories;

  @override
  bool isOffline;

  @override
  DateTime? lastSyncedAt;

  /// When true every stream throws, exercising the error branch.
  bool failTopStories;

  int refreshCount = 0;

  /// Every article this repository knows about, by id.
  Iterable<Article> get all => <Article>[
    ..._topStories,
    ..._localStories,
    ..._categoryStories,
  ];

  void setTopStories(List<Article> articles) => _topStories = articles;

  @override
  Future<List<Article>> topStories({int limit = 8}) async {
    if (failTopStories) throw StateError('offline');
    return _topStories.take(limit).toList(growable: false);
  }

  @override
  Future<List<Article>> byCategory(String categoryId, {int limit = 30}) async {
    if (failTopStories) throw StateError('offline');
    return _categoryStories.take(limit).toList(growable: false);
  }

  @override
  Future<List<Article>> byLocation(String locationId, {int limit = 20}) async {
    if (failTopStories) throw StateError('offline');
    return _localStories.take(limit).toList(growable: false);
  }

  @override
  Future<Article?> byId(String id) async {
    for (final Article article in all) {
      if (article.id == id) return article;
    }
    return null;
  }

  @override
  Future<List<Article>> search(String query, {int limit = 20}) async {
    final String needle = query.toLowerCase();
    return all
        .where(
          (Article article) => article.title.toLowerCase().contains(needle),
        )
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<List<Article>> refresh() async {
    refreshCount++;
    return _topStories;
  }
}

/// In-memory [UserStateRepository]; bookmark/like sets are plain mutable state.
class FakeUserStateRepository implements UserStateRepository {
  FakeUserStateRepository({
    Set<String>? bookmarkedIds,
    Set<String>? likedIds,
    this.activeLocationId = 'city:freetown',
    this.themeMode = 'system',
    this.textScale = 1,
    this.breakingNewsAlertsEnabled = true,
  }) : _bookmarkedIds = <String>{...?bookmarkedIds},
       _likedIds = <String>{...?likedIds};

  final Set<String> _bookmarkedIds;
  final Set<String> _likedIds;

  @override
  Set<String> get bookmarkedIds => Set<String>.unmodifiable(_bookmarkedIds);

  @override
  Set<String> get likedIds => Set<String>.unmodifiable(_likedIds);

  @override
  bool isBookmarked(String articleId) => _bookmarkedIds.contains(articleId);

  @override
  bool isLiked(String articleId) => _likedIds.contains(articleId);

  @override
  Future<void> toggleBookmark(String articleId) async {
    if (!_bookmarkedIds.remove(articleId)) _bookmarkedIds.add(articleId);
  }

  @override
  Future<void> toggleLike(String articleId) async {
    if (!_likedIds.remove(articleId)) _likedIds.add(articleId);
  }

  @override
  String themeMode;

  @override
  Future<void> setThemeMode(String mode) async => themeMode = mode;

  @override
  double textScale;

  @override
  Future<void> setTextScale(double scale) async => textScale = scale;

  @override
  String activeLocationId;

  @override
  Future<void> setActiveLocationId(String locationId) async =>
      activeLocationId = locationId;

  @override
  bool breakingNewsAlertsEnabled;

  @override
  Future<void> setBreakingNewsAlertsEnabled(bool enabled) async =>
      breakingNewsAlertsEnabled = enabled;

  @override
  bool editorsPicksEnabled = false;

  @override
  Future<void> setEditorsPicksEnabled(bool enabled) async =>
      editorsPicksEnabled = enabled;

  @override
  bool interactiveContentEnabled = true;

  @override
  Future<void> setInteractiveContentEnabled(bool enabled) async =>
      interactiveContentEnabled = enabled;

  @override
  bool sportsAlertsEnabled = true;

  @override
  Future<void> setSportsAlertsEnabled(bool enabled) async =>
      sportsAlertsEnabled = enabled;

  @override
  bool weatherForecastEnabled = true;

  @override
  Future<void> setWeatherForecastEnabled(bool enabled) async =>
      weatherForecastEnabled = enabled;
}

/// Deterministic weather; `throwOnCurrent` exercises the header fallback.
class FakeWeatherRepository implements WeatherRepository {
  FakeWeatherRepository({this.throwOnCurrent = false});

  final bool throwOnCurrent;

  @override
  Future<WeatherSnapshot> current(NewsLocation location) async {
    if (throwOnCurrent) throw StateError('no weather');
    return WeatherSnapshot(
      locationLabel: location.label,
      temperatureC: 29,
      conditionLabel: 'Thundery showers',
      glyph: 'storm',
      updatedAt: DateTime(2026, 10, 15, 9),
    );
  }
}

/// Empty standings/scoreboard double for pages that render the sports strip.
class FakeSportsRepository implements SportsRepository {
  @override
  Future<ScoreboardSnapshot> scoreboard({int limit = 8}) async =>
      ScoreboardSnapshot(
        games: const <GameScore>[],
        providerLabel: 'test',
        updatedAt: DateTime(2026, 10, 15),
      );

  @override
  Future<List<GameScore>> gamesForTeam(String teamId, {int limit = 10}) async =>
      const <GameScore>[];

  @override
  Future<List<TeamStanding>> standings(String leagueId) async =>
      const <TeamStanding>[];
}

/// Empty following double; the app bar reads nothing from it in these tests.
class FakeFollowingRepository implements FollowingRepository {
  final Set<String> _followed = <String>{};

  @override
  FollowingSnapshot load() => const FollowingSnapshot.empty();

  @override
  Future<FollowingSnapshot> follow(FollowTarget target) async {
    _followed.add(target.id);
    return const FollowingSnapshot.empty();
  }

  @override
  Future<FollowingSnapshot> unfollow(String targetId) async {
    _followed.remove(targetId);
    return const FollowingSnapshot.empty();
  }

  @override
  Future<FollowingSnapshot> toggle(FollowTarget target) async {
    if (!_followed.remove(target.id)) _followed.add(target.id);
    return const FollowingSnapshot.empty();
  }

  @override
  bool isFollowed(String targetId) => _followed.contains(targetId);
}

/// No-op notification double.
class FakeNotificationRepository implements NotificationRepository {
  final List<NotificationItem> _items = <NotificationItem>[];

  @override
  Future<List<NotificationItem>> history({int limit = 30}) async =>
      _items.take(limit).toList(growable: false);

  @override
  List<NotificationItem> get cachedHistory =>
      List<NotificationItem>.unmodifiable(_items);

  @override
  Future<void> record(NotificationItem item) async => _items.add(item);

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead() async {}

  @override
  int get unreadCount =>
      _items.where((NotificationItem item) => !item.isRead).length;
}

/// Empty ad rotation double.
class FakeAdRepository implements AdRepository {
  FakeAdRepository({this.rotation = const <AdUnit>[]});

  /// Units returned for every placement; empty means "no ad to show".
  final List<AdUnit> rotation;

  @override
  Future<List<AdUnit>> units({String placement = 'default'}) async => rotation;

  @override
  List<AdUnit> get cachedUnits => rotation;
}
