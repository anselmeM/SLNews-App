import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/local/article_cache.dart';
import 'package:slnews_mobile/core/data/repositories/offline_first_article_repository.dart';
import 'package:slnews_mobile/core/data/seed/seed_data.dart';
import 'package:slnews_mobile/core/data/seed/seed_loader.dart';
import 'package:slnews_mobile/core/data/sources/api_client.dart';
import 'package:slnews_mobile/core/data/sources/feed_source.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/publisher.dart';

import 'fakes.dart';

OfflineFirstArticleRepository build({
  required List<FeedSource> sources,
  ArticleCache? cache,
  SeedData? seed,
}) => OfflineFirstArticleRepository(
  sources: sources,
  cache: cache ?? InMemoryArticleCache(),
  seedLoader: InMemorySeedLoader(seed ?? SeedData.empty),
);

void main() {
  group('OfflineFirstArticleRepository resolution order', () {
    test('falls back to the bundled seed when every source fails', () async {
      final OfflineFirstArticleRepository repository = build(
        sources: <FeedSource>[
          FakeFeedSource(
            config: config('awoko'),
            error: ApiException('offline'),
          ),
        ],
        seed: seedData(
          articles: <Article>[article('seed-1'), article('seed-2')],
        ),
      );

      final List<Article> stories = await repository.topStories();
      expect(
        stories.map((Article a) => a.id),
        containsAll(<String>['seed-1', 'seed-2']),
      );
      expect(
        repository.isOffline,
        isFalse,
        reason: 'a launch with no failed fetch must not claim to be offline',
      );
      expect(repository.lastSyncedAt, isNull);
    });

    test('hydrates from the cache written by a previous run', () async {
      final InMemoryArticleCache cache = InMemoryArticleCache();
      final OfflineFirstArticleRepository online = build(
        sources: <FeedSource>[
          FakeFeedSource(
            config: config('a'),
            articles: <Article>[
              article('a-1', publishedAt: DateTime.utc(2026, 10, 5)),
            ],
          ),
        ],
        cache: cache,
      );
      await online.refresh();
      expect(cache.syncedAt('all'), isNotNull);

      final OfflineFirstArticleRepository offline = build(
        sources: <FeedSource>[
          FakeFeedSource(config: config('b'), error: ApiException('down')),
        ],
        cache: cache,
      );

      expect(
        (await offline.topStories()).map((Article a) => a.id),
        contains('a-1'),
      );
      expect(
        offline.isOffline,
        isFalse,
        reason: 'no refresh was attempted, so the banner has nothing to report',
      );
      expect(offline.lastSyncedAt, isNotNull, reason: 'carried over from disk');
    });

    test('topStories prefers breaking and live stories, then fills with the latest', () async {
      final OfflineFirstArticleRepository repository = build(
        sources: const <FeedSource>[],
        seed: seedData(
          articles: <Article>[
            article('plain-new', publishedAt: DateTime.utc(2026, 10, 14)),
            article(
              'breaking-old',
              publishedAt: DateTime.utc(2026, 10, 2),
              isBreaking: true,
            ),
            article(
              'live-mid',
              publishedAt: DateTime.utc(2026, 10, 9),
              isLive: true,
            ),
          ],
        ),
      );

      expect(
        (await repository.topStories(limit: 3)).map((Article a) => a.id),
        <String>['live-mid', 'breaking-old', 'plain-new'],
      );
    });
  });

  group('OfflineFirstArticleRepository.refresh', () {
    test('merges sources, de-duplicates by id keeping the newest and sorts descending', () async {
      final OfflineFirstArticleRepository repository = build(
        sources: <FeedSource>[
          FakeFeedSource(
            config: config('a'),
            articles: <Article>[
              article(
                'dup',
                title: 'Older copy',
                publishedAt: DateTime.utc(2026, 10, 1),
              ),
              article('a-1', publishedAt: DateTime.utc(2026, 10, 5)),
            ],
          ),
          FakeFeedSource(
            config: config('b'),
            articles: <Article>[
              article(
                'dup',
                title: 'Newer copy',
                publishedAt: DateTime.utc(2026, 10, 9),
              ),
            ],
          ),
        ],
        seed: SeedData.empty,
      );

      final List<Article> merged = await repository.refresh();
      expect(merged.map((Article a) => a.id), <String>['dup', 'a-1']);
      expect(merged.first.title, 'Newer copy');
      expect(repository.isOffline, isFalse);
      expect(repository.lastSyncedAt, isNotNull);
    });

    test(
      'keeps seeded content and stays offline when nothing could be fetched',
      () async {
        final OfflineFirstArticleRepository repository = build(
          sources: <FeedSource>[
            FakeFeedSource(config: config('a'), error: ApiException('timeout')),
            FakeFeedSource(
              config: config('b'),
              error: StateError('socket closed'),
            ),
          ],
          seed: seedData(articles: <Article>[article('seed-1')]),
        );

        final List<Article> refreshed = await repository.refresh();
        expect(refreshed.map((Article a) => a.id), contains('seed-1'));
        expect(repository.isOffline, isTrue);
        expect(repository.lastSyncedAt, isNull);
      },
    );

    test('de-duplicates concurrent refresh calls', () async {
      final FakeFeedSource source = FakeFeedSource(
        config: config('a'),
        articles: <Article>[article('a-1')],
      );
      final OfflineFirstArticleRepository repository = build(
        sources: <FeedSource>[source],
      );

      await Future.wait(<Future<List<Article>>>[
        repository.refresh(),
        repository.refresh(),
        repository.refresh(),
      ]);

      expect(source.fetchCount, 1);
    });

    test('survives a source that never answers', () async {
      final FeedSource slow = FakeFeedSource(
        config: config('slow'),
        articles: <Article>[article('slow-1')],
        delay: const Duration(seconds: 30),
      );
      final FakeFeedSource fast = FakeFeedSource(
        config: config('fast'),
        articles: <Article>[article('fast-1')],
      );
      final OfflineFirstArticleRepository repository = build(
        sources: <FeedSource>[slow, fast],
      );

      final List<Article> merged = await repository.refresh().timeout(
        OfflineFirstArticleRepository.sourceTimeout +
            const Duration(seconds: 5),
      );

      expect(merged.map((Article a) => a.id), contains('fast-1'));
    });
  });

  group('OfflineFirstArticleRepository reads', () {
    Future<OfflineFirstArticleRepository> seeded() async => build(
      sources: <FeedSource>[FakeFeedSource(config: config('awoko'))],
      seed: seedData(
        articles: <Article>[
          article(
            'p1',
            categoryId: 'politics',
            publishedAt: DateTime.utc(2026, 10, 10),
          ),
          article(
            'p2',
            categoryId: 'politics',
            publishedAt: DateTime.utc(2026, 10, 9),
          ),
          article(
            'b1',
            categoryId: 'business',
            publishedAt: DateTime.utc(2026, 10, 8),
          ),
          article(
            'h1',
            categoryId: 'health',
            title: 'Guma Valley water shutdown',
            tags: <String>['freetown'],
          ),
        ],
      ),
    );

    test('byCategory filters to the category, sorts and never returns empty for a pill', () async {
      final OfflineFirstArticleRepository repository = await seeded();

      expect(
        (await repository.byCategory('politics')).map((Article a) => a.id),
        <String>['p1', 'p2'],
      );
      expect(
        (await repository.byCategory('top')).map((Article a) => a.id),
        <String>['p1', 'p2', 'b1', 'h1'],
      );
      expect(
        await repository.byCategory('cars'),
        isNotEmpty,
        reason: 'unseeded pill falls back to the feed',
      );
    });

    test('byId and search read the bundle', () async {
      final OfflineFirstArticleRepository repository = await seeded();

      expect(
        (await repository.byId('h1'))?.title,
        'Guma Valley water shutdown',
      );
      expect(await repository.byId('missing'), isNull);
      expect(
        (await repository.search('guma')).map((Article a) => a.id),
        <String>['h1'],
      );
      expect(
        (await repository.search('freetown')).map((Article a) => a.id),
        <String>['h1'],
      );
      expect(await repository.search('   '), isEmpty);
    });

    test('search ranks a headline match above a body-only match', () async {
      final OfflineFirstArticleRepository repository = build(
        sources: <FeedSource>[
          FakeFeedSource(
            config: config('awoko'),
            articles: <Article>[
              article(
                'body-only',
                title: 'Market roundup',
                summary: 'Commodity prices',
                bodyHtml: '<p>Guma Valley raised its tariffs.</p>',
              ),
              article(
                'headline',
                title: 'Guma Valley announces water shutdown',
                summary: 'Freetown',
                bodyHtml: '<p>Details inside.</p>',
              ),
            ],
          ),
        ],
      );

      expect(
        (await repository.search('guma')).map((Article a) => a.id),
        <String>['headline', 'body-only'],
      );
    });

    test(
      'search matches the publisher name and merges the bundled seed',
      () async {
        final OfflineFirstArticleRepository repository = build(
          sources: <FeedSource>[
            FakeFeedSource(
              config: config('awoko'),
              articles: <Article>[
                article(
                  'network-1',
                  title: 'Budget speech postponed',
                  publisher: testPublisher.copyWith(name: 'Awoko Newspaper'),
                ),
              ],
            ),
          ],
          seed: seedData(
            articles: <Article>[
              article('seed-1', title: 'Awoko marks thirty years'),
            ],
          ),
        );

        await repository.refresh();

        // The seed used to be consulted only when the live/cached list returned
        // nothing, so one live match hid every seeded match.
        final List<String> ids = (await repository.search('awoko'))
            .map((Article a) => a.id)
            .toList();
        expect(ids, contains('network-1'));
        expect(ids, contains('seed-1'));
      },
    );
  });

  test('serves the cached body through byId while sources are down', () async {
    final InMemoryArticleCache cache = InMemoryArticleCache();
    final OfflineFirstArticleRepository online = build(
      sources: <FeedSource>[
        FakeFeedSource(
          config: config('a'),
          articles: <Article>[
            article('a-1', bodyHtml: '<p>Cached paragraph survives.</p>'),
          ],
        ),
      ],
      cache: cache,
    );
    await online.refresh();

    final OfflineFirstArticleRepository offline = build(
      sources: <FeedSource>[
        FakeFeedSource(config: config('b'), error: ApiException('down')),
      ],
      cache: cache,
    );

    final Article? story = await offline.byId('a-1');
    expect(story, isNotNull);
    expect(story!.bodyHtml, contains('Cached paragraph survives'));
  });

  group('byId on-demand fetch (B4)', () {
    test(
      'fetches an uncached story, caches it, then serves it offline',
      () async {
        final InMemoryArticleCache cache = InMemoryArticleCache();
        final Article target = article('deep-link-1');
        int calls = 0;

        final OfflineFirstArticleRepository online =
            OfflineFirstArticleRepository(
              sources: const <FeedSource>[],
              cache: cache,
              seedLoader: InMemorySeedLoader(SeedData.empty),
              fetchById: (String id) async {
                calls++;
                return id == target.id ? target : null;
              },
            );

        expect((await online.byId('deep-link-1'))?.id, 'deep-link-1');
        expect(calls, 1);
        expect(
          cache.read('all').map((Article a) => a.id),
          contains('deep-link-1'),
          reason: 'the fetched story is cached for the next offline open',
        );

        // A later run with no fetcher and no network still resolves it from cache.
        final OfflineFirstArticleRepository offline =
            OfflineFirstArticleRepository(
              sources: const <FeedSource>[],
              cache: cache,
              seedLoader: InMemorySeedLoader(SeedData.empty),
            );
        expect((await offline.byId('deep-link-1'))?.id, 'deep-link-1');
      },
    );

    test('a failed or empty fetch leaves byId null without throwing', () async {
      final OfflineFirstArticleRepository failing =
          OfflineFirstArticleRepository(
            sources: const <FeedSource>[],
            cache: InMemoryArticleCache(),
            seedLoader: InMemorySeedLoader(SeedData.empty),
            fetchById: (String id) async => throw ApiException('down'),
          );
      expect(await failing.byId('missing'), isNull);

      final OfflineFirstArticleRepository empty = OfflineFirstArticleRepository(
        sources: const <FeedSource>[],
        cache: InMemoryArticleCache(),
        seedLoader: InMemorySeedLoader(SeedData.empty),
        fetchById: (String id) async => null,
      );
      expect(await empty.byId('missing'), isNull);
    });
  });

  group('byPublisher', () {
    Article by(String id, String publisherId, DateTime publishedAt) => Article(
      id: id,
      title: id,
      publisher: Publisher(id: publisherId, name: publisherId),
      publishedAt: publishedAt,
    );

    test('returns one outlet newest first, honours limit and blanks', () async {
      final OfflineFirstArticleRepository repository = build(
        sources: const <FeedSource>[],
        seed: seedData(
          articles: <Article>[
            by('awoko-old', 'awoko', DateTime.utc(2026, 11, 18)),
            by('bbc-1', 'bbc', DateTime.utc(2026, 11, 19)),
            by('awoko-new', 'awoko', DateTime.utc(2026, 11, 19)),
          ],
        ),
      );

      final List<Article> rows = await repository.byPublisher('awoko');
      expect(rows.map((Article a) => a.id), <String>['awoko-new', 'awoko-old']);

      final List<Article> limited = await repository.byPublisher(
        'awoko',
        limit: 1,
      );
      expect(limited.single.id, 'awoko-new');

      expect(await repository.byPublisher(''), isEmpty);
      expect(await repository.byPublisher('unknown'), isEmpty);
    });
  });
}
