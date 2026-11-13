import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/article_cache.dart';
import '../data/local/preferences_store.dart';
import '../data/seed/seed_loader.dart';
import '../data/seed/video_seed.dart';
import '../data/sources/api_client.dart';
import '../push/push_service.dart';
import '../data/sources/sponsorship_tracker.dart';
import '../data/sources/feed_source.dart';
import '../data/sources/espn_source.dart';
import '../data/sources/league_news_source.dart';
import '../data/sources/market_rate_source.dart';
import '../data/sources/sl_news_video_source.dart';
import '../domain/models/ad_unit.dart';
import '../domain/models/market_snapshot.dart';
import '../domain/models/article.dart';
import '../domain/sports_ranking.dart';
import '../domain/models/follow_models.dart';
import '../domain/models/notification_item.dart';
import '../domain/models/sports_models.dart';
import '../domain/models/video_moment.dart';
import '../domain/models/weather_snapshot.dart';
import '../domain/repositories/ad_repository.dart';
import '../domain/repositories/article_repository.dart';
import '../domain/repositories/following_repository.dart';
import '../domain/repositories/notification_repository.dart';
import '../domain/repositories/sports_repository.dart';
import '../domain/repositories/user_state_repository.dart';
import '../domain/repositories/weather_repository.dart';
import '../data/sources/index_quote_source.dart';
import '../domain/models/index_quote.dart';

import 'package:slnews_mobile/core/utils/app_log.dart';

/// Infrastructure providers.
///
/// Every dependency of the app is declared here and supplied by `AppBootstrap`
/// (production) or by `overrideWithValue` in tests. Nothing in this file
/// performs I/O at declaration time, so importing it from a test is free.
///
/// Family providers are intentionally left untyped: Riverpod 3 marks the
/// concrete family classes `@internal`, so `final x = FutureProvider.family(...)`
/// is the supported spelling.
final Provider<PreferencesStore> preferencesStoreProvider =
    Provider<PreferencesStore>(
      (Ref ref) => throw UnimplementedError(
        'preferencesStoreProvider must be overridden by AppBootstrap',
      ),
      name: 'preferencesStore',
    );

final Provider<ArticleCache> articleCacheProvider = Provider<ArticleCache>(
  (Ref ref) => throw UnimplementedError(
    'articleCacheProvider must be overridden by AppBootstrap',
  ),
  name: 'articleCache',
);

final Provider<SeedLoader> seedLoaderProvider = Provider<SeedLoader>(
  (Ref ref) => throw UnimplementedError(
    'seedLoaderProvider must be overridden by AppBootstrap',
  ),
  name: 'seedLoader',
);

final Provider<EspnSource> espnSourceProvider = Provider<EspnSource>(
  (Ref ref) => EspnSource(client: ref.watch(apiClientProvider)),
  name: 'espnSource',
);

final Provider<LeagueNewsSource> leagueNewsSourceProvider =
    Provider<LeagueNewsSource>(
      (Ref ref) => LeagueNewsSource(client: ref.watch(apiClientProvider)),
      name: 'leagueNewsSource',
    );

/// League-specific news feed (Yahoo/Google), empty offline or in tests.
final leagueNewsProvider = FutureProvider.family<List<Article>, String>((
  Ref ref,
  String leagueId,
) async {
  if (!const bool.fromEnvironment('THESPORTSDB_ENABLED')) {
    return const <Article>[];
  }
  return ref.watch(leagueNewsSourceProvider).fetch(leagueId);
}, name: 'leagueNews');

/// Live news for a followed team ESPN covers; empty when unsupported/offline.
final teamNewsProvider = FutureProvider.family<List<Article>, String>((
  Ref ref,
  String teamId,
) async {
  // Tests and key-less builds stay offline when live sports are disabled.
  if (!const bool.fromEnvironment('THESPORTSDB_ENABLED')) {
    return const <Article>[];
  }
  if (!EspnSource.supportsTeamId(teamId)) return const <Article>[];
  return ref.watch(espnSourceProvider).teamNews(teamId);
}, name: 'teamNews');

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>(
  (Ref ref) => throw UnimplementedError(
    'apiClientProvider must be overridden by AppBootstrap',
  ),
  name: 'apiClient',
);

/// The configured ingest pipeline (RSS + REST + JSON endpoints).
final Provider<List<FeedSource>> feedSourcesProvider =
    Provider<List<FeedSource>>(
      (Ref ref) => throw UnimplementedError(
        'feedSourcesProvider must be overridden by AppBootstrap',
      ),
      name: 'feedSources',
    );

final Provider<ArticleRepository> articleRepositoryProvider =
    Provider<ArticleRepository>(
      (Ref ref) => throw UnimplementedError(
        'articleRepositoryProvider must be overridden by AppBootstrap',
      ),
      name: 'articleRepository',
    );

final Provider<SportsRepository> sportsRepositoryProvider =
    Provider<SportsRepository>(
      (Ref ref) => throw UnimplementedError(
        'sportsRepositoryProvider must be overridden by AppBootstrap',
      ),
      name: 'sportsRepository',
    );

final Provider<FollowingRepository> followingRepositoryProvider =
    Provider<FollowingRepository>(
      (Ref ref) => throw UnimplementedError(
        'followingRepositoryProvider must be overridden by AppBootstrap',
      ),
      name: 'followingRepository',
    );

final Provider<NotificationRepository> notificationRepositoryProvider =
    Provider<NotificationRepository>(
      (Ref ref) => throw UnimplementedError(
        'notificationRepositoryProvider must be overridden by AppBootstrap',
      ),
      name: 'notificationRepository',
    );

final Provider<WeatherRepository> weatherRepositoryProvider =
    Provider<WeatherRepository>(
      (Ref ref) => throw UnimplementedError(
        'weatherRepositoryProvider must be overridden by AppBootstrap',
      ),
      name: 'weatherRepository',
    );

/// Posts sold-unit impression/tap counters; overridden by AppBootstrap.
final Provider<SponsorshipTracker> sponsorshipTrackerProvider =
    Provider<SponsorshipTracker>(
      (Ref ref) => throw UnimplementedError(
        'sponsorshipTrackerProvider must be overridden by AppBootstrap',
      ),
      name: 'sponsorshipTracker',
    );

/// Device registration for breaking-news pushes; overridden by AppBootstrap.
final Provider<PushService> pushServiceProvider = Provider<PushService>(
  (Ref ref) => throw UnimplementedError(
    'pushServiceProvider must be overridden by AppBootstrap',
  ),
  name: 'pushService',
);

final Provider<AdRepository> adRepositoryProvider = Provider<AdRepository>(
  (Ref ref) => throw UnimplementedError(
    'adRepositoryProvider must be overridden by AppBootstrap',
  ),
  name: 'adRepository',
);

final Provider<UserStateRepository> userStateProvider =
    Provider<UserStateRepository>(
      (Ref ref) => throw UnimplementedError(
        'userStateProvider must be overridden by AppBootstrap',
      ),
      name: 'userState',
    );

/// Breaking/staff-picked stories for the For You hero carousel.
final topStoriesProvider = FutureProvider<List<Article>>(
  (Ref ref) => ref.watch(articleRepositoryProvider).topStories(),
  name: 'topStories',
);

/// Latest stories for a category slug.
final categoryFeedProvider = FutureProvider.family<List<Article>, String>((
  Ref ref,
  String categoryId,
) async {
  final ArticleRepository repository = ref.watch(articleRepositoryProvider);
  if (categoryId != 'sports') {
    return repository.byCategory(categoryId);
  }
  // Fetch a wider window, rank local Sierra Leone sport first, then cap. The
  // repository's own limit would otherwise let wires fill all 30 slots.
  final List<Article> pool = await repository.byCategory(
    categoryId,
    limit: 120,
  );
  return rankSportsStories(pool).take(30).toList(growable: false);
}, name: 'categoryFeed');

/// Stories for a followed location (`city:freetown`, ...).
final locationFeedProvider = FutureProvider.family<List<Article>, String>(
  (Ref ref, String locationId) =>
      ref.watch(articleRepositoryProvider).byLocation(locationId),
  name: 'locationFeed',
);

/// Story for the reader route; resolves to `null` when unknown.
final articleProvider = FutureProvider.family<Article?, String>(
  (Ref ref, String id) => ref.watch(articleRepositoryProvider).byId(id),
  name: 'article',
);

/// Full-text search results.
final searchResultsProvider = FutureProvider.family<List<Article>, String>(
  (Ref ref, String query) => ref.watch(articleRepositoryProvider).search(query),
  name: 'searchResults',
);

/// Live/recent fixtures for the Sports tab.
final scoreboardProvider = FutureProvider<ScoreboardSnapshot>(
  (Ref ref) => ref.watch(sportsRepositoryProvider).scoreboard(limit: 40),
  name: 'scoreboard',
);

/// Fixtures for one followed team.
final teamGamesProvider = FutureProvider.family<List<GameScore>, String>(
  (Ref ref, String teamId) =>
      ref.watch(sportsRepositoryProvider).gamesForTeam(teamId),
  name: 'teamGames',
);

/// Standings for one league.
final standingsProvider = FutureProvider.family<List<TeamStanding>, String>(
  (Ref ref, String leagueId) =>
      ref.watch(sportsRepositoryProvider).standings(leagueId),
  name: 'standings',
);

/// Ad rotation for a placement key (`sports_stream`, `feed`).
final adUnitsProvider = FutureProvider.family<List<AdUnit>, String>(
  (Ref ref, String placement) =>
      ref.watch(adRepositoryProvider).units(placement: placement),
  name: 'adUnits',
);

/// Notification history (declared here so both the Following page and the
/// badge in the shell can read it without importing controllers).
final notificationsProvider = FutureProvider<List<NotificationItem>>(
  (Ref ref) => ref.watch(notificationRepositoryProvider).history(),
  name: 'notifications',
);

/// Weather for the active location.
///
/// The location id is read from the persisted user state rather than from
/// `settingsControllerProvider`, which lives in `controllers.dart` and would
/// create an import cycle. `SettingsController.setActiveLocation` invalidates
/// this provider when the reader switches cities.
final activeWeatherProvider = FutureProvider<WeatherSnapshot>((Ref ref) {
  final String locationId = ref.watch(userStateProvider).activeLocationId;
  final NewsLocation location = SlLocations.all.firstWhere(
    (NewsLocation candidate) => candidate.id == locationId,
    orElse: () => SlLocations.fallback,
  );
  return ref.watch(weatherRepositoryProvider).current(location);
}, name: 'activeWeather');

/// The reader's active location, resolved from persisted state.
final activeLocationProvider = Provider<NewsLocation>((Ref ref) {
  final String locationId = ref.watch(userStateProvider).activeLocationId;
  return SlLocations.all.firstWhere(
    (NewsLocation candidate) => candidate.id == locationId,
    orElse: () => SlLocations.fallback,
  );
}, name: 'activeLocation');

/// Category selected in the News tab; app-level so it survives tab switches.
final NotifierProvider<SelectedCategoryController, String>
selectedCategoryProvider = NotifierProvider<SelectedCategoryController, String>(
  SelectedCategoryController.new,
  name: 'selectedCategory',
);

class SelectedCategoryController extends Notifier<String> {
  @override
  String build() => 'top';

  void select(String categoryId) => state = categoryId;
}

/// Reads the "Video moments" rail from the scraper API.
///
/// `null` when the build has no key; [videoMomentsProvider] then serves the
/// bundled rotation. AppBootstrap overrides this once it has an ApiClient.
final Provider<SlNewsVideoSource?> slNewsVideoSourceProvider =
    Provider<SlNewsVideoSource?>((Ref ref) => null, name: 'slNewsVideoSource');

const String _videoCacheKey = 'video_moments.cache.v1';

/// Video moments for the For You rail.
///
/// Builds synchronously from the last payload written to preferences (or the
/// bundled rotation on a first launch), then refreshes from the API in the
/// background. A cold Render instance therefore never delays the rail.
final NotifierProvider<VideoMomentsController, List<VideoMoment>>
videoMomentsProvider =
    NotifierProvider<VideoMomentsController, List<VideoMoment>>(
      VideoMomentsController.new,
      name: 'videoMoments',
    );

class VideoMomentsController extends Notifier<List<VideoMoment>> {
  @override
  List<VideoMoment> build() {
    final List<VideoMoment> cached = _readCache();
    Future<void>.microtask(_refresh);
    return cached;
  }

  List<VideoMoment> _readCache() {
    try {
      final String? raw = ref
          .read(preferencesStoreProvider)
          .string(_videoCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final Object? decoded = jsonDecode(raw);
        if (decoded is List && decoded.isNotEmpty) {
          final List<VideoMoment> cached = <VideoMoment>[
            for (final Object? row in decoded)
              if (row is Map) VideoMoment.fromJson(row.cast<String, dynamic>()),
          ].where((VideoMoment v) => v.id.isNotEmpty).toList();
          if (cached.isNotEmpty) return cached;
        }
      }
    } catch (error) {
      AppLog.debug('videoMoments: unreadable cache: $error');
    }
    // A configured build must never present demo clips as if they were real
    // videos: show nothing until the first successful fetch.
    return ref.read(slNewsVideoSourceProvider) == null
        ? SlVideos.all
        : const <VideoMoment>[];
  }

  Future<void> _refresh() async {
    final SlNewsVideoSource? source = ref.read(slNewsVideoSourceProvider);
    if (source == null) return;
    final List<VideoMoment> live = await source.latest(limit: 30);
    if (live.isEmpty) return;
    state = live;
    try {
      await ref
          .read(preferencesStoreProvider)
          .putString(
            _videoCacheKey,
            jsonEncode(<Map<String, dynamic>>[
              for (final VideoMoment v in live) v.toJson(),
            ]),
          );
    } catch (error) {
      AppLog.debug('videoMoments: could not cache: $error');
    }
  }
}

/// Ads rotated into the For You feed, one per section break.
final FutureProvider<List<AdUnit>> forYouAdsProvider =
    FutureProvider<List<AdUnit>>(
      (Ref ref) => ref.watch(adRepositoryProvider).units(placement: 'feed'),
      name: 'forYouAds',
    );

/// Reads the Markets currency board.
///
/// Keyless endpoint, so the only dependency is the shared [ApiClient] that
/// AppBootstrap already owns (and every test already overrides/replaces).
final Provider<MarketRateSource> marketRateSourceProvider =
    Provider<MarketRateSource>(
      (Ref ref) => MarketRateSource(ref.watch(apiClientProvider)),
      name: 'marketRateSource',
    );

/// Preference key holding the last board we managed to read.
const String marketCacheKey = 'markets.lastSnapshot';

/// The Markets board for the interactive card: fresh rates when the service
/// answers, otherwise the last board we saw, otherwise `null`.
///
/// Never throws: the module is a bonus surface, so an offline reader sees the
/// most recent rates (with their timestamp) instead of an error.
final FutureProvider<MarketSnapshot?> marketSnapshotProvider =
    FutureProvider<MarketSnapshot?>((Ref ref) async {
      PreferencesStore? store;
      try {
        store = ref.watch(preferencesStoreProvider);
      } on UnimplementedError {
        // A bare test scope without storage: still useful, just uncached.
        store = null;
      }

      final MarketSnapshot? cached = _cachedBoard(store);
      final MarketSnapshot? fresh = await ref
          .watch(marketRateSourceProvider)
          .fetch();
      if (fresh != null) {
        if (store != null) {
          await store.putString(marketCacheKey, jsonEncode(fresh.toJson()));
        }
        return fresh;
      }
      return cached;
    }, name: 'marketSnapshot');

MarketSnapshot? _cachedBoard(PreferencesStore? store) {
  final String? raw = store?.string(marketCacheKey);
  if (raw == null || raw.isEmpty) return null;
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is Map) {
      return MarketSnapshot.fromJson(<String, dynamic>{
        for (final MapEntry<Object?, Object?> entry in decoded.entries)
          '${entry.key}': entry.value,
      });
    }
  } catch (error) {
    AppLog.debug('marketSnapshot: cached board unreadable ($error)');
  }
  return null;
}

/// Reads the Stocks index board (keyless chart endpoint, cached).
final Provider<IndexQuoteSource> indexQuoteSourceProvider =
    Provider<IndexQuoteSource>(
      (Ref ref) => IndexQuoteSource(ref.watch(apiClientProvider)),
      name: 'indexQuoteSource',
    );

/// Preference key holding the last index board we managed to read.
const String indexBoardCacheKey = 'stocks.lastBoard';

/// The board for the Stocks section and page: fresh quotes when the service
/// answers, otherwise the last board we saw, otherwise `null` (the section then
/// hides instead of inventing numbers).
final FutureProvider<IndexBoard?> indexBoardProvider =
    FutureProvider<IndexBoard?>((Ref ref) async {
      PreferencesStore? store;
      try {
        store = ref.watch(preferencesStoreProvider);
      } on UnimplementedError {
        store = null;
      }

      IndexBoard? cached;
      final String? raw = store?.string(indexBoardCacheKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final Object? decoded = jsonDecode(raw);
          if (decoded is Map) {
            cached = IndexBoard.fromJson(<String, dynamic>{
              for (final MapEntry<Object?, Object?> entry in decoded.entries)
                '${entry.key}': entry.value,
            });
          }
        } catch (error) {
          AppLog.debug('indexBoard: cached board unreadable ($error)');
        }
      }

      final IndexBoard? fresh = await ref
          .watch(indexQuoteSourceProvider)
          .fetch();
      if (fresh != null) {
        if (store != null) {
          await store.putString(indexBoardCacheKey, jsonEncode(fresh.toJson()));
        }
        return fresh;
      }
      return cached;
    }, name: 'indexBoard');
