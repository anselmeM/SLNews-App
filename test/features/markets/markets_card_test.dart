import 'dart:convert';

import 'package:flutter/material.dart';
// Riverpod 3 keeps `Override` out of the main entrypoint.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/data/sources/api_client.dart';
import 'package:slnews_mobile/core/data/sources/market_rate_source.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/market_snapshot.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/feed/presentation/for_you_page.dart';

import '../feed/support/fakes.dart';
import '../feed/support/test_harness.dart';

/// A source that answers with a fixed board (or nothing) without any network.
class _FakeMarketSource extends MarketRateSource {
  _FakeMarketSource(this.result) : super(ApiClient());

  final MarketSnapshot? result;

  @override
  Future<MarketSnapshot?> fetch() async => result;
}

void main() {
  final MarketSnapshot board = MarketSnapshot(
    base: 'USD',
    rates: const <String, double>{
      'SLE': 24.357927,
      'SLL': 24357.92723,
      'GBP': 0.750839,
      'EUR': 0.889517,
    },
    updatedAt: DateTime.utc(2026, 10, 16, 12),
    source: 'open.er-api.com',
  );

  Article story() => testArticle(
    id: 'story-1',
    title: 'Budget passes',
    publishedAt: DateTime.utc(2026, 10, 16, 9),
  );

  Future<void> pumpForYou(
    WidgetTester tester, {
    required bool interactiveContent,
    MarketRateSource? source,
    PreferencesStore? preferences,
  }) async {
    await useTallSurface(tester, size: const Size(390, 2600));
    final GoRouter router = GoRouter(
      initialLocation: '/for_you',
      routes: <RouteBase>[
        GoRoute(
          path: '/for_you',
          builder: (BuildContext context, GoRouterState state) =>
              const ForYouPage(),
        ),
      ],
    );

    final FakeUserStateRepository userState = FakeUserStateRepository()
      ..interactiveContentEnabled = interactiveContent;

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...feedTestOverrides(
            articles: FakeArticleRepository(topStories: <Article>[story()]),
            userState: userState,
          ),
          marketRateSourceProvider.overrideWithValue(
            source ?? _FakeMarketSource(board),
          ),
          preferencesStoreProvider.overrideWithValue(
            preferences ?? InMemoryPreferencesStore(),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the Markets card is absent unless interactive content is on', (
    WidgetTester tester,
  ) async {
    await pumpForYou(tester, interactiveContent: false);

    expect(find.text('Markets'), findsNothing);
    expect(find.text('Interactive'), findsNothing);
  });

  testWidgets('the card shows the leone board when the switch is on', (
    WidgetTester tester,
  ) async {
    await pumpForYou(tester, interactiveContent: true);

    expect(find.text('Markets'), findsOneWidget);
    expect(find.text('Interactive'), findsOneWidget);
    expect(find.text('Leone (SLE)'), findsOneWidget);
    expect(find.text('24.36'), findsOneWidget);
    expect(find.text('Pound'), findsOneWidget);
    expect(find.text('0.7508'), findsOneWidget);
  });

  testWidgets('tapping the card opens the full board', (
    WidgetTester tester,
  ) async {
    await pumpForYou(tester, interactiveContent: true);

    await tester.tap(find.text('Markets'));
    await tester.pumpAndSettle();

    // The card behind the sheet shows the same caption; the sheet adds the rows.
    expect(find.textContaining('1 USD buys'), findsWidgets);
    expect(find.text('Sierra Leone (new leone)'), findsOneWidget);
    expect(find.text('British pound'), findsOneWidget);
    expect(find.textContaining('Indicative wholesale rates'), findsOneWidget);
  });

  testWidgets('the switch off keeps the page free of the module', (
    WidgetTester tester,
  ) async {
    await pumpForYou(tester, interactiveContent: false);
    expect(find.textContaining('1 USD buys'), findsNothing);
  });

  test('a cached board is served when the rates service is down', () async {
    final InMemoryPreferencesStore store = InMemoryPreferencesStore(
      <String, Object?>{marketCacheKey: jsonEncode(board.toJson())},
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        preferencesStoreProvider.overrideWithValue(store),
        marketRateSourceProvider.overrideWithValue(_FakeMarketSource(null)),
      ],
    );
    addTearDown(container.dispose);

    final MarketSnapshot? snapshot = await container.read(
      marketSnapshotProvider.future,
    );

    expect(snapshot, isNotNull);
    expect(snapshot!.rateOf('SLE'), closeTo(24.357927, 0.0001));
  });

  test('a fresh board replaces the cached one', () async {
    final InMemoryPreferencesStore store = InMemoryPreferencesStore();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        preferencesStoreProvider.overrideWithValue(store),
        marketRateSourceProvider.overrideWithValue(_FakeMarketSource(board)),
      ],
    );
    addTearDown(container.dispose);

    final MarketSnapshot? snapshot = await container.read(
      marketSnapshotProvider.future,
    );

    expect(snapshot, isNotNull);
    expect(store.string(marketCacheKey), isNotNull);
  });
}
