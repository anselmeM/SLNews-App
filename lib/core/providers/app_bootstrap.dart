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
    PreferencesStore preferences;
    ArticleCache cache;
    bool persistent = false;

    if (allowPersistence) {
      try {
        // Hive needs a writable app directory before either box can open, but
        // the two boxes are independent: open them together.
        await Hive.initFlutter();
        final List<Object> boxes = await Future.wait(<Future<Object>>[
          HivePreferencesStore.open(),
          HiveArticleCache.open(),
        ]);
        preferences = boxes[0] as PreferencesStore;
        cache = boxes[1] as ArticleCache;
        persistent = true;
      } catch (error, stackTrace) {
        AppLog.debug(
          'SLNews: local storage unavailable, falling back to memory ($error)',
        );
        debugPrintStack(stackTrace: stackTrace);
        preferences = InMemoryPreferencesStore();
        cache = InMemoryArticleCache();
      }
    } else {
      preferences = InMemoryPreferencesStore();
      cache = InMemoryArticleCache();
    }

    final int storageMs = clock.elapsedMilliseconds;

    // Identity is optional too; a rejected key or an unreachable Frontend API
    // must never stop the reader from opening the app. It is created before the
    // scraper configuration because a build that ships no static key relies on
    // the session token this provides.
    // Identity must never hold the first frame hostage: a cold Frontend API can
    // take seconds. Four seconds is generous for a local session restore; after
    // that the app opens anonymously for this launch.
    final ClerkAuthRepository? auth = await _createAuth().timeout(
      const Duration(seconds: 4),
      onTimeout: () {
        AppLog.debug('SLNews: Clerk init timed out; continuing anonymously');
        return null;
      },
    );

    // The aggregated Sierra Leone feed from the SLNews scraper API is an optional
    // extra source. It is enabled by a static key embedded at build time, or - in
    // a build that ships no secret - by the Clerk session token a signed-in
    // reader can mint. With neither, it stays absent and such a build behaves
    // exactly like the RSS + seed app.
    final SlNewsApiConfig apiConfig = SlNewsApiConfig.fromEnvironment(
      sessionTokenAvailable: auth != null,
    );

    AppLog.debug(
      'SLNews bootstrap: storage=${storageMs}ms '
      'auth=${clock.elapsedMilliseconds - storageMs}ms '
      'total=${clock.elapsedMilliseconds}ms',
    );

    // Reader-state sync (bookmarks, likes, follows) lives on the PWA origin, so
    // its host must be allow-listed for the session token too â€” otherwise every
    // sync call would be anonymous and answer 401.
    final SyncApiConfig syncConfig = SyncApiConfig.fromEnvironment();

    final ApiClient client = ApiClient(
      authTokenProvider: auth?.sessionToken,
      // Session tokens are only attached to SLNews-owned hosts: the same client
      // also fetches third-party publisher feeds, which must never see them.
      authTokenHosts: <String>{
        if (apiConfig.host.isNotEmpty) apiConfig.host,
        if (syncConfig.isConfigured) syncConfig.host,
        // The live site origin, plus the custom domain it is expected to move to.
        // Session tokens are never attached to `slnews.app`: that domain is not ours
        // and is not part of the deep-link plan.
        'sl-news.vercel.app',
        'slnews.sl',
        'www.slnews.sl',
      },
    );
    final SeedLoader seedLoader = seedLoaderOverride ?? const AssetSeedLoader();
    final SlNewsApiSource? apiSource = apiConfig.isConfigured
        ? SlNewsApiSource(config: apiConfig, client: client)
        : null;
    final List<FeedSource> sources = <FeedSource>[
      ...OutletRegistry.buildSources(client),
      ?apiSource,
    ];
    AppLog.debug(
      'SLNews: ingest sources=${sources.length} '
      '(scraper API ${apiConfig.isConfigured ? 'enabled on ${apiConfig.host} via '
                '${apiConfig.apiKey.trim().isEmpty ? 'Clerk session' : 'embedded key'}' : 'disabled - no key and no identity'}), '
      'identity ${auth == null ? 'disabled' : 'Clerk'}',
    );

    // Concrete types: the seed-backed implementations expose an extra `ready()`
    // used below, which is not part of the repository contracts.
    final OfflineFirstArticleRepository articleRepository =
        OfflineFirstArticleRepository(
          sources: sources,
          cache: cache,
          seedLoader: seedLoader,
          client: client,
          // Deep links outside the current feed resolve, then cache.
          fetchById: apiSource?.articleById,
        );
    final EspnSource espnSource = EspnSource(client: client);
    final LeagueNewsSource leagueNewsSource = LeagueNewsSource(client: client);
    final DefaultSportsRepository sportsRepository = DefaultSportsRepository(
      seedLoader: seedLoader,
      client: client,
      espn: espnSource,
      // Optional backend sports proxy (`/api/mobile/v1/sports`). The app maps
      // the same {games} shape it already consumed from the old scoreboard URL.
      scoreboardUrl: const String.fromEnvironment('SLNEWS_SCOREBOARD_URL'),
      // Live scores are a production-build feature: tests and key-less builds
      // stay fully offline and instant.
      // Prefer the backend proxy when configured: it caches, hides the key and
      // survives rate limits. Direct TheSportsDB stays for proxy-less builds.
      liveSource:
          const bool.fromEnvironment('THESPORTSDB_ENABLED') &&
              const String.fromEnvironment('SLNEWS_SCOREBOARD_URL').isEmpty
          ? TheSportsDbSource(client: client)
          : null,
    );
    final DefaultFollowingRepository followingRepository =
        DefaultFollowingRepository(
          preferences: preferences,
          seedLoader: seedLoader,
        );
    final DefaultNotificationRepository notificationRepository =
        DefaultNotificationRepository(
          preferences: preferences,
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
        DefaultUserStateRepository(preferences: preferences);
    // Sold sponsorships and their counters live on the marketing/API host, not
    // the scraper host. Pointing them at SyncApiConfig sent these calls to
    // Render, where the route does not exist, so every feed fell back to seed ads.
    const String webApiBase = String.fromEnvironment(
      'SLNEWS_WEB_URL',
      defaultValue: 'https://sl-news.vercel.app',
    );
    final DefaultAdRepository adRepository = DefaultAdRepository(
      seedLoader: seedLoader,
      sponsorships: SponsorshipSource(client: client, baseUrl: webApiBase),
    );

    // The seed-backed repositories expose synchronous reads (required by the
    // frozen interfaces) over an async seed load. Awaiting them here means the
    // very first frame already has the followed-teams catalogue, alert history,
    // ad rotation, scoreboard and weather instead of an empty flash.
    await Future.wait(<Future<void>>[
      sportsRepository.ready(),
      followingRepository.ready(),
      notificationRepository.ready(),
      weatherRepository.ready(),
      adRepository.ready(),
    ]);

    return AppBootstrap._(
      container: ProviderContainer(
        overrides: [
          preferencesStoreProvider.overrideWithValue(preferences),
          articleCacheProvider.overrideWithValue(cache),
          seedLoaderProvider.overrideWithValue(seedLoader),
          apiClientProvider.overrideWithValue(client),
          feedSourcesProvider.overrideWithValue(sources),
          articleRepositoryProvider.overrideWithValue(articleRepository),
          sportsRepositoryProvider.overrideWithValue(sportsRepository),
          espnSourceProvider.overrideWithValue(espnSource),
          leagueNewsSourceProvider.overrideWithValue(leagueNewsSource),
          followingRepositoryProvider.overrideWithValue(followingRepository),
          notificationRepositoryProvider.overrideWithValue(
            notificationRepository,
          ),
          weatherRepositoryProvider.overrideWithValue(weatherRepository),
          userStateProvider.overrideWithValue(userStateRepository),
          ttsServiceProvider.overrideWithValue(FlutterTtsService()),
          adRepositoryProvider.overrideWithValue(adRepository),
          sponsorshipTrackerProvider.overrideWithValue(
            (() {
              final tracker = SponsorshipTracker(
                client: client,
                baseUrl: webApiBase,
                store: preferences,
              );
              unawaited(tracker.flush());
              return tracker;
            })(),
          ),
          pushServiceProvider.overrideWithValue(
            PushService(
              client: client,
              baseUrl: webApiBase,
              initialTopics: preferences.stringSet(PushService.topicsPrefKey),
              persistTopics: (Set<String> topics) =>
                  preferences.putStringSet(PushService.topicsPrefKey, topics),
            ),
          ),
          // The video rail shares the scraper configuration; when the build has
          // no key it stays null and the bundled rotation is used instead.
          slNewsVideoSourceProvider.overrideWithValue(
            apiConfig.isConfigured
                ? SlNewsVideoSource(apiConfig, client)
                : null,
          ),
          // Keep the provider and the composition root on the same configuration
          // (and URL host allow-list), so a test or a staging build overrides one
          // place and everything follows.
          syncApiConfigProvider.overrideWithValue(syncConfig),
          // Identity is only overridden when a provider is actually configured;
          // otherwise the default (unconfigured, signed-out) stand-ins apply.
          if (auth != null) authRepositoryProvider.overrideWithValue(auth),
          if (auth != null) signInSurfaceProvider.overrideWithValue(auth),
          if (auth != null)
            authAppWrapperProvider.overrideWithValue(auth.wrapApp),
        ],
      ),
      articleRepository: articleRepository,
      isPersistent: persistent,
      preferences: preferences,
      cache: cache,
      seedLoader: seedLoader,
      apiClient: client,
      feedSources: sources,
      sportsRepository: sportsRepository,
      followingRepository: followingRepository,
      notificationRepository: notificationRepository,
      weatherRepository: weatherRepository,
      userStateRepository: userStateRepository,
      adRepository: adRepository,
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
