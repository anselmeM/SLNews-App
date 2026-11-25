import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/domain/auth/account_scope.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/auth_providers.dart';
import 'package:slnews_mobile/core/providers/reading_history_provider.dart';

import '../features/feed/support/fakes.dart';

void main() {
  late InMemoryPreferencesStore store;
  late ProviderContainer container;

  ProviderContainer build({List<Article> articles = const <Article>[]}) {
    final ProviderContainer c = ProviderContainer(
      overrides: <Override>[
        preferencesStoreProvider.overrideWithValue(store),
        articleRepositoryProvider.overrideWithValue(
          FakeArticleRepository(topStories: articles),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    store = InMemoryPreferencesStore();
    container = build();
  });

  test('records newest first, deduplicates and persists', () async {
    final ReadingHistoryController history = container.read(
      readingHistoryProvider.notifier,
    );

    await history.record('a');
    await history.record('b');
    await history.record('a');

    expect(container.read(readingHistoryProvider), <String>['a', 'b']);
    expect(
      store.string(readingHistoryKeyFor(anonymousAccountId)),
      isNotNull,
      reason: 'history is written to preferences',
    );

    final ProviderContainer reopened = build();
    expect(reopened.read(readingHistoryProvider), <String>['a', 'b']);
  });

  test('caps the list so the document stays small', () async {
    final ReadingHistoryController history = container.read(
      readingHistoryProvider.notifier,
    );
    for (int i = 0; i < ReadingHistoryController.limit + 5; i++) {
      await history.record('article-$i');
    }

    expect(
      container.read(readingHistoryProvider),
      hasLength(ReadingHistoryController.limit),
    );
    expect(container.read(readingHistoryProvider).first, 'article-24');
  });

  test('clear empties memory and storage', () async {
    final ReadingHistoryController history = container.read(
      readingHistoryProvider.notifier,
    );
    await history.record('a');
    await history.clear();

    expect(container.read(readingHistoryProvider), isEmpty);
    expect(store.string(readingHistoryKeyFor(anonymousAccountId)), isNull);
  });

  test('reading history is isolated per account', () async {
    final ProviderContainer a = ProviderContainer(
      overrides: <Override>[
        preferencesStoreProvider.overrideWithValue(store),
        activeAccountKeyProvider.overrideWithValue('account-a'),
      ],
    );
    addTearDown(a.dispose);
    await a.read(readingHistoryProvider.notifier).record('a-story');

    final ProviderContainer b = ProviderContainer(
      overrides: <Override>[
        preferencesStoreProvider.overrideWithValue(store),
        activeAccountKeyProvider.overrideWithValue('account-b'),
      ],
    );
    addTearDown(b.dispose);

    expect(a.read(readingHistoryProvider), <String>['a-story']);
    expect(b.read(readingHistoryProvider), isEmpty);
    expect(store.string(readingHistoryKeyFor('account-a')), isNotNull);
    expect(store.string(readingHistoryKeyFor('account-b')), isNull);
  });

  test('recently read resolves ids against the article repository', () async {
    final Article first = testArticle(id: 'a', title: 'First');
    final Article second = testArticle(id: 'b', title: 'Second');
    container = build(articles: <Article>[first, second]);
    final ReadingHistoryController history = container.read(
      readingHistoryProvider.notifier,
    );

    await history.record('a');
    await history.record('missing');
    await history.record('b');

    final List<Article> resolved = await container.read(
      recentlyReadArticlesProvider.future,
    );
    expect(resolved.map((Article article) => article.id), <String>['b', 'a']);
  });
}
