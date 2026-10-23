import 'dart:convert';

import 'package:flutter/material.dart';
// Riverpod 3 keeps `Override` out of the main entrypoint.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/video_moment.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/search/presentation/search_page.dart';

import '../feed/support/fakes.dart';
import '../feed/support/test_harness.dart';

/// Search v1: the field, debounced results, recents and the two result groups.
void main() {
  Article story(String id, String title) =>
      testArticle(id: id, title: title, categoryId: 'top');

  final List<VideoMoment> videos = <VideoMoment>[
    VideoMoment(
      id: 'video-1',
      title: 'Leone Stars training session',
      source: 'SLBC Sports',
      thumbnailUrl: '',
      url: 'https://youtu.be/dQw4w9WgXcQ',
    ),
  ];

  Future<InMemoryPreferencesStore> pumpSearch(
    WidgetTester tester, {
    List<Article> articles = const <Article>[],
    Map<String, Object?> prefs = const <String, Object?>{},
  }) async {
    final InMemoryPreferencesStore store = InMemoryPreferencesStore(prefs);
    final GoRouter router = GoRouter(
      initialLocation: '/search',
      routes: <RouteBase>[
        GoRoute(
          path: '/search',
          builder: (BuildContext context, GoRouterState state) =>
              const SearchPage(),
        ),
        GoRoute(
          path: '/article/:id',
          builder: (BuildContext context, GoRouterState state) =>
              Scaffold(body: Text('article ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/video/:id',
          builder: (BuildContext context, GoRouterState state) =>
              Scaffold(body: Text('video ${state.pathParameters['id']}')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...feedTestOverrides(
            articles: FakeArticleRepository(topStories: articles),
          ),
          preferencesStoreProvider.overrideWithValue(store),
          videoMomentsProvider.overrideWith(() => _FixedVideoMoments(videos)),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  Future<void> type(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  testWidgets('an empty search offers what it covers', (
    WidgetTester tester,
  ) async {
    await pumpSearch(tester);

    expect(find.text('Search SLNews'), findsOneWidget);
    expect(
      find.textContaining('Find stories, videos and topics'),
      findsOneWidget,
    );
  });

  testWidgets('recent searches are listed and reusable', (
    WidgetTester tester,
  ) async {
    await pumpSearch(
      tester,
      articles: <Article>[story('a-1', 'Budget passes in parliament')],
      prefs: <String, Object?>{
        SearchPage.recentKey: jsonEncode(<String>['budget', 'leone stars']),
      },
    );

    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('budget'), findsOneWidget);

    await tester.tap(find.text('budget'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Budget passes in parliament'), findsOneWidget);
  });

  testWidgets('typing debounces into grouped results', (
    WidgetTester tester,
  ) async {
    await pumpSearch(
      tester,
      articles: <Article>[
        story('a-1', 'Budget passes in parliament'),
        story('a-2', 'Leone Stars draw in Guinea'),
      ],
    );

    await type(tester, 'budget');

    expect(find.text('Stories'), findsOneWidget);
    expect(find.text('Budget passes in parliament'), findsOneWidget);
    expect(find.text('Leone Stars draw in Guinea'), findsNothing);
  });

  testWidgets('videos answering the query are grouped separately', (
    WidgetTester tester,
  ) async {
    await pumpSearch(
      tester,
      articles: <Article>[story('a-1', 'Leone Stars draw in Guinea')],
    );

    await type(tester, 'leone');

    expect(find.text('Stories'), findsOneWidget);
    expect(find.text('Videos'), findsOneWidget);
    expect(find.text('SLBC Sports'), findsOneWidget);
  });

  testWidgets('a query with no answers says so', (WidgetTester tester) async {
    await pumpSearch(
      tester,
      articles: <Article>[story('a-1', 'Budget passes in parliament')],
    );

    await type(tester, 'zzzz');

    expect(find.textContaining('No results for'), findsOneWidget);
  });

  testWidgets('a submitted query is remembered in storage', (
    WidgetTester tester,
  ) async {
    final InMemoryPreferencesStore store = await pumpSearch(
      tester,
      articles: <Article>[story('a-1', 'Budget passes in parliament')],
    );

    await tester.enterText(find.byType(TextField), 'budget');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final String? raw = store.string(SearchPage.recentKey);
    expect(raw, isNotNull);
    expect(raw, contains('budget'));
  });

  testWidgets('tapping a story opens the reader', (WidgetTester tester) async {
    await pumpSearch(
      tester,
      articles: <Article>[story('a-1', 'Budget passes in parliament')],
    );

    await type(tester, 'budget');
    await tester.tap(find.text('Budget passes in parliament'));
    await tester.pumpAndSettle();

    expect(find.text('article a-1'), findsOneWidget);
  });

  testWidgets('clearing the field returns to the recent list', (
    WidgetTester tester,
  ) async {
    await pumpSearch(
      tester,
      articles: <Article>[story('a-1', 'Budget passes in parliament')],
    );

    await type(tester, 'budget');
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsNothing);
  });
}

class _FixedVideoMoments extends VideoMomentsController {
  _FixedVideoMoments(this.fixed);

  final List<VideoMoment> fixed;

  @override
  List<VideoMoment> build() => fixed;
}
