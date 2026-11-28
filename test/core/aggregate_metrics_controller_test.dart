import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/domain/analytics/aggregate_feed_metrics.dart';
import 'package:slnews_mobile/core/providers/aggregate_metrics.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/controllers.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';

import '../support/fakes.dart';

void main() {
  test('consent is required before any metric is recorded', () async {
    final InMemoryPreferencesStore store = InMemoryPreferencesStore();
    final FakeUserStateRepository user = FakeUserStateRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        preferencesStoreProvider.overrideWithValue(store),
        userStateProvider.overrideWithValue(user),
      ],
    );
    addTearDown(container.dispose);
    final Article article = testArticle(id: 'one', categoryId: 'politics');

    container
        .read(aggregateMetricsProvider.notifier)
        .recordArticle(FeedMetricKind.open, article);
    await container.read(aggregateMetricsProvider.notifier).flush();

    expect(container.read(aggregateMetricsProvider).totalCount, 0);
    expect(store.string(aggregateMetricsKey), isNull);
  });

  test('consented metrics aggregate without persisting article ids', () async {
    final InMemoryPreferencesStore store = InMemoryPreferencesStore();
    final FakeUserStateRepository user = FakeUserStateRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        preferencesStoreProvider.overrideWithValue(store),
        userStateProvider.overrideWithValue(user),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(settingsControllerProvider.notifier)
        .setAnalyticsEnabled(true);
    final Article article = testArticle(
      id: 'secret-id',
      categoryId: 'politics',
    );

    for (int i = 0; i < 60; i++) {
      container
          .read(aggregateMetricsProvider.notifier)
          .recordArticle(FeedMetricKind.open, article);
    }
    await container.read(aggregateMetricsProvider.notifier).flush();

    final AggregateFeedMetrics metrics = container.read(
      aggregateMetricsProvider,
    );
    expect(metrics.totalCount, 60);
    expect(metrics.publishableRows(), hasLength(1));
    final String raw = store.string(aggregateMetricsKey) ?? '';
    expect(raw, contains('politics'));
    expect(raw, isNot(contains('secret-id')));
  });

  test('feed impressions are counted once per session', () async {
    final InMemoryPreferencesStore store = InMemoryPreferencesStore();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        preferencesStoreProvider.overrideWithValue(store),
        userStateProvider.overrideWithValue(FakeUserStateRepository()),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(settingsControllerProvider.notifier)
        .setAnalyticsEnabled(true);
    final List<Article> feed = <Article>[
      testArticle(id: 'a', categoryId: 'politics'),
      testArticle(id: 'b', categoryId: 'business'),
    ];

    container.read(aggregateMetricsProvider.notifier).recordImpressions(feed);
    container.read(aggregateMetricsProvider.notifier).recordImpressions(feed);
    await container.read(aggregateMetricsProvider.notifier).flush();

    expect(container.read(aggregateMetricsProvider).totalCount, 2);
  });

  test('withdrawing consent clears stored counters', () async {
    final InMemoryPreferencesStore store = InMemoryPreferencesStore();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        preferencesStoreProvider.overrideWithValue(store),
        userStateProvider.overrideWithValue(FakeUserStateRepository()),
      ],
    );
    addTearDown(container.dispose);
    final SettingsController settings = container.read(
      settingsControllerProvider.notifier,
    );
    await settings.setAnalyticsEnabled(true);
    container
        .read(aggregateMetricsProvider.notifier)
        .recordArticle(
          FeedMetricKind.open,
          testArticle(id: 'one', categoryId: 'politics'),
        );
    await container.read(aggregateMetricsProvider.notifier).flush();
    expect(store.string(aggregateMetricsKey), isNotNull);

    await settings.setAnalyticsEnabled(false);
    container.read(aggregateMetricsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(store.string(aggregateMetricsKey), isNull);
    expect(container.read(aggregateMetricsProvider).totalCount, 0);
  });
}
