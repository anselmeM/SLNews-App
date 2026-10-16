import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/features/feed/presentation/viewmodels/for_you_view_model.dart';

import 'support/fakes.dart';

/// Unit tests for the derived For You logic; no widgets are pumped here.
void main() {
  const NewsLocation freetown = SlLocations.fallback;

  ForYouFeed build({
    List<Article> topStories = const <Article>[],
    List<Article> localStories = const <Article>[],
    List<Article> extraStories = const <Article>[],
    int heroLimit = ForYouViewModel.heroLimit,
  }) {
    return ForYouViewModel.build(
      topStories: topStories,
      locationStories: localStories,
      extraStories: extraStories,
      activeLocation: freetown,
      isOffline: false,
      heroLimit: heroLimit,
    );
  }

  test('de-duplicates the same story arriving from every stream', () {
    final Article shared = testArticle(
      id: 'shared',
      publishedAt: DateTime(2026, 10, 15, 9),
    );
    final Article extra = testArticle(
      id: 'only-extra',
      publishedAt: DateTime(2026, 10, 15, 7),
    );

    final ForYouFeed feed = build(
      topStories: <Article>[shared],
      localStories: <Article>[shared],
      extraStories: <Article>[
        shared.copyWith(title: 'Shared from category'),
        extra,
      ],
    );

    final List<String> rendered = <String>[
      ...feed.hero.map((Article a) => a.id),
      ...feed.stream.map((Article a) => a.id),
    ];
    expect(rendered, <String>['shared', 'only-extra']);
    expect(rendered.where((String id) => id == 'shared'), hasLength(1));
    // The extra feed only contributes what the carousel did not take.
    expect(feed.hero.map((Article a) => a.id).toList(), <String>['shared']);
    expect(feed.stream.map((Article a) => a.id).toList(), <String>[
      'only-extra',
    ]);
  });

  test('orders the merged stream newest first', () {
    final ForYouFeed feed = build(
      topStories: <Article>[
        testArticle(id: 'oldest', publishedAt: DateTime(2026, 10, 13)),
        testArticle(id: 'newest', publishedAt: DateTime(2026, 10, 15, 18)),
        testArticle(id: 'middle', publishedAt: DateTime(2026, 10, 14)),
        // A fourth story keeps one item out of the hero so the stream is
        // exercised too.
        testArticle(id: 'second', publishedAt: DateTime(2026, 10, 15, 12)),
      ],
      heroLimit: 3,
    );

    expect(feed.hero.map((Article a) => a.id).toList(), <String>[
      'newest',
      'second',
      'middle',
    ]);
    expect(feed.stream.map((Article a) => a.id).toList(), <String>['oldest']);
  });

  test('empty input yields an empty, safe feed', () {
    final ForYouFeed feed = build();

    expect(feed.isEmpty, isTrue);
    expect(feed.hero, isEmpty);
    expect(feed.stream, isEmpty);
    expect(feed.breakingCount, 0);
  });

  test('promotes breaking stories ahead of newer non-breaking ones', () {
    final ForYouFeed feed = build(
      topStories: <Article>[
        testArticle(id: 'fresh', publishedAt: DateTime(2026, 10, 15, 18)),
        testArticle(
          id: 'alert',
          publishedAt: DateTime(2026, 10, 15, 6),
          isBreaking: true,
        ),
      ],
    );

    expect(feed.hero.first.id, 'alert');
    expect(feed.hasBreaking, isTrue);
    expect(feed.breakingCount, 1);
  });

  test('caps the hero at the limit and streams the rest', () {
    final List<Article> stories = <Article>[
      for (int index = 0; index < 9; index++)
        testArticle(
          id: 'story-$index',
          publishedAt: DateTime(2026, 10, 15, 18 - index),
        ),
    ];

    final ForYouFeed feed = build(topStories: stories, heroLimit: 3);

    expect(feed.hero.map((Article a) => a.id).toList(), <String>[
      'story-0',
      'story-1',
      'story-2',
    ]);
    expect(feed.stream.map((Article a) => a.id).toList(), <String>[
      'story-3',
      'story-4',
      'story-5',
      'story-6',
      'story-7',
      'story-8',
    ]);
  });

  test('keeps the location stream ahead of the latest remainder', () {
    final ForYouFeed feed = build(
      topStories: <Article>[
        for (int index = 0; index < 7; index++)
          testArticle(
            id: 'story-$index',
            publishedAt: DateTime(2026, 10, 15, 18 - index),
          ),
      ],
      localStories: <Article>[
        testArticle(id: 'local-1', publishedAt: DateTime(2026, 10, 15, 5)),
        testArticle(id: 'local-2', publishedAt: DateTime(2026, 10, 15, 4)),
      ],
    );

    expect(feed.hero, hasLength(ForYouViewModel.heroLimit));
    expect(feed.hero.any((Article a) => a.id.startsWith('local-')), isFalse);
    expect(feed.stream.first.id, 'local-1');
    expect(
      feed.stream.where((Article a) => a.id.startsWith('local-')),
      hasLength(2),
    );
    expect(feed.stream.last.id, 'story-6');
  });
}
