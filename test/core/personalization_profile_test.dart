import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/domain/auth/account_scope.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/domain/models/publisher.dart';
import 'package:slnews_mobile/core/domain/models/personalization_profile.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/auth_providers.dart';
import 'package:slnews_mobile/core/providers/personalization_profile.dart';

import '../support/fakes.dart';

void main() {
  final Article story = Article(
    id: 'story-1',
    title: 'Budget passes',
    publisher: const Publisher(id: 'awoko', name: 'Awoko', wordmark: 'AWOKO'),
    publishedAt: DateTime(2026, 11, 24),
    categoryId: 'politics',
  );

  test('records reading progress and exposes unfinished articles', () async {
    final InMemoryPreferencesStore store = InMemoryPreferencesStore();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[preferencesStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    final PersonalizationProfileController controller = container.read(
      personalizationProfileProvider.notifier,
    );
    controller.recordRead(
      story,
      dwell: const Duration(seconds: 45),
      progress: 0.45,
    );

    await controller.flushPersistence();
    final PersonalizationProfile profile = container.read(
      personalizationProfileProvider,
    );
    expect(profile.progress['story-1']?.progress, 0.45);
    expect(profile.continueReading().single.articleId, 'story-1');
    expect(profile.topicAffinity()['politics'], greaterThan(0));
    expect(
      store.string(personalizationProfileKeyFor(anonymousAccountId)),
      isNotNull,
      reason: 'the profile persists locally',
    );
  });

  test('short shallow reads become negative skip signals', () {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        preferencesStoreProvider.overrideWithValue(InMemoryPreferencesStore()),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(personalizationProfileProvider.notifier)
        .recordRead(story, dwell: const Duration(seconds: 3), progress: 0.02);

    expect(
      container
          .read(personalizationProfileProvider)
          .topicAffinity()['politics'],
      lessThan(0),
    );
  });

  test('save/like/dismiss signals update affinity and hide dismissals', () {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        preferencesStoreProvider.overrideWithValue(InMemoryPreferencesStore()),
      ],
    );
    addTearDown(container.dispose);
    final PersonalizationProfileController controller = container.read(
      personalizationProfileProvider.notifier,
    );

    controller.recordSave(story);
    expect(
      container
          .read(personalizationProfileProvider)
          .topicAffinity()['politics'],
      4,
    );

    controller.recordLike(story);
    controller.recordDismiss(story);

    final PersonalizationProfile profile = container.read(
      personalizationProfileProvider,
    );
    expect(profile.dismissedArticleIds(), contains('story-1'));
    expect(profile.progress, isEmpty);
    expect(profile.topicAffinity()['politics'], lessThan(4));
  });

  test('clear removes the profile and its stored document', () async {
    final InMemoryPreferencesStore store = InMemoryPreferencesStore();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[preferencesStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final PersonalizationProfileController controller = container.read(
      personalizationProfileProvider.notifier,
    );
    controller.recordSave(story);
    await controller.flushPersistence();
    expect(
      store.string(personalizationProfileKeyFor(anonymousAccountId)),
      isNotNull,
    );

    await controller.clear();

    expect(container.read(personalizationProfileProvider).isEmpty, isTrue);
    expect(
      store.string(personalizationProfileKeyFor(anonymousAccountId)),
      isNull,
    );
  });

  test('affinity decays after seven days and expires after thirty', () {
    final DateTime now = DateTime.utc(2026, 11, 24);
    final PersonalizationProfile profile = PersonalizationProfile(
      events: <EngagementEvent>[
        EngagementEvent(
          articleId: 'recent',
          topicId: 'politics',
          publisherId: 'awoko',
          kind: EngagementKind.save,
          at: now.subtract(const Duration(days: 1)),
          weight: 4,
        ),
        EngagementEvent(
          articleId: 'old',
          topicId: 'politics',
          publisherId: 'awoko',
          kind: EngagementKind.save,
          at: now.subtract(const Duration(days: 10)),
          weight: 4,
        ),
        EngagementEvent(
          articleId: 'expired',
          topicId: 'politics',
          publisherId: 'awoko',
          kind: EngagementKind.save,
          at: now.subtract(const Duration(days: 40)),
          weight: 4,
        ),
      ],
    );

    expect(profile.topicAffinity(now: now)['politics'], 6);
    expect(profile.publisherAffinity(now: now)['awoko'], 6);
  });

  test('profile JSON round-trips and tolerates a bad document', () {
    final PersonalizationProfile original = PersonalizationProfile(
      events: <EngagementEvent>[
        EngagementEvent(
          articleId: 'a',
          topicId: 'politics',
          publisherId: 'awoko',
          kind: EngagementKind.like,
          at: DateTime.utc(2026, 11, 24),
          weight: 3,
        ),
      ],
      progress: <String, ReadingProgressEntry>{
        'a': ReadingProgressEntry(
          articleId: 'a',
          progress: 0.5,
          lastReadAt: DateTime.utc(2026, 11, 24),
        ),
      },
    );

    final PersonalizationProfile restored = PersonalizationProfile.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );

    expect(restored.events.single.articleId, 'a');
    expect(restored.progress['a']?.progress, 0.5);
    expect(
      PersonalizationProfile.fromJson(<String, dynamic>{
        'events': <Object?>['bad'],
        'progress': <Object?>['bad'],
      }).isEmpty,
      isTrue,
    );
  });

  test('profile and reading positions are isolated per account', () async {
    final InMemoryPreferencesStore store = InMemoryPreferencesStore();
    final ProviderContainer a = ProviderContainer(
      overrides: <Override>[
        preferencesStoreProvider.overrideWithValue(store),
        activeAccountKeyProvider.overrideWithValue('account-a'),
      ],
    );
    addTearDown(a.dispose);
    final PersonalizationProfileController controllerA = a.read(
      personalizationProfileProvider.notifier,
    );
    controllerA.recordSave(story);
    await controllerA.flushPersistence();

    final ProviderContainer b = ProviderContainer(
      overrides: <Override>[
        preferencesStoreProvider.overrideWithValue(store),
        activeAccountKeyProvider.overrideWithValue('account-b'),
      ],
    );
    addTearDown(b.dispose);

    expect(a.read(personalizationProfileProvider).eventCount, 1);
    expect(b.read(personalizationProfileProvider).isEmpty, isTrue);
    expect(store.string(personalizationProfileKeyFor('account-a')), isNotNull);
    expect(store.string(personalizationProfileKeyFor('account-b')), isNull);
  });

  test('event tags persist as tag affinity', () async {
    final InMemoryPreferencesStore store = InMemoryPreferencesStore();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[preferencesStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final PersonalizationProfileController controller = container.read(
      personalizationProfileProvider.notifier,
    );
    final Article tagged = story.copyWith(tags: const <String>['freetown']);

    controller.recordSave(tagged);
    await controller.flushPersistence();

    expect(
      container
          .read(personalizationProfileProvider)
          .topicAffinity()['freetown'],
      greaterThan(0),
    );
  });

  test(
    'deferred activity uses the captured account, not the active one',
    () async {
      final InMemoryPreferencesStore store = InMemoryPreferencesStore();
      final ProviderContainer current = ProviderContainer(
        overrides: <Override>[
          preferencesStoreProvider.overrideWithValue(store),
          activeAccountKeyProvider.overrideWithValue('account-b'),
        ],
      );
      addTearDown(current.dispose);
      final PersonalizationProfileController controller = current.read(
        personalizationProfileProvider.notifier,
      );
      controller.recordSave(story, accountKey: 'account-a');
      await controller.flushPersistence();

      final ProviderContainer owner = ProviderContainer(
        overrides: <Override>[
          preferencesStoreProvider.overrideWithValue(store),
          activeAccountKeyProvider.overrideWithValue('account-a'),
        ],
      );
      addTearDown(owner.dispose);
      expect(owner.read(personalizationProfileProvider).eventCount, 1);
      final ProviderContainer other = ProviderContainer(
        overrides: <Override>[
          preferencesStoreProvider.overrideWithValue(store),
          activeAccountKeyProvider.overrideWithValue('account-b'),
        ],
      );
      addTearDown(other.dispose);
      expect(other.read(personalizationProfileProvider).isEmpty, isTrue);
      expect(current.read(personalizationProfileProvider).isEmpty, isTrue);
    },
  );

  test('reset marker blocks a partially failed legacy restore', () async {
    final InMemoryPreferencesStore store = InMemoryPreferencesStore();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[preferencesStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final PersonalizationProfileController controller = container.read(
      personalizationProfileProvider.notifier,
    );
    controller.recordSave(story);
    await controller.flushPersistence();
    final String oldLegacy = jsonEncode(
      container.read(personalizationProfileProvider).toJson(),
    );
    await controller.clear();

    // Simulate the legacy remove failing during reset after the scoped key was
    // already cleared.
    await store.putString(personalizationProfileKey, oldLegacy);
    final ProviderContainer reopened = ProviderContainer(
      overrides: <Override>[preferencesStoreProvider.overrideWithValue(store)],
    );
    addTearDown(reopened.dispose);
    expect(reopened.read(personalizationProfileProvider).isEmpty, isTrue);
  });

  test(
    'continue reading resolves unfinished articles through the repository',
    () async {
      final InMemoryPreferencesStore store = InMemoryPreferencesStore();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          preferencesStoreProvider.overrideWithValue(store),
          articleRepositoryProvider.overrideWithValue(
            FakeArticleRepository(topStories: <Article>[story]),
          ),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(personalizationProfileProvider.notifier)
          .recordRead(story, dwell: const Duration(seconds: 30), progress: 0.4);

      final List<ContinueReadingEntry> entries = await container.read(
        continueReadingProvider.future,
      );

      expect(entries.single.article.id, 'story-1');
      expect(entries.single.progress, 0.4);
    },
  );
}
