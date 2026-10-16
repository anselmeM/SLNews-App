import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/app.dart';
import 'package:slnews_mobile/core/data/seed/seed_data.dart';
import 'package:slnews_mobile/core/data/seed/seed_loader.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/notification_item.dart';
import 'package:slnews_mobile/core/domain/models/sports_models.dart';
import 'package:slnews_mobile/core/domain/models/weather_snapshot.dart';
import 'package:slnews_mobile/core/providers/app_bootstrap.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/routing/app_router.dart';
import 'package:slnews_mobile/core/routing/app_routes.dart';

/// End-to-end screen renders.
///
/// These pump the **real** application — real bootstrap, real router, real
/// pages, real bundled seed content — with in-memory storage, then write one PNG
/// per screen. They are the visual regression harness for the Samsung-News-style
/// layout and the clearest proof that the app renders with no network at all.
///
///     flutter test test/golden --update-goldens     # regenerate
///     flutter test test/golden                      # compare
///
/// Every timestamp is pinned (see [_frozenSeedLoader]) so renders are stable.
/// CI runs the functional suites (`test/core`, `test/data`, `test/features`) and
/// skips these, because pixel output also depends on the host renderer.
void main() {
  setUpAll(() async {
    // `cached_network_image` needs a cache directory and a database, neither of
    // which exists under `flutter test`. Pointing path_provider at a real temp
    // directory keeps the image pipeline happy so the only thing the renders
    // show is the design system's own placeholder.
    TestWidgetsFlutterBinding.ensureInitialized();
    final String tempDir = Directory.systemTemp.createTempSync('slnews_render_').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => tempDir,
    );

    // Render with the bundled typeface instead of the default test font.
    final FontLoader textLoader = FontLoader('SLNewsSans');
    textLoader.addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
    await textLoader.load();

    // Load the Material icon font too, otherwise every icon renders as a box and
    // the renders stop being useful for review.
    final FontLoader iconLoader = FontLoader('MaterialIcons');
    iconLoader.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await iconLoader.load();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });

  late ProviderContainer container;

  Future<void> pumpApp(WidgetTester tester) async {
    // Logical size of the reference device (1080 x 2202 at DPR 2.75).
    tester.view.physicalSize = const Size(1080, 2202);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final AppBootstrap bootstrap = await AppBootstrap.create(
      allowPersistence: false,
      seedLoaderOverride: await _frozenSeedLoader(),
    );
    container = bootstrap.container;
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const SlNewsApp()),
    );
    await settle(tester);
    drainPlatformNoise(tester);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    drainPlatformNoise(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  }

  testWidgets('For You tab renders the hero carousel and streams', (WidgetTester tester) async {
    await pumpApp(tester);
    expect(find.text('Top stories'), findsWidgets);
    await capture(tester, 'for_you');
  });

  testWidgets('News tab renders the category pills, hero and grid', (WidgetTester tester) async {
    await pumpApp(tester);
    container.read(appRouterProvider).go(AppRoutes.news);
    await settle(tester);
    await capture(tester, 'news');
  });

  testWidgets('Sports tab renders the scoreboard and inline ad', (WidgetTester tester) async {
    await pumpApp(tester);
    container.read(appRouterProvider).go(AppRoutes.sports);
    await settle(tester);
    await capture(tester, 'sports');
  });

  testWidgets('Following tab renders subscriptions and alert history', (WidgetTester tester) async {
    await pumpApp(tester);
    container.read(appRouterProvider).go(AppRoutes.following);
    await settle(tester);
    await capture(tester, 'following');
  });

  testWidgets('Article reader renders the body and floating action bar', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    final List<Article> stories = await container.read(articleRepositoryProvider).topStories();
    expect(stories, isNotEmpty, reason: 'bundled seed content must be available offline');

    container.read(appRouterProvider).push(AppRoutes.articleFor(stories.first.id));
    await settle(tester);
    await capture(tester, 'article');
  });

  testWidgets('Saved stories renders its empty state', (WidgetTester tester) async {
    await pumpApp(tester);
    container.read(appRouterProvider).push(AppRoutes.saved);
    await settle(tester);
    await capture(tester, 'saved');
  });
}

/// Pumps a bounded number of frames instead of `pumpAndSettle`, because the
/// shimmering skeletons animate forever by design.
Future<void> settle(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Discards the platform-channel exceptions a widget test cannot satisfy.
///
/// Every article has a remote image, and `cached_network_image` asks the host
/// for a cache directory and a database that do not exist under `flutter test`
/// (`path_provider` / `sqflite` have no test implementations). The images fall
/// back to the design-system placeholder, which is exactly what the render is
/// meant to show; the noise would otherwise fail the test.
void drainPlatformNoise(WidgetTester tester) {
  while (tester.takeException() != null) {
    // Intentionally empty: the exceptions carry no information for this test.
  }
}

/// The bundled seed with every timestamp pinned to one instant.
///
/// The shipped assets express recency relative to "now" (`publishedMinutesAgo`
/// and friends) so the app always looks fresh; that makes renders drift, because
/// the reader prints an absolute publication time. Deterministic content keeps
/// the PNGs comparable while exercising the same models and the same pipeline.
Future<SeedLoader> _frozenSeedLoader() async {
  final SeedData live = await const AssetSeedLoader().load();
  final DateTime base = DateTime(2026, 10, 15, 9);

  return InMemorySeedLoader(
    SeedData(
      articles: <Article>[
        for (int index = 0; index < live.articles.length; index++)
          live.articles[index].copyWith(
            publishedAt: base.subtract(Duration(minutes: 17 * index)),
          ),
      ],
      scoreboard: ScoreboardSnapshot(
        games: <GameScore>[
          for (final GameScore game in live.scoreboard.games)
            GameScore(
              id: game.id,
              leagueLabel: game.leagueLabel,
              away: game.away,
              home: game.home,
              status: game.status,
              awayScore: game.awayScore,
              homeScore: game.homeScore,
              startsAt: game.startsAt == null ? null : base.add(const Duration(hours: 2)),
              periodLabel: game.periodLabel,
              venue: game.venue,
            ),
        ],
        providerLabel: live.scoreboard.providerLabel,
        updatedAt: base,
      ),
      followables: live.followables,
      locations: live.locations,
      notifications: <NotificationItem>[
        for (int index = 0; index < live.notifications.length; index++)
          NotificationItem(
            id: live.notifications[index].id,
            title: live.notifications[index].title,
            body: live.notifications[index].body,
            receivedAt: base.subtract(Duration(hours: index + 1)),
            kind: live.notifications[index].kind,
            articleId: live.notifications[index].articleId,
            isRead: live.notifications[index].isRead,
          ),
      ],
      ads: live.ads,
      weather: <String, WeatherSnapshot>{
        for (final MapEntry<String, WeatherSnapshot> entry in live.weather.entries)
          entry.key: WeatherSnapshot(
            locationLabel: entry.value.locationLabel,
            temperatureC: entry.value.temperatureC,
            conditionLabel: entry.value.conditionLabel,
            glyph: entry.value.glyph,
            highC: entry.value.highC,
            lowC: entry.value.lowC,
            humidityPercent: entry.value.humidityPercent,
            updatedAt: base,
          ),
      },
      standings: live.standings,
    ),
  );
}
