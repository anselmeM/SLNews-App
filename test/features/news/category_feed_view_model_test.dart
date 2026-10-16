import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/features/news/presentation/viewmodels/category_feed_view_model.dart';

import 'support/fakes.dart';

void main() {
  // `NewsCategoryFeedViewModel` is deliberately pure Dart: no Flutter binding,
  // no providers, no I/O. Every rule below is part of the News screen's layout
  // contract, so the tests document the boundaries rather than the internals.

  group('NewsCategoryFeedViewModel.build', () {
    test('an empty feed produces no sections and no hero', () {
      final NewsCategoryFeed feed = NewsCategoryFeedViewModel.build(
        const <Article>[],
        'cars',
      );

      expect(feed.isEmpty, isTrue);
      expect(feed.hero, isNull);
      expect(feed.grid, isEmpty);
      expect(feed.list, isEmpty);
      expect(feed.total, 0);
      expect(feed.label, 'Cars and Vehicles');
    });

    test('a single story becomes the hero and leaves both sections empty', () {
      final Article only = fakeArticle(id: 'only', title: 'Single story from the desk');

      final NewsCategoryFeed feed = NewsCategoryFeedViewModel.build(<Article>[only], 'top');

      expect(feed.hero, same(only));
      expect(feed.grid, isEmpty);
      expect(feed.list, isEmpty);
      expect(feed.total, 1);
      expect(feed.all.single.id, 'only');
    });

    test('exactly seven stories split 1 / 6 / 0 at the grid-list boundary', () {
      final List<Article> stories = <Article>[
        for (int index = 1; index <= 7; index++)
          fakeArticle(id: 'story-$index', title: 'Story $index', minutesAgo: index),
      ];

      final NewsCategoryFeed feed = NewsCategoryFeedViewModel.build(stories, 'top');

      expect(feed.hero!.id, 'story-1');
      expect(feed.grid.length, 6);
      expect(feed.list, isEmpty);
      expect(
        feed.grid.map((Article article) => article.id),
        <String>['story-2', 'story-3', 'story-4', 'story-5', 'story-6', 'story-7'],
      );
      expect(feed.total, 7);
    });

    test('an eighth story starts the list section', () {
      final List<Article> stories = <Article>[
        for (int index = 1; index <= 8; index++)
          fakeArticle(id: 'story-$index', title: 'Story $index', minutesAgo: index),
      ];

      final NewsCategoryFeed feed = NewsCategoryFeedViewModel.build(stories, 'top');

      expect(feed.hero!.id, 'story-1');
      expect(feed.grid.length, 6);
      expect(feed.list.map((Article article) => article.id), <String>['story-8']);
    });

    test('a breaking story is promoted into the hero slot', () {
      final List<Article> stories = <Article>[
        fakeArticle(id: 'newest', title: 'Newest story of the hour', minutesAgo: 1),
        fakeArticle(id: 'second', title: 'Second story of the hour', minutesAgo: 30),
        fakeArticle(
          id: 'breaking',
          title: 'BREAKING: Fire destroys stalls at Freetown market',
          minutesAgo: 240,
          isBreaking: true,
        ),
      ];

      final NewsCategoryFeed feed = NewsCategoryFeedViewModel.build(stories, 'top');

      expect(feed.hero!.id, 'breaking');
      // The promoted story is moved, never duplicated: sizes stay 1 + 6 + rest.
      expect(feed.total, 3);
      expect(
        feed.grid.map((Article article) => article.id),
        <String>['newest', 'second'],
      );
      expect(feed.list, isEmpty);
    });

    test('a live story outranks a newer ordinary story when nothing is breaking', () {
      final List<Article> stories = <Article>[
        fakeArticle(id: 'newest', title: 'Newest ordinary story', minutesAgo: 1),
        fakeArticle(
          id: 'live',
          title: 'LIVE: Election results come in across the districts',
          minutesAgo: 120,
          isLive: true,
        ),
      ];

      final NewsCategoryFeed feed = NewsCategoryFeedViewModel.build(stories, 'top');

      expect(feed.hero!.id, 'live');
      expect(feed.grid.map((Article article) => article.id), <String>['newest']);
    });

    test('duplicate ids are dropped, keeping the first occurrence', () {
      final Article first = fakeArticle(id: 'dup', title: 'First version', minutesAgo: 5);
      final Article duplicate = fakeArticle(id: 'dup', title: 'Syndicated version', minutesAgo: 5);
      final Article other = fakeArticle(id: 'other', title: 'Unrelated story', minutesAgo: 90);

      final NewsCategoryFeed feed = NewsCategoryFeedViewModel.build(
        <Article>[first, duplicate, other],
        'top',
      );

      expect(feed.total, 2);
      expect(feed.hero, same(first));
      expect(feed.hero!.title, 'First version');
      expect(feed.grid.single.id, 'other');
    });

    test('a duplicated breaking story still yields exactly one hero', () {
      final Article breaking = fakeArticle(
        id: 'dup-breaking',
        title: 'BREAKING: Flooding closes the main highway',
        isBreaking: true,
      );

      final NewsCategoryFeed feed = NewsCategoryFeedViewModel.build(
        <Article>[breaking, breaking, fakeArticle(id: 'other', title: 'Other', minutesAgo: 60)],
        'top',
      );

      expect(feed.total, 2);
      expect(feed.hero, same(breaking));
      expect(feed.grid.single.id, 'other');
    });

    test('an unknown category id falls back to the first catalogue label', () {
      final NewsCategoryFeed feed = NewsCategoryFeedViewModel.build(
        <Article>[fakeArticle(id: 'a', title: 'A')],
        'not-a-category',
      );

      expect(feed.label, 'Top stories');
      expect(feed.categoryId, 'not-a-category');
    });
  });

  group('NewsCategoryFeedViewModel.heroOf', () {
    test('returns null for an empty list', () {
      expect(NewsCategoryFeedViewModel.heroOf(const <Article>[]), isNull);
    });

    test('preserves the incoming order for equally prominent stories', () {
      final List<Article> stories = <Article>[
        fakeArticle(id: 'first', title: 'First', minutesAgo: 5),
        fakeArticle(id: 'second', title: 'Second', minutesAgo: 10),
      ];

      expect(NewsCategoryFeedViewModel.heroOf(stories)!.id, 'first');
    });
  });

  group('NewsCategoryFeed', () {
    test('all returns hero, grid and list in render order', () {
      final List<Article> stories = <Article>[
        for (int index = 1; index <= 9; index++)
          fakeArticle(id: 'story-$index', title: 'Story $index', minutesAgo: index),
      ];

      final NewsCategoryFeed feed = NewsCategoryFeedViewModel.build(stories, 'top');

      expect(feed.all.length, 9);
      expect(
        feed.all.map((Article article) => article.id),
        <String>['story-1', 'story-2', 'story-3', 'story-4', 'story-5', 'story-6', 'story-7', 'story-8', 'story-9'],
      );
    });

    test('the empty named constructor is empty', () {
      const NewsCategoryFeed feed = NewsCategoryFeed.empty();

      expect(feed.isEmpty, isTrue);
      expect(feed.all, isEmpty);
    });
  });
}
