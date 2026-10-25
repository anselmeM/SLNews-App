import 'package:slnews_mobile/core/domain/models/ad_unit.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/publisher.dart';
import 'package:slnews_mobile/core/domain/repositories/ad_repository.dart';
import 'package:slnews_mobile/core/domain/repositories/article_repository.dart';
import 'package:slnews_mobile/core/domain/repositories/user_state_repository.dart';

/// In-memory fakes for the News feature tests.
///
/// The shared `test/support/fakes.dart` does not exist yet (the Lead owns it),
/// so the News tests carry their own: three tiny implementations of the frozen
/// repository interfaces, no I/O, no async delays beyond a completed `Future`.
///
/// Articles deliberately ship a `null` [Article.imageUrl] so `SlNetworkImage`
/// renders its local placeholder and the widget tests never touch the network.

/// Publisher used by every fixture story.
const Publisher kFakePublisher = Publisher(
  id: 'slnews',
  name: 'SLNews Desk',
  wordmark: 'SLNEWS',
  country: 'Sierra Leone',
);

/// A fixed clock so relative-age labels stay deterministic.
final DateTime kFakeNow = DateTime(2026, 10, 15, 12);

/// Builds a fixture story in [categoryId], [minutesAgo] minutes before
/// [kFakeNow].
Article fakeArticle({
  required String id,
  required String title,
  String categoryId = 'top',
  int minutesAgo = 0,
  bool isBreaking = false,
  bool isLive = false,
  String summary = '',
  String? imageUrl,
}) {
  return Article(
    id: id,
    title: title,
    summary: summary,
    publisher: kFakePublisher,
    publishedAt: kFakeNow.subtract(Duration(minutes: minutesAgo)),
    categoryId: categoryId,
    isBreaking: isBreaking,
    isLive: isLive,
  );
}

/// A Sierra Leonean headline comfortably over 60 characters, used to prove the
/// cards ellipsize instead of clipping.
const String kLongHeadline =
    'Freetown City Council unveils a new drainage master plan for the central business district';

/// The fixture feed: `top` has a hero, a grid and enough rows for the inline ad
/// slot; `politics` has its own hero; every other category is empty so the empty
/// state is reachable from the pill strip.
Map<String, List<Article>> defaultNewsFixtures() => <String, List<Article>>{
  'top': <Article>[
    fakeArticle(
      id: 'top-hero',
      title:
          'Bo government hospital receives new dialysis machines from partners',
      summary:
          'The donation covers two years of consumables for the renal unit.',
    ),
    for (int index = 2; index <= 11; index++)
      fakeArticle(
        id: 'top-$index',
        title:
            'Sierra Leone news desk story number $index from the overnight wire',
        minutesAgo: index * 20,
      ),
  ],
  'politics': <Article>[
    fakeArticle(
      id: 'politics-hero',
      title: 'Parliament passes the 2026 budget after a marathon overnight sitting',
      categoryId: 'politics',
    ),
    for (int index = 2; index <= 8; index++)
      fakeArticle(
        id: 'politics-$index',
        title:
            'Politics desk follow-up $index on the budget debate in Freetown',
        categoryId: 'politics',
        minutesAgo: index * 15,
      ),
  ],
};

/// Hand-written [ArticleRepository] backed by a `categoryId -> stories` map.
class FakeArticleRepository implements ArticleRepository {
  FakeArticleRepository({
    Map<String, List<Article>>? byCategory,
    this.topStoryLimit = 8,
  }) : _byCategory = byCategory ?? const <String, List<Article>>{};

  final Map<String, List<Article>> _byCategory;

  /// Recorded so a test can assert the requested page size.
  final int topStoryLimit;

  /// Every `byCategory` call, in order â€” used by the refresh/retry tests.
  final List<String> categoryRequests = <String>[];

  int refreshCount = 0;

  @override
  Future<List<Article>> byCategory(String categoryId, {int limit = 30}) async {
    categoryRequests.add(categoryId);
    final List<Article> stories = _byCategory[categoryId] ?? const <Article>[];
    return stories.take(limit).toList(growable: false);
  }

  @override
  Future<List<Article>> topStories({int limit = 8}) async {
    final List<Article> stories = _byCategory['top'] ?? const <Article>[];
    return stories.take(limit).toList(growable: false);
  }

  @override
  Future<List<Article>> byLocation(String locationId, {int limit = 20}) async =>
      const <Article>[];

  @override
  Future<Article?> byId(String id) async {
    for (final List<Article> stories in _byCategory.values) {
      for (final Article story in stories) {
        if (story.id == id) {
          return story;
        }
      }
    }
    return null;
  }

  @override
  Future<List<Article>> search(String query, {int limit = 20}) async =>
      const <Article>[];

  @override
  Future<List<Article>> refresh() async {
    refreshCount++;
    return const <Article>[];
  }

  @override
  bool get isOffline => false;

  @override
  DateTime? get lastSyncedAt => kFakeNow;
}

/// Hand-written [AdRepository] returning one unit per placement, or nothing.
class FakeAdRepository implements AdRepository {
  FakeAdRepository({this.unitsForPlacement = const <String, List<AdUnit>>{}});

  /// Rotation per placement key (`feed`, `sports_stream`, ...).
  final Map<String, List<AdUnit>> unitsForPlacement;

  /// Convenience for the common "one unit in the feed slot" case.
  factory FakeAdRepository.feed(List<AdUnit> units) => FakeAdRepository(
    unitsForPlacement: <String, List<AdUnit>>{'feed': units},
  );

  @override
  List<AdUnit> get cachedUnits => const <AdUnit>[];

  @override
  Future<List<AdUnit>> units({String placement = 'default'}) async =>
      unitsForPlacement[placement] ?? const <AdUnit>[];
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

/// Hand-written [UserStateRepository] whose entire state is in memory.
class FakeUserStateRepository implements UserStateRepository {
  final Set<String> _bookmarks = <String>{};
  final Set<String> _likes = <String>{};

  String _themeMode = 'system';
  double _textScale = 1;
  String _activeLocationId = 'city:freetown';
  bool _breakingAlerts = true;

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
    if (!_bookmarks.remove(articleId)) {
      _bookmarks.add(articleId);
    }
  }

  @override
  Future<void> toggleLike(String articleId) async {
    if (!_likes.remove(articleId)) {
      _likes.add(articleId);
    }
  }

  @override
  String get themeMode => _themeMode;

  @override
  Future<void> setThemeMode(String mode) async => _themeMode = mode;

  @override
  double get textScale => _textScale;

  @override
  Future<void> setTextScale(double scale) async => _textScale = scale;

  @override
  String get activeLocationId => _activeLocationId;

  @override
  Future<void> setActiveLocationId(String locationId) async =>
      _activeLocationId = locationId;

  @override
  bool get breakingNewsAlertsEnabled => _breakingAlerts;

  @override
  Future<void> setBreakingNewsAlertsEnabled(bool enabled) async =>
      _breakingAlerts = enabled;

  bool _editorsPicks = false;
  bool _interactiveContent = true;
  bool _sportsAlerts = true;
  bool _weatherForecast = true;

  @override
  bool get editorsPicksEnabled => _editorsPicks;

  @override
  Future<void> setEditorsPicksEnabled(bool enabled) async =>
      _editorsPicks = enabled;

  @override
  bool get interactiveContentEnabled => _interactiveContent;

  @override
  Future<void> setInteractiveContentEnabled(bool enabled) async =>
      _interactiveContent = enabled;

  @override
  bool get sportsAlertsEnabled => _sportsAlerts;

  @override
  Future<void> setSportsAlertsEnabled(bool enabled) async =>
      _sportsAlerts = enabled;
  @override
  bool get followedTopicAlertsEnabled => true;

  @override
  Future<void> setFollowedTopicAlertsEnabled(bool enabled) async {}

  bool _onboardingCompleted = false;

  @override
  bool get onboardingCompleted => _onboardingCompleted;

  @override
  Future<void> setOnboardingCompleted(bool completed) async =>
      _onboardingCompleted = completed;

  @override
  bool get weatherForecastEnabled => _weatherForecast;

  @override
  Future<void> setWeatherForecastEnabled(bool enabled) async =>
      _weatherForecast = enabled;
}
