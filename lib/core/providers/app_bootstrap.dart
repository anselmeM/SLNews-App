import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/auth/clerk_auth_repository.dart';
import '../data/local/article_cache.dart';
import '../data/local/preferences_store.dart';
import '../data/repositories/default_ad_repository.dart';
import '../data/sources/sponsorship_source.dart';
import '../data/sources/sponsorship_tracker.dart';
import '../push/push_service.dart';
import '../data/repositories/default_following_repository.dart';
import '../data/repositories/default_notification_repository.dart';
import '../data/repositories/default_sports_repository.dart';
import '../data/repositories/default_user_state_repository.dart';
import '../data/repositories/default_weather_repository.dart';
import '../data/repositories/offline_first_article_repository.dart';
import '../data/seed/outlet_registry.dart';
import '../data/seed/seed_loader.dart';
import '../data/sources/api_client.dart';
import '../domain/auth/account_scope.dart';
import '../data/sources/feed_source.dart';
import '../data/sources/sl_news_api_source.dart';
import '../data/sources/sl_news_video_source.dart';
import '../data/sources/espn_source.dart';
import '../data/sources/league_news_source.dart';
import '../tts/flutter_tts_service.dart';
import '../tts/tts_controller.dart';
import '../data/sources/the_sports_db_source.dart';
import '../data/sync/sync_api_config.dart';
import '../domain/repositories/ad_repository.dart';
import '../domain/repositories/article_repository.dart';
import '../domain/repositories/following_repository.dart';
import '../domain/repositories/notification_repository.dart';
import '../domain/repositories/sports_repository.dart';
import '../domain/repositories/user_state_repository.dart';
import '../domain/repositories/weather_repository.dart';
import 'app_providers.dart';
import 'auth_providers.dart';
import 'sync_repository_provider.dart';

import 'package:slnews_mobile/core/utils/app_log.dart';

/// Opens local storage and wires the object graph before the first frame.
///
/// Doing this in `main()` (instead of inside providers) keeps every provider
/// synchronous, so widgets never have to reason about a half-initialised app and
/// tests can substitute the whole graph with in-memory fakes.
///
/// The overrides are installed into a [ProviderContainer] here rather than being
/// handed back as a list: Riverpod 3 keeps the `Override` type out of its public
/// API, so the list literal can only be built where the parameter type is known.
class AppBootstrap {
  AppBootstrap._({
    required this.container,
    required this.articleRepository,
    required this.isPersistent,
    required this.preferences,
    required this.cache,
    required this.seedLoader,
    required this.apiClient,
    required this.feedSources,
    required this.sportsRepository,
    required this.followingRepository,
    required this.notificationRepository,
    required this.weatherRepository,
    required this.userStateRepository,
    required this.adRepository,
  });

  /// Container holding every production dependency; pass it to
  /// `UncontrolledProviderScope`. Dispose it when the app is torn down in tests.
  final ProviderContainer container;

  final ArticleRepository articleRepository;

  /// False when Hive failed to open and the app fell back to memory-only
  /// storage; the reader keeps working but nothing survives a restart.
  final bool isPersistent;

  final PreferencesStore preferences;
  final ArticleCache cache;
  final SeedLoader seedLoader;
  final ApiClient apiClient;
  final List<FeedSource> feedSources;
  final SportsRepository sportsRepository;
  final FollowingRepository followingRepository;
  final NotificationRepository notificationRepository;
  final WeatherRepository weatherRepository;
  final UserStateRepository userStateRepository;
  final AdRepository adRepository;

  /// Opens local storage and wires the object graph.
  ///
  /// [seedLoaderOverride] lets a harness supply deterministic content (the
  /// golden render tests pin every timestamp so screens are byte-comparable);
  /// the app always uses the bundled assets.
  static Future<AppBootstrap> create({
    bool allowPersistence = true,
    SeedLoader? seedLoaderOverride,
  }) async {
    final Stopwatch clock = Stopwatch()..start();
    final _Storage storage = await _openStorage(allowPersistence);
    final int storageMs = clock.elapsedMilliseconds;
    final ClerkAuthRepository? auth = await _createAuthWithTimeout();
    final SlNewsApiConfig apiConfig = SlNewsApiConfig.fromEnvironment(
      sessionTokenAvailable: auth != null,
    );
    AppLog.debug(
      'SLNews bootstrap: storage=${storageMs}ms '
      'auth=${clock.elapsedMilliseconds - storageMs}ms '
      'total=${clock.elapsedMilliseconds}ms',
    );

    final SyncApiConfig syncConfig = SyncApiConfig.fromEnvironment();
    final ApiClient client = _createClient(
      auth: auth,
      apiConfig: apiConfig,
      syncConfig: syncConfig,
    );
    final SeedLoader seedLoader = seedLoaderOverride ?? const AssetSeedLoader();
    final _Sources sources = _createSources(client, apiConfig);
    AppLog.debug(_sourceLog(apiConfig, sources, auth));

    final _RepositoryGraph repositories = await _buildRepositories(
      storage: storage,
      auth: auth,
      client: client,
      seedLoader: seedLoader,
      sources: sources.sources,
      apiSource: sources.apiSource,
    );
    return AppBootstrap._(
      container: _createContainer(
        auth: auth,
        apiConfig: apiConfig,
        syncConfig: syncConfig,
        seedLoader: seedLoader,
        storage: storage,
        client: client,
        sources: sources.sources,
        repositories: repositories,
      ),
      articleRepository: repositories.articleRepository,
      isPersistent: storage.persistent,
      preferences: storage.preferences,
      cache: storage.cache,
      seedLoader: seedLoader,
      apiClient: client,
      feedSources: sources.sources,
      sportsRepository: repositories.sportsRepository,
      followingRepository: repositories.followingRepository,
      notificationRepository: repositories.notificationRepository,
      weatherRepository: repositories.weatherRepository,
      userStateRepository: repositories.userStateRepository,
      adRepository: repositories.adRepository,
    );
  }

  static Future<_Storage> _openStorage(bool allowPersistence) async {
    if (!allowPersistence) {
      return _Storage(
        preferences: InMemoryPreferencesStore(),
        cache: InMemoryArticleCache(),
        persistent: false,
      );
    }
    try {
      // Hive needs a writable app directory before either box can open, but
      // the two boxes are independent: open them together.
      await Hive.initFlutter();
      final List<Object> boxes = await Future.wait(<Future<Object>>[
        HivePreferencesStore.open(),
        HiveArticleCache.open(),
      ]);
      return _Storage(
        preferences: boxes[0] as PreferencesStore,
        cache: boxes[1] as ArticleCache,
        persistent: true,
      );
    } catch (error, stackTrace) {
      AppLog.debug(
        'SLNews: local storage unavailable, falling back to memory ($error)',
      );
      debugPrintStack(stackTrace: stackTrace);
      return _Storage(
        preferences: InMemoryPreferencesStore(),
        cache: InMemoryArticleCache(),
        persistent: false,
      );
    }
  }

  static Future<ClerkAuthRepository?> _createAuthWithTimeout() =>
      _createAuth().timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          AppLog.debug('SLNews: Clerk init timed out; continuing anonymously');
          return null;
        },
      );

  static ApiClient _createClient({
    required ClerkAuthRepository? auth,
    required SlNewsApiConfig apiConfig,
    required SyncApiConfig syncConfig,
  }) {
    // Session tokens are only attached to SLNews-owned hosts: the same client
    // also fetches third-party publisher feeds, which must never see them.
    return ApiClient(
      authTokenProvider: auth?.sessionToken,
      authTokenHosts: <String>{
        if (apiConfig.host.isNotEmpty) apiConfig.host,
        if (syncConfig.isConfigured) syncConfig.host,
        // The live site origin, plus the custom domain it is expected to move to.
        'sl-news.vercel.app',
        'slnews.sl',
        'www.slnews.sl',
      },
    );
  }

  static _Sources _createSources(ApiClient client, SlNewsApiConfig apiConfig) {
    final SlNewsApiSource? apiSource = apiConfig.isConfigured
        ? SlNewsApiSource(config: apiConfig, client: client)
        : null;
    return _Sources(
      sources: <FeedSource>[...OutletRegistry.buildSources(client), ?apiSource],
      apiSource: apiSource,
    );
  }

  static String _sourceLog(
    SlNewsApiConfig apiConfig,
    _Sources sources,
    ClerkAuthRepository? auth,
  ) {
    final String credential = apiConfig.apiKey.trim().isNotEmpty
        ? 'embedded key'
        : auth != null
        ? 'Clerk session'
        : 'anonymous public routes';
    final String scraper = apiConfig.isConfigured
        ? 'enabled on ${apiConfig.host} via $credential'
        : 'disabled - no host';
    return 'SLNews: ingest sources=${sources.sources.length} '
        '(scraper API $scraper), '
        'identity ${auth == null ? 'disabled' : 'Clerk'}';
  }

  static Future<_RepositoryGraph> _buildRepositories({
    required _Storage storage,
    required ClerkAuthRepository? auth,
    required ApiClient client,
    required SeedLoader seedLoader,
    required List<FeedSource> sources,
    required SlNewsApiSource? apiSource,
  }) async {
    final OfflineFirstArticleRepository articleRepository =
        OfflineFirstArticleRepository(
          sources: sources,
          cache: storage.cache,
          seedLoader: seedLoader,
          client: client,
          fetchById: apiSource?.articleById,
        );
    final EspnSource espnSource = EspnSource(client: client);
    final LeagueNewsSource leagueNewsSource = LeagueNewsSource(client: client);
    final DefaultSportsRepository sportsRepository = DefaultSportsRepository(
      seedLoader: seedLoader,
      client: client,
      espn: espnSource,
      scoreboardUrl: const String.fromEnvironment('SLNEWS_SCOREBOARD_URL'),
      liveSource:
          const bool.fromEnvironment('THESPORTSDB_ENABLED') &&
              const String.fromEnvironment('SLNEWS_SCOREBOARD_URL').isEmpty
          ? TheSportsDbSource(client: client)
          : null,
    );
    final DefaultFollowingRepository followingRepository =
        DefaultFollowingRepository(
          preferences: storage.preferences,
          seedLoader: seedLoader,
          accountId: () => localAccountIdFor(auth?.currentUser?.id),
        );
    final DefaultNotificationRepository notificationRepository =
        DefaultNotificationRepository(
          preferences: storage.preferences,
          seedLoader: seedLoader,
        );
    final DefaultWeatherRepository weatherRepository = DefaultWeatherRepository(
      seedLoader: seedLoader,
      client: client,
      endpointTemplate: const String.fromEnvironment(
        'SLNEWS_WEATHER_URL',
        defaultValue: 'https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,weather_code,relative_humidity_2m&timezone=auto',
      ),
    );
    final DefaultUserStateRepository userStateRepository =
        DefaultUserStateRepository(
          preferences: storage.preferences,
          accountId: () => localAccountIdFor(auth?.currentUser?.id),
        );
    const String webApiBase = String.fromEnvironment(
      'SLNEWS_WEB_URL',
      defaultValue: 'https://sl-news.vercel.app',
    );
    final DefaultAdRepository adRepository = DefaultAdRepository(
      seedLoader: seedLoader,
      sponsorships: SponsorshipSource(client: client, baseUrl: webApiBase),
    );
    await Future.wait(<Future<void>>[
      sportsRepository.ready(),
      followingRepository.ready(),
      notificationRepository.ready(),
      weatherRepository.ready(),
      adRepository.ready(),
    ]);
    return _RepositoryGraph(
      articleRepository: articleRepository,
      espnSource: espnSource,
      leagueNewsSource: leagueNewsSource,
      sportsRepository: sportsRepository,
      followingRepository: followingRepository,
      notificationRepository: notificationRepository,
      weatherRepository: weatherRepository,
      userStateRepository: userStateRepository,
      adRepository: adRepository,
    );
  }

  static ProviderContainer _createContainer({
    required ClerkAuthRepository? auth,
    required SlNewsApiConfig apiConfig,
    required SyncApiConfig syncConfig,
    required SeedLoader seedLoader,
    required _Storage storage,
    required ApiClient client,
    required List<FeedSource> sources,
    required _RepositoryGraph repositories,
  }) {
    const String webApiBase = String.fromEnvironment(
      'SLNEWS_WEB_URL',
      defaultValue: 'https://sl-news.vercel.app',
    );
    return ProviderContainer(
      overrides: [
        preferencesStoreProvider.overrideWithValue(storage.preferences),
        articleCacheProvider.overrideWithValue(storage.cache),
        seedLoaderProvider.overrideWithValue(seedLoader),
        apiClientProvider.overrideWithValue(client),
        feedSourcesProvider.overrideWithValue(sources),
        articleRepositoryProvider.overrideWithValue(
          repositories.articleRepository,
        ),
        sportsRepositoryProvider.overrideWithValue(
          repositories.sportsRepository,
        ),
        espnSourceProvider.overrideWithValue(repositories.espnSource),
        leagueNewsSourceProvider.overrideWithValue(
          repositories.leagueNewsSource,
        ),
        followingRepositoryProvider.overrideWithValue(
          repositories.followingRepository,
        ),
        notificationRepositoryProvider.overrideWithValue(
          repositories.notificationRepository,
        ),
        weatherRepositoryProvider.overrideWithValue(
          repositories.weatherRepository,
        ),
        userStateProvider.overrideWithValue(repositories.userStateRepository),
        ttsServiceProvider.overrideWithValue(FlutterTtsService()),
        adRepositoryProvider.overrideWithValue(repositories.adRepository),
        sponsorshipTrackerProvider.overrideWithValue(
          (() {
            final tracker = SponsorshipTracker(
              client: client,
              baseUrl: webApiBase,
              store: storage.preferences,
            );
            unawaited(tracker.flush());
            return tracker;
          })(),
        ),
        pushServiceProvider.overrideWithValue(
          PushService(
            client: client,
            baseUrl: webApiBase,
            initialTopics: storage.preferences.stringSet(
              PushService.topicsPrefKey,
            ),
            persistTopics: (Set<String> topics) => storage.preferences
                .putStringSet(PushService.topicsPrefKey, topics),
          ),
        ),
        slNewsVideoSourceProvider.overrideWithValue(
          apiConfig.isConfigured ? SlNewsVideoSource(apiConfig, client) : null,
        ),
        syncApiConfigProvider.overrideWithValue(syncConfig),
        if (auth != null) authRepositoryProvider.overrideWithValue(auth),
        if (auth != null) signInSurfaceProvider.overrideWithValue(auth),
        if (auth != null)
          authAppWrapperProvider.overrideWithValue(auth.wrapApp),
      ],
    );
  }

  /// Builds the Clerk session when `CLERK_PUBLISHABLE_KEY` is configured.
  ///
  /// Returns `null` (app runs anonymously) when the key is absent, rejected, or
  /// the Frontend API cannot be reached â€” start-up must not depend on identity.
  static Future<ClerkAuthRepository?> _createAuth() async {
    const String key = String.fromEnvironment('CLERK_PUBLISHABLE_KEY');
    if (key.trim().isEmpty) {
      AppLog.debug('SLNews: identity disabled - no CLERK_PUBLISHABLE_KEY');
      return null;
    }
    try {
      final ClerkAuthRepository repository = await ClerkAuthRepository.create(
        publishableKey: key.trim(),
      );
      AppLog.debug('SLNews: identity enabled via Clerk');
      return repository;
    } catch (error, stackTrace) {
      AppLog.debug(
        'SLNews: Clerk unavailable, continuing anonymously ($error)',
      );
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }
}

class _Storage {
  const _Storage({
    required this.preferences,
    required this.cache,
    required this.persistent,
  });

  final PreferencesStore preferences;
  final ArticleCache cache;
  final bool persistent;
}

class _Sources {
  const _Sources({required this.sources, required this.apiSource});

  final List<FeedSource> sources;
  final SlNewsApiSource? apiSource;
}

class _RepositoryGraph {
  const _RepositoryGraph({
    required this.articleRepository,
    required this.espnSource,
    required this.leagueNewsSource,
    required this.sportsRepository,
    required this.followingRepository,
    required this.notificationRepository,
    required this.weatherRepository,
    required this.userStateRepository,
    required this.adRepository,
  });

  final OfflineFirstArticleRepository articleRepository;
  final EspnSource espnSource;
  final LeagueNewsSource leagueNewsSource;
  final DefaultSportsRepository sportsRepository;
  final DefaultFollowingRepository followingRepository;
  final DefaultNotificationRepository notificationRepository;
  final DefaultWeatherRepository weatherRepository;
  final DefaultUserStateRepository userStateRepository;
  final DefaultAdRepository adRepository;
}
