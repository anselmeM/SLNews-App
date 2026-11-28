import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/analytics/aggregate_upload_outbox.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/domain/analytics/aggregate_feed_metrics.dart';
import 'package:slnews_mobile/core/domain/experiments/experiment_assignment.dart';
import 'package:slnews_mobile/core/domain/feed_mix.dart';

void main() {
  AggregateFeedMetrics publishableMetrics({int count = 50}) {
    AggregateFeedMetrics metrics = AggregateFeedMetrics.empty();
    metrics = metrics.increment(
      AggregateMetricKey(
        day: DateTime.utc(2026, 11, 20),
        experimentKey: 'for_you_ranker_v1',
        variant: ExperimentVariant.control,
        categoryId: 'politics',
        audience: FeedAudience.sierraLeone,
        metric: FeedMetricKind.open,
      ),
      by: count,
    );
    return metrics;
  }

  test('upload is dormant and enqueue requires a k-anonymous batch', () async {
    final AggregateUploadOutbox outbox = AggregateUploadOutbox(
      preferences: InMemoryPreferencesStore(),
    );

    expect(aggregateUploadEnabled, isFalse);
    expect(await outbox.enqueue(publishableMetrics(count: 49)), isFalse);
    expect(await outbox.pending(), isEmpty);
    expect(await outbox.enqueue(publishableMetrics()), isTrue);
    expect(await outbox.pending(), hasLength(1));
  });

  test('duplicate batches are not queued twice', () async {
    final AggregateUploadOutbox outbox = AggregateUploadOutbox(
      preferences: InMemoryPreferencesStore(),
    );

    expect(await outbox.enqueue(publishableMetrics()), isTrue);
    expect(await outbox.enqueue(publishableMetrics()), isFalse);
    expect(await outbox.pending(), hasLength(1));
  });

  test('oldest batches are dropped at the queue limit', () async {
    final AggregateUploadOutbox outbox = AggregateUploadOutbox(
      preferences: InMemoryPreferencesStore(),
      maxBatches: 2,
    );

    for (int i = 0; i < 3; i++) {
      AggregateFeedMetrics metrics = AggregateFeedMetrics.empty();
      metrics = metrics.increment(
        AggregateMetricKey(
          day: DateTime.utc(2026, 11, 20 + i),
          experimentKey: 'ranker',
          variant: ExperimentVariant.control,
          categoryId: 'politics',
          audience: FeedAudience.sierraLeone,
          metric: FeedMetricKind.open,
        ),
        by: 50,
      );
      await outbox.enqueue(metrics);
    }

    final List<AggregateUploadBatch> batches = await outbox.pending();
    expect(batches, hasLength(2));
    expect(batches.first.rows.first['day'], '2026-11-21');
  });

  test('successful batches are removed and failures stay queued', () async {
    final AggregateUploadOutbox outbox = AggregateUploadOutbox(
      preferences: InMemoryPreferencesStore(),
    );
    await outbox.enqueue(publishableMetrics());

    int attempts = 0;
    final int delivered = await outbox.flush(
      retryDelay: Duration.zero,
      send: (AggregateUploadBatch batch) async {
        attempts++;
        if (attempts < 3) throw StateError('offline');
      },
    );

    expect(delivered, 1);
    expect(attempts, 3);
    expect(await outbox.pending(), isEmpty);

    await outbox.enqueue(publishableMetrics());
    final int failed = await outbox.flush(
      maxAttempts: 2,
      retryDelay: Duration.zero,
      send: (AggregateUploadBatch batch) async => throw StateError('offline'),
    );
    expect(failed, 0);
    expect(await outbox.pending(), hasLength(1));
  });
}
