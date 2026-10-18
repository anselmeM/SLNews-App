import 'dart:convert';

import 'package:flutter/material.dart';
// Riverpod 3 keeps `Override` out of the main entrypoint.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/data/sources/api_client.dart';
import 'package:slnews_mobile/core/data/sources/index_quote_source.dart';
import 'package:slnews_mobile/core/data/sources/market_rate_source.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/index_quote.dart';
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

/// Index board double for the Stocks section.
class _FakeIndexSource extends IndexQuoteSource {
  _FakeIndexSource(this.result) : super(ApiClient());

  final IndexBoard? result;

  @override
  Future<IndexBoard?> fetch() async => result;
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

  IndexBoard indices() => IndexBoard(
    quotes: <IndexQuote>[
      const IndexQuote(
        symbol: '^IXIC',
        name: 'Nasdaq Comp',
        subtitle: 'NASDAQ Composite',
        price: 26140.03,
        changePercent: -3.94,
        sparkline: <double>[26500, 26410, 26290, 26140],
      ),
      const IndexQuote(
        symbol: '^RUT',
        name: 'Russell 2000',
        subtitle: 'Russell 2000 Index',
        price: 2721.37,
        changePercent: -1.66,
      ),
      const IndexQuote(
        symbol: '^DJI',
        name: 'Dow Jones',
        subtitle: 'Dow Jones Industrial Average',
        price: 52002.40,
        changePercent: -0.36,
      ),
      const IndexQuote(
        symbol: '^GSPTSE',
        name: 'TSX Comp',
        subtitle: 'S&P/TSX Composite index',
        price: 36176.55,
        changePercent: 0.10,
      ),
    ],
    updatedAt: DateTime.utc(2026, 10, 16, 20),
    sourceLabel: 'yahoo/finance',
    isOpen: false,
  );

  Article story() => testArticle(
    id: 'story-1',
    title: 'Budget passes',
    publishedAt: DateTime.utc(2026, 10, 16, 9),
  );

  Future<void> pumpForYou(
    WidgetTester tester, {
    required bool interactiveContent,
    IndexBoard? indexBoard,
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
        GoRoute(
          path: '/stocks',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('stocks page')),
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
          indexQuoteSourceProvider.overrideWithValue(
            _FakeIndexSource(indexBoard ?? indices()),
          ),
          preferencesStoreProvider.overrideWithValue(
            InMemoryPreferencesStore(),
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

  testWidgets('the Stocks section is absent unless interactive content is on', (
    WidgetTester tester,
  ) async {
    await pumpForYou(tester, interactiveContent: false);

    expect(find.text('Stocks'), findsNothing);
    expect(find.text('Nasdaq Comp'), findsNothing);
  });

  testWidgets('the Stocks card lists the indices with attribution', (
    WidgetTester tester,
  ) async {
    await pumpForYou(tester, interactiveContent: true);

    expect(find.text('Stocks'), findsWidgets);
    expect(find.text('Nasdaq Comp'), findsOneWidget);
    expect(find.text('NASDAQ Composite'), findsOneWidget);
    expect(find.text('26,140.03'), findsOneWidget);
    expect(find.text('-3.94%'), findsOneWidget);
    expect(find.text('+0.10%'), findsOneWidget);
    expect(find.textContaining('Powered by yahoo/finance'), findsOneWidget);
    expect(find.text('Market is closed'), findsOneWidget);
  });

  testWidgets('tapping the card opens the Stocks page', (
    WidgetTester tester,
  ) async {
    await pumpForYou(tester, interactiveContent: true);

    await tester.tap(find.text('Nasdaq Comp'));
    await tester.pumpAndSettle();

    expect(find.text('stocks page'), findsOneWidget);
  });

  test('a cached FX board is served when the rates service is down', () async {
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

  test('a fresh FX board replaces the cached one', () async {
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
