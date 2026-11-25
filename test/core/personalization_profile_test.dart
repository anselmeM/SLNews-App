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

    container
        .read(personalizationProfileProvider.notifier)
        .recordRead(story, dwell: const Duration(seconds: 45), progress: 0.45);

    await Future<void>.delayed(const Duration(milliseconds: 10));
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
    await Future<void>.delayed(Duration.zero);
    expect(
      store.string(personalizationProfileKeyFor(anonymousAccountId)),
      isNotNull,
    );

    controller.clear();
    await Future<void>.delayed(Duration.zero);

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
    a.read(personalizationProfileProvider.notifier).recordSave(story);
    await Future<void>.delayed(const Duration(milliseconds: 10));

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
