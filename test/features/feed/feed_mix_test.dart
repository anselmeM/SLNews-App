import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/feed_mix.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/domain/models/publisher.dart';
import 'package:slnews_mobile/features/feed/presentation/viewmodels/for_you_view_model.dart';

const Publisher local = Publisher(
  id: 'awoko',
  name: 'Awoko Newspaper',
  wordmark: 'AWOKO',
);
const Publisher international = Publisher(
  id: 'bbcafrica',
  name: 'BBC News Africa',
  wordmark: 'BBC',
);

Article article({
  required String id,
  required Publisher publisher,
  String categoryId = 'top',
  DateTime? publishedAt,
}) {
  return Article(
    id: id,
    title: id,
    publisher: publisher,
    categoryId: categoryId,
    publishedAt: publishedAt ?? DateTime(2026, 11, 12),
  );
}

void main() {
  test('classifies Sierra Leone, international and sport stories', () {
    expect(
      FeedMix.audienceOf(article(id: 'local', publisher: local)),
      FeedAudience.sierraLeone,
    );
    expect(
      FeedMix.audienceOf(
        article(
          id: 'world',
          publisher: international,
          publishedAt: DateTime(2026, 11, 13),
        ),
      ),
      FeedAudience.international,
    );
    expect(
      FeedMix.audienceOf(
        article(id: 'sport', publisher: international, categoryId: 'sports'),
      ),
      FeedAudience.sports,
    );
    expect(
      FeedMix.isSports(
        article(id: 'sport', publisher: local, categoryId: 'sports'),
      ),
      isTrue,
    );
  });

  test(
    'home feed is Sierra Leone-first, international-second and sports-last',
    () {
      final List<Article> top = <Article>[
        article(
          id: 'sport-newest',
          publisher: international,
          categoryId: 'sports',
          publishedAt: DateTime(2026, 11, 15, 12),
        ),
        article(
          id: 'world',
          publisher: international,
          publishedAt: DateTime(2026, 11, 15, 10),
        ),
        article(
          id: 'local',
          publisher: local,
          publishedAt: DateTime(2026, 11, 14, 8),
        ),
        article(
          id: 'local-2',
          publisher: local,
          publishedAt: DateTime(2026, 11, 13, 8),
        ),
      ];

      final ForYouFeed feed = ForYouViewModel.build(
        topStories: top,
        locationStories: const <Article>[],
        extraStories: const <Article>[],
        activeLocation: SlLocations.fallback,
        isOffline: false,
        heroLimit: 3,
        sportsOutsideLimit: 1,
      );

      expect(feed.hero.map((Article a) => a.id).toList(), <String>[
        'local',
        'local-2',
        'world',
      ]);
      expect(feed.stream.map((Article a) => a.id).toList(), <String>[
        'sport-newest',
      ]);
    },
  );

  test('sports tail is capped outside the Sports tab', () {
    final List<Article> sports = <Article>[
      for (int i = 0; i < 5; i++)
        article(
          id: 'sport-$i',
          publisher: international,
          categoryId: 'sports',
          publishedAt: DateTime(2026, 11, 15, 12 - i),
        ),
    ];

    final ForYouFeed feed = ForYouViewModel.build(
      topStories: sports,
      locationStories: const <Article>[],
      extraStories: const <Article>[],
      activeLocation: SlLocations.fallback,
      isOffline: false,
      heroLimit: 0,
      sportsOutsideLimit: 2,
    );

    expect(feed.stream.map((Article a) => a.id).toList(), <String>[
      'sport-0',
      'sport-1',
    ]);
  });
}
