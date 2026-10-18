import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:slnews_mobile/core/data/local/article_cache.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InMemoryArticleCache', () {
    test('round-trips articles and records a sync timestamp', () async {
      final InMemoryArticleCache cache = InMemoryArticleCache();
      await cache.init();
      expect(cache.read('all'), isEmpty);
      expect(cache.syncedAt('all'), isNull);

      final DateTime before = DateTime.now().toUtc();
      await cache.write('all', <Article>[article('a'), article('b')]);

      final List<Article> read = cache.read('all');
      expect(read.map((Article a) => a.id), <String>['a', 'b']);
      expect(read.first.title, 'Headline a');
      expect(read.first.publisher.name, 'Awoko Newspaper');
      expect(read.first.publishedAt, DateTime.utc(2026, 10, 1, 12));

      final DateTime? synced = cache.syncedAt('all');
      expect(synced, isNotNull);
      expect(
        synced!.isBefore(before.subtract(const Duration(seconds: 5))),
        isFalse,
      );
    });

    test('skips a corrupt entry and prunes it from storage', () async {
      final String raw = jsonEncode(<Object>[
        article('keep').toJson(),
        <String, Object>{'id': 7},
        'not-a-map',
      ]);
      final InMemoryArticleCache cache = InMemoryArticleCache(<String, Object?>{
        'articles:all': raw,
        'synced:all': '2026-10-15T10:00:00.000Z',
      });

      expect(cache.read('all').map((Article a) => a.id), <String>['keep']);
      // The original sync time survives the prune.
      expect(cache.syncedAt('all'), DateTime.utc(2026, 10, 15, 10));

      final Object? pruned = cache.rawValues['articles:all'];
      expect(pruned, isA<String>());
      expect(jsonDecode(pruned! as String), hasLength(1));
    });

    test('drops an unparseable payload and deletes the key', () async {
      final InMemoryArticleCache cache = InMemoryArticleCache(<String, Object?>{
        'articles:all': '{not json',
        'synced:all': '2026-10-15T10:00:00.000Z',
      });

      expect(cache.read('all'), isEmpty);
      expect(cache.rawValues.containsKey('articles:all'), isFalse);
    });

    test(
      'clear removes cached articles and timestamps but nothing else',
      () async {
        final InMemoryArticleCache cache = InMemoryArticleCache(
          <String, Object?>{
            'articles:all': '[]',
            'articles:category:top': '[]',
            'synced:all': '2026-10-15T10:00:00.000Z',
            'user.bookmarks': <String>['a'],
          },
        );

        await cache.clear();

        expect(
          cache.rawValues.keys.where((String k) => k.startsWith('articles:')),
          isEmpty,
        );
        expect(
          cache.rawValues.keys.where((String k) => k.startsWith('synced:')),
          isEmpty,
        );
        expect(cache.rawValues['user.bookmarks'], isNotNull);
      },
    );
  });

  group('HiveArticleCache', () {
    late Directory directory;

    setUpAll(() async {
      directory = await Directory.systemTemp.createTemp('slnews_cache_test');
      Hive.init(directory.path);
    });

    tearDownAll(() async {
      await Hive.close();
      if (directory.existsSync()) await directory.delete(recursive: true);
    });

    test('reads safely before init', () {
      final HiveArticleCache cache = HiveArticleCache(
        boxName: 'cache_never_opened',
      );
      expect(cache.read('all'), isEmpty);
      expect(cache.syncedAt('all'), isNull);
      expect(cache.keys(), isEmpty);
    });

    test('persists articles across cache instances', () async {
      final HiveArticleCache first = await HiveArticleCache.open(
        boxName: 'cache_persist',
      );
      await first.write('all', <Article>[article('hive-1')]);

      final HiveArticleCache second = await HiveArticleCache.open(
        boxName: 'cache_persist',
      );
      expect(second.read('all').single.id, 'hive-1');
      expect(second.read('all').single.title, 'Headline hive-1');
      expect(second.syncedAt('all'), isNotNull);
    });

    test(
      'skips and removes a corrupt string written straight into the box',
      () async {
        final Box<dynamic> box = await Hive.openBox<dynamic>('cache_corrupt');
        await box.put('articles:all', '{not json');

        final HiveArticleCache cache = HiveArticleCache(
          boxName: 'cache_corrupt',
        );
        await cache.init();

        expect(cache.read('all'), isEmpty);
        expect(box.get('articles:all'), isNull);
      },
    );

    test('clear empties the box', () async {
      final HiveArticleCache cache = await HiveArticleCache.open(
        boxName: 'cache_clear',
      );
      await cache.write('all', <Article>[article('x')]);
      await cache.clear();
      expect(cache.read('all'), isEmpty);
      expect(cache.syncedAt('all'), isNull);
      expect(cache.keys(), isEmpty);
    });
  });

  test('keeps the article body so a cached story reads offline', () async {
    final InMemoryArticleCache cache = InMemoryArticleCache();
    await cache.init();

    await cache.write('all', <Article>[
      article('with-body', bodyHtml: '<p>The full report, paragraph one.</p>'),
    ]);

    final Article restored = cache.read('all').single;
    expect(restored.bodyHtml, contains('paragraph one'));
    expect(restored.estimatedReadingMinutes, greaterThanOrEqualTo(1));
  });
}
