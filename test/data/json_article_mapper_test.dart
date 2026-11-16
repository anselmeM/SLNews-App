import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/sources/feed_source.dart';
import 'package:slnews_mobile/core/data/sources/json_article_mapper.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';

/// Unit tests for the loose-JSON normaliser shared by the REST/GraphQL sources.
///
/// The mapper is the single translation point between outlet-shaped payloads and
/// the strict `Article` model, so these cover the envelopes, the field aliases
/// and the fallbacks rather than one happy path.
void main() {
  const FeedSourceConfig config = FeedSourceConfig(
    id: 'awoko',
    outlet: 'Awoko Newspaper',
    publisherId: 'awoko',
    wordmark: 'AWOKO',
    url: 'https://awoko.org/api/news',
    kind: FeedSourceKind.restJson,
    categoryId: 'politics',
    websiteUrl: 'https://awoko.org',
  );

  final DateTime fixedNow = DateTime.utc(2026, 11, 15, 12);

  group('JsonArticleMapper.extractEntries', () {
    test('accepts a bare array', () {
      expect(JsonArticleMapper.extractEntries(<Object?>[1, 2]), <Object?>[
        1,
        2,
      ]);
    });

    test('finds each envelope key, in order', () {
      for (final String key in JsonArticleMapper.defaultPaths) {
        expect(
          JsonArticleMapper.extractEntries(<String, Object?>{
            key: <Object?>['a'],
          }),
          <Object?>['a'],
          reason: 'envelope key $key',
        );
      }
    });

    test('looks one level into data', () {
      expect(
        JsonArticleMapper.extractEntries(<String, Object?>{
          'data': <String, Object?>{
            'articles': <Object?>['nested'],
          },
        }),
        <Object?>['nested'],
      );
      expect(
        JsonArticleMapper.extractEntries(<String, Object?>{
          'data': <Object?>['direct'],
        }),
        <Object?>['direct'],
      );
    });

    test('returns empty for unusable payloads', () {
      expect(JsonArticleMapper.extractEntries(null), isEmpty);
      expect(JsonArticleMapper.extractEntries('nope'), isEmpty);
      expect(
        JsonArticleMapper.extractEntries(<String, Object?>{'unknown': 1}),
        isEmpty,
      );
    });

    test('honours a custom path list', () {
      final Map<String, Object?> payload = <String, Object?>{
        'feed': <Object?>['custom'],
        'items': <Object?>['default'],
      };
      expect(
        JsonArticleMapper.extractEntries(payload, paths: <String>['feed']),
        <Object?>['custom'],
      );
    });
  });

  group('JsonArticleMapper.map', () {
    test('maps a full wire object', () {
      final Article article = JsonArticleMapper.map(
        <String, Object?>{
          'id': 'wire-42',
          'title': '  Budget passes  ',
          'bodyHtml': '<p>Parliament approved the budget.</p>',
          'summary': 'The budget passed.',
          'author': 'A. Reporter',
          'imageUrl': 'https://cdn.example/a.jpg',
          'imageCaption': 'Parliament',
          'imageCredit': 'Reuters',
          'sourceUrl': '/story/budget',
          'publisher': <String, Object?>{
            'id': 'politico',
            'name': 'Politico SL',
            'wordmark': 'POLITICO',
            'logoUrl': 'https://cdn.example/logo.png',
            'websiteUrl': 'https://politicosl.com',
            'country': 'Sierra Leone',
            'isWire': true,
          },
          'publishedAt': '2026-11-14T09:30:00Z',
          'categoryId': 'business',
          'tags': <Object?>['budget', 'parliament', 'budget'],
          'isBreaking': true,
          'isLive': true,
          'readingMinutes': 4,
        },
        config,
        now: fixedNow,
      )!;

      expect(article.id, 'wire-42');
      expect(article.title, 'Budget passes');
      expect(article.summary, 'The budget passed.');
      expect(article.bodyHtml, contains('Parliament'));
      expect(article.author, 'A. Reporter');
      expect(article.imageUrl, 'https://cdn.example/a.jpg');
      expect(article.imageCaption, 'Parliament');
      expect(article.imageCredit, 'Reuters');
      // A relative link resolves against the outlet's website.
      expect(article.sourceUrl, 'https://awoko.org/story/budget');
      expect(article.publisher.name, 'Politico SL');
      expect(article.publisher.id, 'politico');
      expect(article.publisher.isWire, isTrue);
      expect(article.publishedAt, DateTime.utc(2026, 11, 14, 9, 30));
      expect(article.categoryId, 'business');
      expect(article.tags, <String>['budget', 'parliament']);
      expect(article.isBreaking, isTrue);
      expect(article.isLive, isTrue);
      expect(article.readingMinutes, 4);
    });

    test('accepts the headline/name aliases', () {
      expect(
        JsonArticleMapper.map(<String, Object?>{
          'headline': 'A',
        }, config)!.title,
        'A',
      );
      expect(
        JsonArticleMapper.map(<String, Object?>{'name': 'B'}, config)!.title,
        'B',
      );
    });

    test('rejects objects without a title', () {
      expect(JsonArticleMapper.map(<String, Object?>{}, config), isNull);
      expect(JsonArticleMapper.map('a string', config), isNull);
      expect(
        JsonArticleMapper.map(<String, Object?>{'title': '   '}, config),
        isNull,
      );
    });

    test('derives the id from the link, else from the outlet and title', () {
      final Article fromLink = JsonArticleMapper.map(<String, Object?>{
        'title': 'Budget',
        'url': 'https://awoko.org/story/budget',
      }, config)!;
      expect(fromLink.id, isNotEmpty);
      expect(fromLink.id, isNot('0'));

      final Article fromParts = JsonArticleMapper.map(
        <String, Object?>{'title': 'Budget'},
        config,
        now: fixedNow,
      )!;
      expect(fromParts.id, isNot(fromLink.id));
    });

    test('falls back through the body when no summary is supplied', () {
      final Article article = JsonArticleMapper.map(<String, Object?>{
        'title': 'Budget',
        'content': '<p>${'word ' * 80}</p>',
      }, config)!;

      expect(article.summary, isNotEmpty);
      expect(article.summary.length, lessThanOrEqualTo(241));
      expect(article.summary.contains('<'), isFalse);
    });

    test('falls back to the outlet publisher and config category', () {
      final Article article = JsonArticleMapper.map(
        <String, Object?>{'title': 'Budget'},
        config,
        now: fixedNow,
      )!;

      expect(article.publisher.name, 'Awoko Newspaper');
      expect(article.publisher.id, 'awoko');
      expect(article.publisher.wordmark, 'AWOKO');
      expect(article.categoryId, 'politics');
      expect(article.publishedAt, fixedNow);
      expect(article.isBreaking, isFalse);
    });

    test('accepts a publisher given as a plain name', () {
      final Article article = JsonArticleMapper.map(<String, Object?>{
        'title': 'Budget',
        'source': 'Wire Desk',
      }, config)!;

      expect(article.publisher.name, 'Wire Desk');
      expect(article.publisher.id, 'awoko');
    });

    test('parses tags from a comma string and caps them at eight', () {
      final Article article = JsonArticleMapper.map(<String, Object?>{
        'title': 'Budget',
        'tags': 'a, b , a, c',
      }, config)!;
      expect(article.tags, <String>['a', 'b', 'c']);

      final Article capped = JsonArticleMapper.map(<String, Object?>{
        'title': 'Budget',
        'tags': <Object?>[for (int i = 0; i < 12; i++) 'tag$i'],
      }, config)!;
      expect(capped.tags, hasLength(8));
    });

    test('parses epoch and DateTime timestamps', () {
      final DateTime fromEpoch = JsonArticleMapper.map(<String, Object?>{
        'title': 'Budget',
        'date': 1700000000,
      }, config)!.publishedAt;
      expect(fromEpoch.isUtc, isTrue);
      expect(fromEpoch.year, greaterThan(2020));

      final DateTime fromDate = JsonArticleMapper.map(<String, Object?>{
        'title': 'Budget',
        'createdAt': DateTime.utc(2026, 1, 2, 3),
      }, config)!.publishedAt;
      expect(fromDate, DateTime.utc(2026, 1, 2, 3));
    });

    test('accepts reading minutes as a string', () {
      final Article article = JsonArticleMapper.map(<String, Object?>{
        'title': 'Budget',
        'readingMinutes': ' 6 ',
      }, config)!;
      expect(article.readingMinutes, 6);
    });
  });

  group('JsonArticleMapper.toArticles', () {
    test('maps usable entries and skips the rest', () {
      final List<Article> articles = JsonArticleMapper.toArticles(
        <String, Object?>{
          'items': <Object?>[
            <String, Object?>{'title': 'One'},
            <String, Object?>{},
            <String, Object?>{'title': 'Two'},
            'junk',
          ],
        },
        config,
        now: fixedNow,
      );

      expect(articles.map((Article a) => a.title), <String>['One', 'Two']);
    });

    test('stops at the limit', () {
      final List<Article> articles = JsonArticleMapper.toArticles(
        <Object?>[
          for (int i = 0; i < 10; i++) <String, Object?>{'title': 'Story $i'},
        ],
        config,
        limit: 3,
        now: fixedNow,
      );

      expect(articles, hasLength(3));
    });
  });
}
