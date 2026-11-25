import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/local/article_cache.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/data/repositories/default_ad_repository.dart';
import 'package:slnews_mobile/core/data/repositories/default_following_repository.dart';
import 'package:slnews_mobile/core/data/repositories/default_notification_repository.dart';
import 'package:slnews_mobile/core/data/repositories/default_sports_repository.dart';
import 'package:slnews_mobile/core/data/repositories/default_user_state_repository.dart';
import 'package:slnews_mobile/core/data/repositories/default_weather_repository.dart';
import 'package:slnews_mobile/core/data/repositories/offline_first_article_repository.dart';
import 'package:slnews_mobile/core/data/seed/seed_data.dart';
import 'package:slnews_mobile/core/data/seed/seed_loader.dart';
import 'package:slnews_mobile/core/data/sources/api_client.dart';
import 'package:slnews_mobile/core/data/sources/feed_source.dart';
import 'package:slnews_mobile/core/domain/models/ad_unit.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/domain/models/notification_item.dart';
import 'package:slnews_mobile/core/domain/models/sports_models.dart';
import 'package:slnews_mobile/core/domain/models/weather_snapshot.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const SeedLoader bundled = AssetSeedLoader();

  group('DefaultSportsRepository on the bundled seed', () {
    late DefaultSportsRepository repository;

    setUp(() => repository = DefaultSportsRepository(seedLoader: bundled));

    test('scoreboard puts live fixtures first and honours the limit', () async {
      final ScoreboardSnapshot board = await repository.scoreboard();

      expect(board.games, isNotEmpty);
      expect(board.providerLabel, 'yahoo/sports');
      expect(board.games.first.status, GameStatus.live);
      expect(board.games.first.home.id, 'team:leone-stars');
      expect(board.games.first.periodLabel, "72'");
      expect((await repository.scoreboard(limit: 2)).games, hasLength(2));
    });

    test('gamesForTeam accepts prefixed and bare ids', () async {
      expect(await repository.gamesForTeam('team:lal'), hasLength(2));
      expect(await repository.gamesForTeam('lal'), hasLength(2));
      expect(await repository.gamesForTeam('team:unknown'), isEmpty);
    });

    test(
      'standings resolve a league slug and fall back to the whole table',
      () async {
        final List<TeamStanding> rows = await repository.standings(
          'league:spl',
        );

        expect(rows, hasLength(6));
        expect(rows.map((TeamStanding r) => r.rank), <int>[1, 2, 3, 4, 5, 6]);
        expect(await repository.standings('spl'), hasLength(6));
        expect(await repository.standings('league:nba'), hasLength(6));
      },
    );

    test(
      'an unreachable live scoreboard leaves the seeded fixtures in place',
      () async {
        final ({Dio dio, FakeHttpAdapter adapter}) fake = dioWith((
          RequestOptions options,
        ) async {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        });
        final DefaultSportsRepository live = DefaultSportsRepository(
          seedLoader: bundled,
          client: ApiClient(
            dio: fake.dio,
            timeout: const Duration(milliseconds: 50),
          ),
          scoreboardUrl: 'https://scores.example.test/games',
        );

        expect((await live.scoreboard()).games, isNotEmpty);
      },
    );

    test('a working live scoreboard replaces the strip', () async {
      final ({Dio dio, FakeHttpAdapter adapter}) fake = dioWith(
        (RequestOptions options) async => jsonBody(
          '''
{"games":[{"id":"wire-1","leagueLabel":"NBA","status":"scheduled","startsAt":"2026-10-16T22:30:00Z",
"away":{"id":"team:den","name":"Denver Nuggets","code":"DEN","colourHex":"#0E2240"},
"home":{"id":"team:lal","name":"Los Angeles Lakers","code":"LAL","colourHex":"#552583"}}]}''',
        ),
      );
      final DefaultSportsRepository live = DefaultSportsRepository(
        seedLoader: bundled,
        client: ApiClient(dio: fake.dio, timeout: const Duration(seconds: 2)),
        scoreboardUrl: 'https://scores.example.test/games',
      );

      // The seeded strip answers first; the wire payload replaces it once it
      // lands, so poll briefly instead of assuming a fixed scheduling delay.
      ScoreboardSnapshot board = await live.scoreboard();
      final DateTime deadline = DateTime.now().add(const Duration(seconds: 10));
      while (board.games.length != 1 && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        board = await live.scoreboard();
      }

      expect(board.games.single.id, 'wire-1');
      expect(
        fake.adapter.requests.single.uri.toString(),
        'https://scores.example.test/games',
      );
    });
  });

  group('DefaultNotificationRepository on the bundled seed', () {
    test(
      'seeds history newest first, persists reads and de-duplicates records',
      () async {
        final InMemoryPreferencesStore preferences = InMemoryPreferencesStore();
        final DefaultNotificationRepository repository =
            DefaultNotificationRepository(
              seedLoader: bundled,
              preferences: preferences,
            );

        final List<NotificationItem> history = await repository.history();
        expect(history, hasLength(6));
        for (int i = 1; i < history.length; i++) {
          expect(
            history[i - 1].receivedAt.isBefore(history[i].receivedAt),
            isFalse,
          );
        }
        expect(repository.cachedHistory, hasLength(6));

        final int unreadBefore = repository.unreadCount;
        expect(unreadBefore, greaterThan(0));

        final NotificationItem first = history.first;
        await repository.markRead(first.id);
        expect(repository.unreadCount, unreadBefore - 1);
        expect(
          preferences.stringSet(DefaultNotificationRepository.readIdsKey),
          contains(first.id),
        );

        final DefaultNotificationRepository reopened =
            DefaultNotificationRepository(
              seedLoader: bundled,
              preferences: preferences,
            );
        final List<NotificationItem> again = await reopened.history();
        expect(
          again.firstWhere((NotificationItem i) => i.id == first.id).isRead,
          isTrue,
        );

        await reopened.markAllRead();
        expect(reopened.unreadCount, 0);
      },
    );

    test(
      'record prepends and replaces an existing alert with the same id',
      () async {
        final DefaultNotificationRepository repository =
            DefaultNotificationRepository(
              seedLoader: bundled,
              preferences: InMemoryPreferencesStore(),
            );
        final int seededCount = (await repository.history()).length;
        final NotificationItem fresh = NotificationItem(
          id: 'notif-test',
          title: 'Fresh alert',
          body: 'Body copy',
          receivedAt: DateTime.utc(2026, 10, 15, 23),
          kind: NotificationKind.breaking,
        );

        await repository.record(fresh);
        expect((await repository.history()).first.id, 'notif-test');
        expect(await repository.history(), hasLength(seededCount + 1));

        await repository.record(fresh.copyWith(isRead: true));
        final List<NotificationItem> after = await repository.history();
        expect(after, hasLength(seededCount + 1));
        expect(after.first.isRead, isTrue);
      },
    );
  });

  test('ad rotation serves the house units for any placement', () async {
    final DefaultAdRepository repository = DefaultAdRepository(
      seedLoader: bundled,
    );

    final List<AdUnit> units = await repository.units(
      placement: 'sports_stream',
    );

    expect(units, hasLength(3));
    expect(repository.cachedUnits, hasLength(3));
    final AdUnit rewards = units.firstWhere(
      (AdUnit unit) => unit.id == 'ad-salone-rewards',
    );
    expect(rewards.assetLabel, r'$20');
    expect(rewards.disclosure, isNotNull);
    expect(
      units.map((AdUnit unit) => unit.advertiser),
      isNot(contains('PayPal')),
    );
  });

  group('DefaultWeatherRepository', () {
    test('serves a bundled snapshot for every seeded city', () async {
      final DefaultWeatherRepository repository = DefaultWeatherRepository(
        seedLoader: bundled,
      );

      for (final NewsLocation location in SlLocations.all) {
        final WeatherSnapshot snapshot = await repository.current(location);
        expect(snapshot.locationLabel, location.label);
        expect(snapshot.temperatureC, greaterThan(0));
        expect(snapshot.conditionLabel, isNotEmpty);
      }

      final WeatherSnapshot freetown = await repository.current(
        SlLocations.fallback,
      );
      expect(freetown.temperatureC, 29);
      expect(freetown.glyph, 'storm');
      expect(freetown.highC, 31);
    });

    test('device locations do not receive a fake Freetown forecast', () async {
      final DefaultWeatherRepository repository = DefaultWeatherRepository(
        seedLoader: bundled,
      );

      final WeatherSnapshot snapshot = await repository.current(
        const NewsLocation(
          id: 'geo:51.51,-0.13',
          label: 'London',
          region: 'United Kingdom',
          latitude: 51.51,
          longitude: -0.13,
        ),
      );

      expect(snapshot.locationLabel, 'London');
      expect(snapshot.isAvailable, isFalse);
      expect(snapshot.conditionLabel, 'Weather unavailable');
    });

    test('falls back to a placeholder for an unknown city', () async {
      final DefaultWeatherRepository repository = DefaultWeatherRepository(
        seedLoader: bundled,
      );

      final WeatherSnapshot snapshot = await repository.current(
        const NewsLocation(
          id: 'city:nowhere',
          label: 'Nowhere',
          region: 'Nowhere',
        ),
      );

      expect(snapshot.locationLabel, 'Nowhere');
      expect(snapshot.conditionLabel, 'Thundery showers');
    });

    test('prefers a configured live endpoint', () async {
      final ({Dio dio, FakeHttpAdapter adapter}) fake = dioWith(
        (RequestOptions options) async => jsonBody(
          '{"current":{"temperatureC":33,"conditionLabel":"Sunny","glyph":"sun","highC":35,"lowC":25,"humidityPercent":60}}',
        ),
      );
      final DefaultWeatherRepository repository = DefaultWeatherRepository(
        seedLoader: bundled,
        client: ApiClient(dio: fake.dio, timeout: const Duration(seconds: 2)),
        endpointTemplate:
            'https://api.example.test/weather?id={id}&lat={lat}&lon={lon}',
      );

      final WeatherSnapshot snapshot = await repository.current(
        SlLocations.fallback,
      );

      expect(snapshot.temperatureC, 33);
      expect(snapshot.conditionLabel, 'Sunny');
      expect(snapshot.locationLabel, 'Freetown');
      expect(
        fake.adapter.requests.single.uri.query,
        contains('city%3Afreetown'),
      );
    });
  });

  test('every repository is usable with in-memory stores only', () async {
    final PreferencesStore preferences = InMemoryPreferencesStore();
    final SeedData seed = seedData(
      articles: <Article>[article('seed-1')],
      followables: <FollowTarget>[
        target('city:freetown', isPopular: true, label: 'Freetown'),
        target('topic:politics', isPopular: true, label: 'Politics'),
      ],
      notifications: <NotificationItem>[
        NotificationItem(
          id: 'n1',
          title: 'Title',
          body: 'Body',
          receivedAt: DateTime.utc(2026, 10, 15, 10),
          kind: NotificationKind.breaking,
        ),
      ],
      ads: <AdUnit>[
        const AdUnit(
          id: 'ad-1',
          headline: 'H',
          body: 'B',
          ctaLabel: 'Go',
          advertiser: 'Test',
        ),
      ],
      weather: <String, WeatherSnapshot>{
        'city:freetown': WeatherSnapshot(
          locationLabel: 'Freetown',
          temperatureC: 30,
          conditionLabel: 'Sunny',
          glyph: 'sun',
          updatedAt: DateTime.utc(2026, 10, 15, 10),
        ),
      },
      standings: <TeamStanding>[
        TeamStanding(
          team: const Team(
            id: 'team:lal',
            name: 'Los Angeles Lakers',
            code: 'LAL',
          ),
          leagueId: 'league:nba',
          leagueLabel: 'NBA',
          record: '1-0',
          rank: 1,
        ),
      ],
      games: <GameScore>[
        GameScore(
          id: 'g1',
          leagueLabel: 'NBA',
          away: const Team(id: 'team:den', name: 'Denver Nuggets', code: 'DEN'),
          home: const Team(
            id: 'team:lal',
            name: 'Los Angeles Lakers',
            code: 'LAL',
          ),
          status: GameStatus.scheduled,
          startsAt: DateTime.utc(2026, 10, 16, 22, 30),
        ),
      ],
    );
    final SeedLoader inMemory = InMemorySeedLoader(seed);

    final OfflineFirstArticleRepository articles =
        OfflineFirstArticleRepository(
          sources: const <FeedSource>[],
          cache: InMemoryArticleCache(),
          seedLoader: inMemory,
        );
    final DefaultSportsRepository sports = DefaultSportsRepository(
      seedLoader: inMemory,
    );
    final DefaultFollowingRepository following = DefaultFollowingRepository(
      preferences: preferences,
      seedLoader: inMemory,
    );
    final DefaultNotificationRepository notifications =
        DefaultNotificationRepository(
          seedLoader: inMemory,
          preferences: preferences,
        );
    final DefaultWeatherRepository weather = DefaultWeatherRepository(
      seedLoader: inMemory,
    );
    final DefaultUserStateRepository userState = DefaultUserStateRepository(
      preferences: preferences,
    );
    final DefaultAdRepository ads = DefaultAdRepository(seedLoader: inMemory);

    expect((await articles.topStories()).single.id, 'seed-1');
    expect((await sports.scoreboard()).games.single.id, 'g1');
    expect((await sports.gamesForTeam('lal')).single.id, 'g1');
    expect((await sports.standings('nba')).single.rank, 1);
    await following.ready();
    // Suggestions are unfollowed topics, popular first; the seeded city is no
    // longer offered because locations left the app.
    final List<FollowTarget> suggested = following.load().suggested;
    expect(suggested.map((FollowTarget target) => target.id), <String>[
      'topic:politics',
    ]);
    expect((await notifications.history()).single.id, 'n1');
    expect((await weather.current(SlLocations.fallback)).temperatureC, 30);
    expect((await ads.units()).single.id, 'ad-1');
    expect(userState.themeMode, 'system');
  });
}
