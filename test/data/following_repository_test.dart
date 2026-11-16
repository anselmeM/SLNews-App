import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/data/repositories/default_following_repository.dart';
import 'package:slnews_mobile/core/data/seed/seed_data.dart';
import 'package:slnews_mobile/core/data/seed/seed_loader.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';

import 'fakes.dart';

SeedData catalogue({int popularCount = 3}) => seedData(
  followables: <FollowTarget>[
    target('team:lal'),
    target('team:leone-stars'),
    target('league:nba'),
    target('city:freetown', isPopular: true),
    target('city:bo', isPopular: true),
    target('city:kenema'),
    target('topic:politics', isPopular: true),
    target('topic:music'),
    target('publisher:awoko'),
    ...<FollowTarget>[
      for (int i = 0; i < popularCount; i++)
        target('topic:extra$i', isPopular: true),
    ],
  ],
);

void main() {
  group('DefaultFollowingRepository', () {
    test('load reports the seeded catalogue with nothing followed', () async {
      final DefaultFollowingRepository repository = DefaultFollowingRepository(
        preferences: InMemoryPreferencesStore(),
        seedLoader: InMemorySeedLoader(catalogue(popularCount: 0)),
      );
      await repository.ready();

      final FollowingSnapshot snapshot = repository.load();
      expect(snapshot.followed, isEmpty);
      expect(snapshot.suggested.map((FollowTarget t) => t.id), <String>[
        'city:freetown',
        'city:bo',
        'topic:politics',
      ]);
      expect(snapshot.sports.map((FollowTarget t) => t.id), <String>[
        'team:lal',
        'team:leone-stars',
        'league:nba',
      ]);
      expect(snapshot.locations, hasLength(3));
      expect(snapshot.topics, hasLength(2));
      expect(snapshot.publishers.single.id, 'publisher:awoko');
      expect(snapshot.followedIds, isEmpty);
    });

    test(
      'follow, unfollow and toggle persist through the preferences store',
      () async {
        final InMemoryPreferencesStore preferences = InMemoryPreferencesStore();
        final DefaultFollowingRepository repository =
            DefaultFollowingRepository(
              preferences: preferences,
              seedLoader: InMemorySeedLoader(catalogue()),
            );
        await repository.ready();
        final FollowTarget lakers = target(
          'team:lal',
          label: 'Los Angeles Lakers',
        );

        await repository.follow(lakers);
        expect(repository.isFollowed('team:lal'), isTrue);
        expect(
          preferences.stringSet(DefaultFollowingRepository.followedIdsKey),
          <String>{'team:lal'},
        );
        expect(repository.load().followed.single.id, 'team:lal');
        expect(repository.load().isFollowed('team:lal'), isTrue);

        // Following twice does not duplicate the subscription.
        await repository.follow(lakers);
        expect(repository.load().followed, hasLength(1));

        await repository.unfollow('team:lal');
        expect(repository.isFollowed('team:lal'), isFalse);
        expect(
          preferences.stringSet(DefaultFollowingRepository.followedIdsKey),
          isEmpty,
        );

        await repository.toggle(lakers);
        expect(repository.isFollowed('team:lal'), isTrue);
        await repository.toggle(lakers);
        expect(repository.isFollowed('team:lal'), isFalse);
      },
    );

    test(
      'suggestions never include something already followed and cap at six',
      () async {
        final DefaultFollowingRepository repository =
            DefaultFollowingRepository(
              preferences: InMemoryPreferencesStore(),
              seedLoader: InMemorySeedLoader(catalogue(popularCount: 8)),
            );
        await repository.ready();

        final FollowingSnapshot initial = repository.load();
        expect(initial.suggested, hasLength(6));
        expect(
          initial.suggested.every((FollowTarget t) => t.isPopular),
          isTrue,
        );

        final FollowingSnapshot afterFollow = await repository.follow(
          initial.suggested.first,
        );
        expect(
          afterFollow.suggested.map((FollowTarget t) => t.id),
          isNot(contains(initial.suggested.first.id)),
        );
        expect(afterFollow.suggested, hasLength(6));
      },
    );

    test(
      'a new repository over the same store sees the persisted subscriptions',
      () async {
        final InMemoryPreferencesStore preferences = InMemoryPreferencesStore();
        final DefaultFollowingRepository first = DefaultFollowingRepository(
          preferences: preferences,
          seedLoader: InMemorySeedLoader(catalogue()),
        );
        await first.ready();
        await first.follow(target('city:bo', isPopular: true, label: 'Bo'));

        final DefaultFollowingRepository second = DefaultFollowingRepository(
          preferences: preferences,
          seedLoader: InMemorySeedLoader(catalogue()),
        );
        await second.ready();

        expect(second.isFollowed('city:bo'), isTrue);
        expect(second.load().followed.single.id, 'city:bo');
        expect(
          second.load().suggested.map((FollowTarget t) => t.id),
          isNot(contains('city:bo')),
        );
      },
    );

    test('load works before hydration and gains labels afterwards', () async {
      final DefaultFollowingRepository repository = DefaultFollowingRepository(
        preferences: InMemoryPreferencesStore(),
        seedLoader: InMemorySeedLoader(catalogue()),
      );

      // Synchronous first read must not throw or lose follow state.
      expect(repository.load().followed, isEmpty);
      await repository.ready();
      expect(repository.load().topics, isNotEmpty);
    });

    test(
      'a league outside the seed catalogue survives a restart while followed',
      () async {
        final InMemoryPreferencesStore preferences = InMemoryPreferencesStore();
        const FollowTarget nfl = FollowTarget(
          id: 'league:nfl',
          kind: FollowKind.league,
          label: 'NFL',
          subtitle: 'League',
        );

        final DefaultFollowingRepository first = DefaultFollowingRepository(
          preferences: preferences,
          seedLoader: InMemorySeedLoader(catalogue()),
        );
        await first.ready();
        await first.follow(nfl);
        expect(
          first.load().sports.map((FollowTarget t) => t.id),
          contains('league:nfl'),
        );

        // A second repository over the same store rehydrates from the seed,
        // which does not carry the NFL; the followed extra must be merged back
        // so the row does not vanish after a relaunch.
        final DefaultFollowingRepository second = DefaultFollowingRepository(
          preferences: preferences,
          seedLoader: InMemorySeedLoader(catalogue()),
        );
        await second.ready();

        expect(second.isFollowed('league:nfl'), isTrue);
        expect(
          second.load().followed.map((FollowTarget t) => t.label),
          contains('NFL'),
        );
      },
    );

    test(
      'an unfollowed catalogue extra is dropped on the next start',
      () async {
        final InMemoryPreferencesStore preferences = InMemoryPreferencesStore();
        const FollowTarget nfl = FollowTarget(
          id: 'league:nfl',
          kind: FollowKind.league,
          label: 'NFL',
          subtitle: 'League',
        );

        final DefaultFollowingRepository first = DefaultFollowingRepository(
          preferences: preferences,
          seedLoader: InMemorySeedLoader(catalogue()),
        );
        await first.ready();
        await first.follow(nfl);
        await first.unfollow(nfl.id);

        final DefaultFollowingRepository second = DefaultFollowingRepository(
          preferences: preferences,
          seedLoader: InMemorySeedLoader(catalogue()),
        );
        await second.ready();

        expect(second.isFollowed('league:nfl'), isFalse);
        expect(
          second.load().sports.map((FollowTarget t) => t.id),
          isNot(contains('league:nfl')),
        );
      },
    );
  });
}
