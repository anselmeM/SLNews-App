import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/personalization_profile.dart';
import 'package:slnews_mobile/core/providers/aggregate_metrics.dart';
import 'package:slnews_mobile/core/providers/personalization_profile.dart';
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
    expect(
      capturedRef
          .read(personalizationProfileProvider)
          .events
          .any((EngagementEvent event) => event.kind == EngagementKind.save),
      isTrue,
      reason: 'saving teaches the local personalization profile',
    );

    await tester.tap(find.text('unsave'));
    await tester.pumpAndSettle();

    expect(
      capturedRef.read(bookmarksControllerProvider),
      isNot(contains(article.id)),
    );
    expect(find.text('Removed from saved'), findsOneWidget);
  });

  testWidgets('consented saves reach the aggregate metrics store', (
    WidgetTester tester,
  ) async {
    final FakeUserStateRepository userState = FakeUserStateRepository()
      ..analyticsEnabled = true;
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
                body: ElevatedButton(
                  onPressed: () => handleArticleAction(
                    context,
                    ref,
                    article,
                    ArticleAction.bookmark,
                  ),
                  child: const Text('save'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 20));

    expect(capturedRef.read(aggregateMetricsProvider).totalCount, 1);
  });

  testWidgets('show less like this hides the story and records dismissal', (
    WidgetTester tester,
  ) async {
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        overrides: feedTestOverrides(
          articles: FakeArticleRepository(topStories: <Article>[article]),
        ),
        child: themedChild(
          Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              capturedRef = ref;
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () => handleArticleAction(
                    context,
                    ref,
                    article,
                    ArticleAction.lessLikeThis,
                  ),
                  child: const Text('less'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('less'));
    await tester.pumpAndSettle();

    expect(
      capturedRef.read(personalizationProfileProvider).dismissedArticleIds(),
      contains(article.id),
    );
    expect(find.text("We'll show you less like this"), findsOneWidget);
  });

  testWidgets('opted-out readers do not train the local profile on save', (
    WidgetTester tester,
  ) async {
    final FakeUserStateRepository userState = FakeUserStateRepository()
      ..personalizeFeed = false;
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
                body: ElevatedButton(
                  onPressed: () => handleArticleAction(
                    context,
                    ref,
                    article,
                    ArticleAction.bookmark,
                  ),
                  child: const Text('save'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();

    expect(capturedRef.read(personalizationProfileProvider).events, isEmpty);
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

  testWidgets('follow publisher subscribes through the shared controller', (
    WidgetTester tester,
  ) async {
    final FakeFollowingRepository following = FakeFollowingRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: feedTestOverrides(
          articles: FakeArticleRepository(),
          following: following,
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
                      ArticleAction.followPublisher,
                    ),
                    child: const Text('follow'),
                  ),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('follow'));
    await tester.pumpAndSettle();

    expect(following.isFollowed('publisher:awoko'), isTrue);
    expect(find.text('Following Awoko Newspaper'), findsOneWidget);
  });
}
