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
  country: 'United Kingdom',
);

/// The scraper API sends no country; the app records that as an empty value.
const Publisher unknown = Publisher(
  id: 'publisher:new-outlet',
  name: 'New Outlet',
  wordmark: 'NO',
  country: '',
);

Article article({
  required String id,
  required Publisher publisher,
  String categoryId = 'top',
  DateTime? publishedAt,
  String? title,
  String summary = '',
}) {
  return Article(
    id: id,
    title: title ?? id,
    summary: summary,
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
    'locality comes from the publisher country, with a keyword fallback',
    () {
      // A local outlet is local even when the headline says nothing about
      // Sierra Leone — the old id/name lists were what made this work, and they
      // missed outlets whose ids differed between the API and the registry.
      expect(
        FeedMix.isSierraLeone(article(id: 'quiet-local', publisher: local)),
        isTrue,
      );

      // A foreign outlet stays international unless the headline is about SL.
      expect(
        FeedMix.isSierraLeone(
          article(id: 'world-news', publisher: international),
        ),
        isFalse,
      );
      expect(
        FeedMix.isSierraLeone(
          article(
            id: 'wire',
            publisher: international,
            title: 'Freetown port expansion wins backing',
          ),
        ),
        isTrue,
      );

      // A summary mention alone is not enough for a known foreign outlet.
      expect(
        FeedMix.isSierraLeone(
          article(
            id: 'passing',
            publisher: international,
            title: 'Regional summit closes',
            summary: 'Delegates met in Freetown earlier this year.',
          ),
        ),
        isFalse,
      );

      // Unknown provenance falls back to the whole story text.
      expect(
        FeedMix.isSierraLeone(
          article(
            id: 'unknown-quiet',
            publisher: unknown,
            title: 'New outlet launches',
          ),
        ),
        isFalse,
      );
      expect(
        FeedMix.isSierraLeone(
          article(
            id: 'unknown-local',
            publisher: unknown,
            title: 'New outlet launches',
            summary: 'Reporting from Bo and Freetown.',
          ),
        ),
        isTrue,
      );
    },
  );

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
