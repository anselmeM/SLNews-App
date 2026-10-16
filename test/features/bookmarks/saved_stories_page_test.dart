import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/bookmarks/presentation/saved_stories_page.dart';

import 'support/fakes.dart';
import 'support/test_harness.dart';

/// Widget tests for the offline reading list.
///
/// Reuses the Feed agent's in-memory fakes: the page must resolve bookmarked
/// ids through the repository only, so zero network is exercised by design.
void main() {
  final Article saved = testArticle(
    id: 'saved-1',
    title: 'Saved ferry timetable story',
    publishedAt: DateTime(2026, 10, 15, 9),
  );
  final Article other = testArticle(
    id: 'other-1',
    title: 'Never bookmarked story',
    publishedAt: DateTime(2026, 10, 15, 8),
  );

  Future<void> pumpSaved(
    WidgetTester tester, {
    required Set<String> bookmarkedIds,
  }) async {
    await useTallSurface(tester, size: const Size(390, 900));
    final GoRouter router = GoRouter(
      initialLocation: '/saved',
      routes: <RouteBase>[
        GoRoute(
          path: '/saved',
          builder: (BuildContext context, GoRouterState state) =>
              const SavedStoriesPage(),
        ),
        GoRoute(
          path: '/article/:id',
          builder: (BuildContext context, GoRouterState state) =>
              Scaffold(body: Text('article ${state.pathParameters['id']}')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: feedTestOverrides(
          articles: FakeArticleRepository(
            topStories: <Article>[saved, other],
            localStories: <Article>[saved],
          ),
          userState: FakeUserStateRepository(bookmarkedIds: bookmarkedIds),
        ),
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders every saved article and nothing else', (
    WidgetTester tester,
  ) async {
    await pumpSaved(tester, bookmarkedIds: <String>{saved.id});

    expect(find.text('Saved stories'), findsWidgets);
    expect(find.text('Saved ferry timetable story'), findsOneWidget);
    expect(find.text('Never bookmarked story'), findsNothing);
  });

  testWidgets('shows the empty state when nothing is saved', (
    WidgetTester tester,
  ) async {
    await pumpSaved(tester, bookmarkedIds: const <String>{});

    expect(find.text('Nothing saved yet'), findsOneWidget);
    expect(
      find.text('Tap Save on any story to read it offline.'),
      findsOneWidget,
    );
  });

  testWidgets('remove control drops the story from the list', (
    WidgetTester tester,
  ) async {
    await pumpSaved(tester, bookmarkedIds: <String>{saved.id});

    await tester.tap(find.byTooltip('Remove from saved'));
    await tester.pumpAndSettle();

    expect(find.text('Removed from saved'), findsOneWidget);
    expect(find.text('Nothing saved yet'), findsOneWidget);
  });

  testWidgets('tapping a saved story opens the reader route', (
    WidgetTester tester,
  ) async {
    await pumpSaved(tester, bookmarkedIds: <String>{saved.id});

    await tester.tap(find.text('Saved ferry timetable story'));
    await tester.pumpAndSettle();

    expect(find.text('article saved-1'), findsOneWidget);
  });
}
