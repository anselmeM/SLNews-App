import 'dart:convert';

import 'package:flutter/foundation.dart';
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
import '../data/sources/notification_preferences_source.dart';
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

part 'app_providers_market.dart';

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

/// Whether public live sports feeds (league RSS, ESPN team news) may be
/// fetched. Tests override this to stay offline without relying on a compile
/// flag that is not reliable at runtime.
final Provider<bool> liveSportsFeedsProvider = Provider<bool>(
  (Ref ref) => true,
  name: 'liveSportsFeeds',
);

/// League-specific news feed (Yahoo/Google), empty offline or in tests.
final leagueNewsProvider = FutureProvider.family<List<Article>, String>((
  Ref ref,
  String leagueId,
) async {
  if (!ref.watch(liveSportsFeedsProvider)) return const <Article>[];
  return ref.watch(leagueNewsSourceProvider).fetch(leagueId);
}, name: 'leagueNews');

/// Live news for a followed team ESPN covers; empty when unsupported/offline.
final teamNewsProvider = FutureProvider.family<List<Article>, String>((
  Ref ref,
  String teamId,
) async {
  if (!ref.watch(liveSportsFeedsProvider)) return const <Article>[];
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

/// Writes digest preferences to the PWA API; null when this build has no sync
/// backend, in which case settings stay local and the UI hides no controls.
final Provider<DigestPreferencesGateway?>
notificationPreferencesSourceProvider = Provider<DigestPreferencesGateway?>(
  (Ref ref) => null,
  name: 'notificationPreferencesSource',
);

/// Breaking/staff-picked stories for the For You hero carousel.
final topStoriesProvider = FutureProvider<List<Article>>(
  (Ref ref) => ref.watch(articleRepositoryProvider).topStories(),
  name: 'topStories',
);

/// Latest stories for a category slug.
/// Latest stories from one publisher, for the publisher page.
final publisherArticlesProvider = FutureProvider.family<List<Article>, String>(
  (Ref ref, String publisherId) =>
      ref.watch(articleRepositoryProvider).byPublisher(publisherId),
  name: 'publisherArticles',
);

final categoryFeedProvider = FutureProvider.family<List<Article>, String>((
  Ref ref,
  String categoryId,
) async {
  final ArticleRepository repository = ref.watch(articleRepositoryProvider);
  if (categoryId != 'sports') {
    final List<Article> articles = await repository.byCategory(categoryId);
    if (articles.isNotEmpty || categoryId == 'top') return articles;
    // A category can be temporarily empty when every matching live item is
    // older than the current feed window. Never leave the tab blank; show the
    // latest news under the category heading until dedicated items arrive.
    return repository.topStories(limit: 30);
  }
  // Fetch a wider window, rank local Sierra Leone sport first, then cap. The
  // repository's own limit would otherwise let wires fill all 30 slots.
  final List<Article> pool = await repository.byCategory(
    categoryId,
    limit: 120,
  );
  final List<Article> ranked = rankSportsStories(pool);
  if (ranked.isNotEmpty) return ranked.take(30).toList(growable: false);
  return repository.topStories(limit: 30);
}, name: 'categoryFeed');

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
/// create an import cycle. The feed itself no longer has a city concept: this is
/// the weather location only, and the app offers no picker for it today.
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

// v2: v1 caches could hold search/channel URLs from the old seed, which opened
// a YouTube page instead of a clip. Reading it again would resurrect that bug.
const String _videoCacheKey = 'video_moments.cache.v2';

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
    // Keep the rail usable on first launch, offline, and while a configured
    // build waits for its first live response. Live/cached entries replace this
    // rotation as soon as the scraper returns videos; an empty response never
    // blanks the section.
    return SlVideos.all;
  }

  Future<void> _refresh() async {
    final SlNewsVideoSource? source = ref.read(slNewsVideoSourceProvider);
    if (source == null) return;
    // Fetch a deeper page than the rail shows: the rail stays short, but the
    // reel can swipe through the day's fuller upload set.
    final List<VideoMoment> live = await source.latest(limit: 50);
    if (live.isEmpty) return;
    final List<VideoMoment> ordered = interleaveVideos(live);
    state = ordered;
    try {
      await ref
          .read(preferencesStoreProvider)
          .putString(
            _videoCacheKey,
            jsonEncode(<Map<String, dynamic>>[
              for (final VideoMoment v in ordered) v.toJson(),
            ]),
          );
    } catch (error) {
      AppLog.debug('videoMoments: could not cache: $error');
    }
  }
}

/// De-duplicates by video id and interleaves sources so one prolific channel
/// cannot fill the rail/reel with consecutive uploads.
///
/// Each source keeps its newest-first order; the output alternates sources until
/// every unique clip is placed.
@visibleForTesting
List<VideoMoment> interleaveVideos(List<VideoMoment> videos) {
  final Set<String> seen = <String>{};
  final Map<String, List<VideoMoment>> bySource = <String, List<VideoMoment>>{};
  for (final VideoMoment video in videos) {
    final String identity = video.youtubeId?.trim().isNotEmpty == true
        ? video.youtubeId!.trim()
        : video.id;
    if (identity.isEmpty || !seen.add(identity)) continue;
    bySource.putIfAbsent(video.source, () => <VideoMoment>[]).add(video);
  }

  final List<VideoMoment> ordered = <VideoMoment>[];
  bool added = true;
  while (added) {
    added = false;
    for (final List<VideoMoment> queue in bySource.values) {
      if (queue.isEmpty) continue;
      ordered.add(queue.removeAt(0));
      added = true;
    }
  }
  return List<VideoMoment>.unmodifiable(ordered);
}

/// Ads rotated into the For You feed, one per section break.
