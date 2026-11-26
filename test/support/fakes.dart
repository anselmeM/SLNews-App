/// The app's single set of in-memory repository doubles.
///
/// Every feature used to carry its own copy, and they drifted: the feed copy
/// ignored `byCategory`'s argument, the news copy returned empty search results,
/// and the sports copy could not serve `byId`. A test could pass against one copy
/// while the production wiring was broken. This file is the one implementation
/// now — feature `support/fakes.dart` files re-export it (plus their own fixture
/// builders), so call sites keep their existing imports.
///
/// Everything is synchronous state behind `Future`-returning interfaces: tests
/// never touch Hive, dio or the network.
library;

import 'dart:async';

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
  List<String> tags = const <String>[],
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
    tags: tags,
  );
}

/// A single house ad unit for the in-stream slot.
const AdUnit kFakeFeedAd = AdUnit(
  id: 'ad-feed-1',
  headline: 'CLAIM YOUR REWARD',
  body: 'Top up any mobile wallet in Sierra Leone and get cash back.',
  ctaLabel: 'View more',
  advertiser: 'Orange Money',
  assetLabel: r'$20',
  disclosure: 'Sponsored content. Terms apply.',
);

/// In-memory [ArticleRepository] driven by the lists a test hands it.
///
/// `byCategory` honours the slug (a per-category map, then one shared
/// `categoryStories` list as the fallback), `byId` searches everything, and
/// `search` matches titles across every known story. The older copies each got
/// one of those wrong.
// ignore_for_file: prefer_initializing_formals
class FakeArticleRepository implements ArticleRepository {
  FakeArticleRepository({
    List<Article> topStories = const <Article>[],
    List<Article> localStories = const <Article>[],
    List<Article> categoryStories = const <Article>[],
    Map<String, List<Article>>? feeds,
    Map<String, List<Article>>? byCategory,
    this.isOffline = false,
    this.lastSyncedAt,
    this.failTopStories = false,
  }) : _topStories = topStories,
       _localStories = localStories,
       _categoryStories = categoryStories,
       feeds = feeds ?? byCategory ?? <String, List<Article>>{};

  /// Mutable so a test can swap the top stories between pumps.
  List<Article> _topStories;

  final List<Article> _localStories;
  final List<Article> _categoryStories;

  /// Category slug -> stories; also the store behind [seed].
  final Map<String, List<Article>> feeds;

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
    for (final List<Article> stories in feeds.values) ...stories,
  ];

  void setTopStories(List<Article> articles) => _topStories = articles;

  /// Seeds one category's feed, e.g. `seed('business', <Article>[...])`.
  void seed(String categoryId, List<Article> articles) =>
      feeds[categoryId] = articles;

  @override
  Future<List<Article>> topStories({int limit = 8}) async {
    if (failTopStories) throw StateError('offline');
    final List<Article> stories = feeds['top'] ?? _topStories;
    return stories.take(limit).toList(growable: false);
  }

  @override
  Future<List<Article>> byCategory(String categoryId, {int limit = 30}) async {
    if (failTopStories) throw StateError('offline');
    final List<Article> stories = feeds[categoryId] ?? _categoryStories;
    return stories.take(limit).toList(growable: false);
  }

  @override
  Future<List<Article>> byPublisher(
    String publisherId, {
    int limit = 30,
  }) async {
    final List<Article> rows = <Article>[
      for (final Article article in all)
        if (article.publisher.id == publisherId) article,
    ]..sort((Article a, Article b) => b.publishedAt.compareTo(a.publishedAt));
    return rows.take(limit).toList(growable: false);
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
    return feeds['top'] ?? _topStories;
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
  bool followedTopicAlertsEnabled = true;

  @override
  Future<void> setFollowedTopicAlertsEnabled(bool enabled) async =>
      followedTopicAlertsEnabled = enabled;

  @override
  bool onboardingCompleted = false;

  @override
  Future<void> setOnboardingCompleted(bool completed) async =>
      onboardingCompleted = completed;

  @override
  bool weatherForecastEnabled = true;

  @override
  Future<void> setWeatherForecastEnabled(bool enabled) async =>
      weatherForecastEnabled = enabled;

  @override
  bool personalizeFeed = true;

  /// Optional gate for testing rapid settings taps.
  Completer<void>? personalizeGate;

  /// Optional injected failure/success behavior for preference writes.
  Future<void> Function(bool enabled)? personalizeWriter;

  @override
  Future<void> setPersonalizeFeed(bool enabled) async {
    final Future<void> Function(bool enabled)? writer = personalizeWriter;
    if (writer != null) {
      await writer(enabled);
      personalizeFeed = enabled;
      return;
    }
    final Completer<void>? gate = personalizeGate;
    if (gate != null) await gate.future;
    personalizeFeed = enabled;
  }

  final Map<String, String> digestCache = <String, String>{};

  @override
  String? digestPreferencesFor(String accountId) => digestCache[accountId];

  @override
  Future<void> setDigestPreferencesFor(String accountId, String json) async =>
      digestCache[accountId] = json;
}

/// Deterministic weather; `throwOnCurrent` exercises the header fallback.
class FakeWeatherRepository implements WeatherRepository {
  FakeWeatherRepository({
    this.throwOnCurrent = false,
    this.snapshot,
    this.pending,
  });

  bool throwOnCurrent;

  /// Returned as-is when set, including a deliberately stale location.
  final WeatherSnapshot? snapshot;

  /// When set, the forecast stays loading until the test completes it.
  final Completer<WeatherSnapshot>? pending;

  @override
  Future<WeatherSnapshot> current(NewsLocation location) async {
    if (throwOnCurrent) throw StateError('no weather');
    final Completer<WeatherSnapshot>? gate = pending;
    if (gate != null) return gate.future;
    return snapshot ??
        WeatherSnapshot(
          locationLabel: location.label,
          locationId: location.id,
          temperatureC: 29,
          conditionLabel: 'Thundery showers',
          glyph: 'storm',
          updatedAt: DateTime(2026, 10, 15, 9),
        );
  }
}

/// In-memory [SportsRepository] backed by literal fixtures.
class FakeSportsRepository implements SportsRepository {
  FakeSportsRepository({
    ScoreboardSnapshot? scoreboard,
    Map<String, List<GameScore>>? gamesByTeam,
    Map<String, List<TeamStanding>>? standingsByLeague,
    this.error,
  }) : _standingsByLeague = standingsByLeague ?? <String, List<TeamStanding>>{},
       _scoreboard =
           scoreboard ??
           ScoreboardSnapshot(
             games: const <GameScore>[],
             providerLabel: 'test',
             updatedAt: DateTime(2026, 10, 15),
           ),
       _gamesByTeam = gamesByTeam ?? <String, List<GameScore>>{};

  final ScoreboardSnapshot _scoreboard;
  final Map<String, List<GameScore>> _gamesByTeam;
  final Map<String, List<TeamStanding>> _standingsByLeague;

  /// When set, [scoreboard] throws it — used for the degraded-state tests.
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
      _standingsByLeague[leagueId] ?? const <TeamStanding>[];
}

/// In-memory [FollowingRepository].
///
/// Accepts either a catalogue (the feed tests follow targets from it) or a
/// ready snapshot (the sports tests start from a followed set).
class FakeFollowingRepository implements FollowingRepository {
  FakeFollowingRepository({
    List<FollowTarget> catalogue = const <FollowTarget>[],
    FollowingSnapshot? snapshot,
  }) : _catalogue = catalogue,
       _snapshot =
           snapshot ??
           FollowingSnapshot(
             followed: const <FollowTarget>[],
             suggested: const <FollowTarget>[],
             topics: <FollowTarget>[
               for (final FollowTarget target in catalogue)
                 if (target.kind == FollowKind.topic) target,
             ],
           );

  final List<FollowTarget> _catalogue;
  FollowingSnapshot _snapshot;

  @override
  List<FollowTarget> get catalogue => _catalogue;

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

/// In-memory notification history.
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

/// In-memory ad rotation.
///
/// Accepts the feed style (`rotation`), the sports style (`units`) and the news
/// style (`unitsForPlacement` / [FakeAdRepository.feed]).
class FakeAdRepository implements AdRepository {
  FakeAdRepository({
    List<AdUnit> rotation = const <AdUnit>[],
    List<AdUnit>? units,
    Map<String, List<AdUnit>> unitsForPlacement =
        const <String, List<AdUnit>>{},
  }) : _rotation = units ?? rotation,
       _unitsForPlacement = unitsForPlacement;

  /// Convenience for the common "one unit in the feed slot" case.
  factory FakeAdRepository.feed(List<AdUnit> units) => FakeAdRepository(
    unitsForPlacement: <String, List<AdUnit>>{'feed': units},
  );

  final List<AdUnit> _rotation;
  final Map<String, List<AdUnit>> _unitsForPlacement;

  /// Placement keys requested through [units], in call order.
  ///
  /// Lets a widget test prove which server slot a surface actually asked for
  /// (for example News must request `news_stream`, not `feed`).
  final List<String> requestedPlacements = <String>[];

  @override
  Future<List<AdUnit>> units({String placement = 'default'}) async {
    requestedPlacements.add(placement);
    return _unitsForPlacement[placement] ?? _rotation;
  }

  @override
  List<AdUnit> get cachedUnits => _rotation;
}
