import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/publisher.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/publisher/presentation/publisher_page.dart';

import '../feed/support/fakes.dart';

void main() {
  final Article first = testArticle(
    id: 'a',
    title: 'Awoko leads with the budget',
    publishedAt: DateTime.utc(2026, 11, 19),
  );
  final Article second = testArticle(
    id: 'b',
    title: 'Awoko follows up on the review',
    publishedAt: DateTime.utc(2026, 11, 18),
  );
  final Article other = Article(
    id: 'c',
    title: 'A different outlet story',
    publisher: const Publisher(id: 'bbc', name: 'BBC Africa'),
    publishedAt: DateTime.utc(2026, 11, 19),
  );

  Future<FakeFollowingRepository> pumpPage(
    WidgetTester tester, {
    required String publisherId,
    String? label,
    List<Article> articles = const <Article>[],
  }) async {
    final FakeFollowingRepository following = FakeFollowingRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          preferencesStoreProvider.overrideWithValue(
            InMemoryPreferencesStore(),
          ),
          articleRepositoryProvider.overrideWithValue(
            FakeArticleRepository(topStories: articles),
          ),
          followingRepositoryProvider.overrideWithValue(following),
          userStateProvider.overrideWithValue(FakeUserStateRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: PublisherPage(publisherId: publisherId, publisherLabel: label),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return following;
  }

  testWidgets('lists only that publisher and can follow it', (
    WidgetTester tester,
  ) async {
    final FakeFollowingRepository following = await pumpPage(
      tester,
      publisherId: 'awoko',
      label: 'Awoko Newspaper',
      articles: <Article>[first, second, other],
    );

    expect(find.text('Awoko Newspaper'), findsWidgets);
    expect(find.text('Awoko leads with the budget'), findsOneWidget);
    expect(find.text('Awoko follows up on the review'), findsOneWidget);
    expect(find.text('A different outlet story'), findsNothing);

    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();

    expect(following.isFollowed('publisher:awoko'), isTrue);
    expect(find.text('Following'), findsOneWidget);
  });

  testWidgets('a publisher with no local stories still shows an empty state', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester, publisherId: 'awoko', label: 'Awoko Newspaper');

    expect(find.text('No stories yet'), findsOneWidget);
    expect(find.text('Latest stories'), findsNothing);
  });
}
