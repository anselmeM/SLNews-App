import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/article_cache.dart';
import '../data/local/preferences_store.dart';
import '../data/seed/seed_loader.dart';
import '../data/sources/api_client.dart';
import '../data/sources/feed_source.dart';
import '../domain/models/ad_unit.dart';
import '../domain/models/article.dart';
import '../domain/models/follow_models.dart';
import '../domain/models/notification_item.dart';
import '../domain/models/sports_models.dart';
import '../domain/models/weather_snapshot.dart';
import '../domain/repositories/ad_repository.dart';
import '../domain/repositories/article_repository.dart';
import '../domain/repositories/following_repository.dart';
import '../domain/repositories/notification_repository.dart';
import '../domain/repositories/sports_repository.dart';
import '../domain/repositories/user_state_repository.dart';
import '../domain/repositories/weather_repository.dart';

/// Infrastructure providers.
///
/// Every dependency of the app is declared here and supplied by `AppBootstrap`
/// (production) or by `overrideWithValue` in tests. Nothing in this file
/// performs I/O at declaration time, so importing it from a test is free.
///
/// Family providers are intentionally left untyped: Riverpod 3 marks the
/// concrete family classes `@internal`, so `final x = FutureProvider.family(...)`
/// is the supported spelling.
final Provider<PreferencesStore> preferencesStoreProvider = Provider<PreferencesStore>(
  (Ref ref) => throw UnimplementedError('preferencesStoreProvider must be overridden by AppBootstrap'),
  name: 'preferencesStore',
);

final Provider<ArticleCache> articleCacheProvider = Provider<ArticleCache>(
  (Ref ref) => throw UnimplementedError('articleCacheProvider must be overridden by AppBootstrap'),
  name: 'articleCache',
);

final Provider<SeedLoader> seedLoaderProvider = Provider<SeedLoader>(
  (Ref ref) => throw UnimplementedError('seedLoaderProvider must be overridden by AppBootstrap'),
  name: 'seedLoader',
);

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>(
  (Ref ref) => throw UnimplementedError('apiClientProvider must be overridden by AppBootstrap'),
  name: 'apiClient',
);

/// The configured ingest pipeline (RSS + REST + JSON endpoints).
final Provider<List<FeedSource>> feedSourcesProvider = Provider<List<FeedSource>>(
  (Ref ref) => throw UnimplementedError('feedSourcesProvider must be overridden by AppBootstrap'),
  name: 'feedSources',
);

final Provider<ArticleRepository> articleRepositoryProvider = Provider<ArticleRepository>(
  (Ref ref) => throw UnimplementedError('articleRepositoryProvider must be overridden by AppBootstrap'),
  name: 'articleRepository',
);

final Provider<SportsRepository> sportsRepositoryProvider = Provider<SportsRepository>(
  (Ref ref) => throw UnimplementedError('sportsRepositoryProvider must be overridden by AppBootstrap'),
  name: 'sportsRepository',
);

final Provider<FollowingRepository> followingRepositoryProvider = Provider<FollowingRepository>(
  (Ref ref) => throw UnimplementedError('followingRepositoryProvider must be overridden by AppBootstrap'),
  name: 'followingRepository',
);

final Provider<NotificationRepository> notificationRepositoryProvider =
    Provider<NotificationRepository>(
      (Ref ref) => throw UnimplementedError(
        'notificationRepositoryProvider must be overridden by AppBootstrap',
      ),
      name: 'notificationRepository',
    );

final Provider<WeatherRepository> weatherRepositoryProvider = Provider<WeatherRepository>(
  (Ref ref) => throw UnimplementedError('weatherRepositoryProvider must be overridden by AppBootstrap'),
  name: 'weatherRepository',
);

final Provider<AdRepository> adRepositoryProvider = Provider<AdRepository>(
  (Ref ref) => throw UnimplementedError('adRepositoryProvider must be overridden by AppBootstrap'),
  name: 'adRepository',
);

final Provider<UserStateRepository> userStateProvider = Provider<UserStateRepository>(
  (Ref ref) => throw UnimplementedError('userStateProvider must be overridden by AppBootstrap'),
  name: 'userState',
);

/// Breaking/staff-picked stories for the For You hero carousel.
final topStoriesProvider = FutureProvider<List<Article>>(
  (Ref ref) => ref.watch(articleRepositoryProvider).topStories(),
  name: 'topStories',
);

/// Latest stories for a category slug.
final categoryFeedProvider = FutureProvider.family<List<Article>, String>(
  (Ref ref, String categoryId) => ref.watch(articleRepositoryProvider).byCategory(categoryId),
  name: 'categoryFeed',
);

/// Stories for a followed location (`city:freetown`, ...).
final locationFeedProvider = FutureProvider.family<List<Article>, String>(
  (Ref ref, String locationId) => ref.watch(articleRepositoryProvider).byLocation(locationId),
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
  (Ref ref) => ref.watch(sportsRepositoryProvider).scoreboard(),
  name: 'scoreboard',
);

/// Fixtures for one followed team.
final teamGamesProvider = FutureProvider.family<List<GameScore>, String>(
  (Ref ref, String teamId) => ref.watch(sportsRepositoryProvider).gamesForTeam(teamId),
  name: 'teamGames',
);

/// Standings for one league.
final standingsProvider = FutureProvider.family<List<TeamStanding>, String>(
  (Ref ref, String leagueId) => ref.watch(sportsRepositoryProvider).standings(leagueId),
  name: 'standings',
);

/// Ad rotation for a placement key (`sports_stream`, `feed`).
final adUnitsProvider = FutureProvider.family<List<AdUnit>, String>(
  (Ref ref, String placement) => ref.watch(adRepositoryProvider).units(placement: placement),
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
final NotifierProvider<SelectedCategoryController, String> selectedCategoryProvider =
    NotifierProvider<SelectedCategoryController, String>(
      SelectedCategoryController.new,
      name: 'selectedCategory',
    );

class SelectedCategoryController extends Notifier<String> {
  @override
  String build() => 'top';

  void select(String categoryId) => state = categoryId;
}
