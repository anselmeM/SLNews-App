import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/providers/controllers.dart';
import 'package:slnews_mobile/core/widgets/overflow_menu_button.dart';
import 'package:slnews_mobile/features/feed/presentation/widgets/article_actions.dart';

import 'support/fakes.dart';
import 'support/test_harness.dart';

/// Verifies the shared kebab-menu handler: bookmarking round-trips through the
/// controller and every other action ends in reader-facing feedback.
void main() {
  final Article article = testArticle(
    id: 'story-1',
    title: 'Ferry terminal reopens',
    sourceUrl: 'https://example.com/story-1',
  );

  testWidgets('bookmark action persists through bookmarksControllerProvider', (
    WidgetTester tester,
  ) async {
    final FakeUserStateRepository userState = FakeUserStateRepository();
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        overrides: feedTestOverrides(
          articles: FakeArticleRepository(topStories: <Article>[article]),
          userState: userState,
        ),
        child: themedChild(
          Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              capturedRef = ref;
              return Scaffold(
                body: Column(
                  children: <Widget>[
                    ElevatedButton(
                      onPressed: () => handleArticleAction(
                        context,
                        ref,
                        article,
                        ArticleAction.bookmark,
                      ),
                      child: const Text('save'),
                    ),
                    ElevatedButton(
                      onPressed: () => handleArticleAction(
                        context,
                        ref,
                        article,
                        ArticleAction.removeBookmark,
                      ),
                      child: const Text('unsave'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();

    expect(capturedRef.read(bookmarksControllerProvider), contains(article.id));
    expect(userState.bookmarkedIds, contains(article.id));
    expect(find.text('Saved for offline reading'), findsOneWidget);

    await tester.tap(find.text('unsave'));
    await tester.pumpAndSettle();

    expect(
      capturedRef.read(bookmarksControllerProvider),
      isNot(contains(article.id)),
    );
    expect(find.text('Removed from saved'), findsOneWidget);
  });

  testWidgets('hide action confirms with a SnackBar and changes no state', (
    WidgetTester tester,
  ) async {
    final FakeUserStateRepository userState = FakeUserStateRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: feedTestOverrides(
          articles: FakeArticleRepository(topStories: <Article>[article]),
          userState: userState,
        ),
        child: themedChild(
          Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) =>
                Scaffold(
                  body: ElevatedButton(
                    onPressed: () => handleArticleAction(
                      context,
                      ref,
                      article,
                      ArticleAction.hide,
                    ),
                    child: const Text('hide'),
                  ),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('hide'));
    await tester.pumpAndSettle();

    expect(find.text('Story hidden from your feed'), findsOneWidget);
    expect(userState.bookmarkedIds, isEmpty);
    expect(userState.likedIds, isEmpty);
  });

  testWidgets('openInBrowser without a link reports instead of throwing', (
    WidgetTester tester,
  ) async {
    final Article withoutUrl = testArticle(id: 'story-2', sourceUrl: null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: feedTestOverrides(articles: FakeArticleRepository()),
        child: themedChild(
          Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) =>
                Scaffold(
                  body: ElevatedButton(
                    onPressed: () => handleArticleAction(
                      context,
                      ref,
                      withoutUrl,
                      ArticleAction.openInBrowser,
                    ),
                    child: const Text('browser'),
                  ),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('browser'));
    await tester.pumpAndSettle();

    expect(find.text('No link available for this story'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('report action acknowledges without a backend call', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: feedTestOverrides(articles: FakeArticleRepository()),
        child: themedChild(
          Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) =>
                Scaffold(
                  body: ElevatedButton(
                    onPressed: () => handleArticleAction(
                      context,
                      ref,
                      article,
                      ArticleAction.report,
                    ),
                    child: const Text('report'),
                  ),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('report'));
    await tester.pumpAndSettle();

    expect(find.text("Thanks — we'll review this story"), findsOneWidget);
  });
}
