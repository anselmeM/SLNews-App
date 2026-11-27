import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/analytics/aggregate_feed_metrics.dart';
import 'package:slnews_mobile/core/domain/experiments/experiment_assignment.dart';
import 'package:slnews_mobile/core/domain/feed_mix.dart';

void main() {
  AggregateMetricKey key({
    int day = 20,
    FeedMetricKind metric = FeedMetricKind.open,
  }) => AggregateMetricKey(
    day: DateTime.utc(2026, 11, day, 23, 59),
    experimentKey: 'for_you_ranker_v1',
    variant: ExperimentVariant.control,
    categoryId: 'politics',
    audience: FeedAudience.sierraLeone,
    metric: metric,
  );

  test('aggregates per day, category, audience and metric only', () {
    AggregateFeedMetrics metrics = AggregateFeedMetrics.empty();
    metrics = metrics.increment(key(), by: 30);
    metrics = metrics.increment(key(metric: FeedMetricKind.save), by: 20);

    expect(metrics.countFor(key()), 30);
    expect(metrics.countFor(key(metric: FeedMetricKind.save)), 20);
    expect(metrics.totalCount, 50);
    expect(key().day, DateTime.utc(2026, 11, 20));
    expect(key().dimensionKey, contains('2026-11-20'));
    expect(key().dimensionKey, isNot(contains('article')));
    final AggregateMetricKey hostile = AggregateMetricKey(
      day: DateTime.utc(2026, 11, 20),
      experimentKey: 'ranker',
      variant: ExperimentVariant.control,
      categoryId: 'Headline: Man detained in Freetown',
      audience: FeedAudience.sierraLeone,
      metric: FeedMetricKind.open,
    );
    expect(hostile.categoryId, 'other');
  });

  test('minimum bucket suppresses small cohorts', () {
    AggregateFeedMetrics metrics = AggregateFeedMetrics.empty();
    metrics = metrics.increment(key(), by: 49);
    expect(metrics.publishableRows(), isEmpty);

    metrics = metrics.increment(key());
    expect(metrics.publishableRows(), hasLength(1));
    expect(metrics.publishableRows().single['count'], 50);
  });

  test('round-trips counters and drops malformed rows', () {
    final AggregateFeedMetrics metrics = AggregateFeedMetrics.empty()
        .increment(key(), by: 7)
        .increment(key(metric: FeedMetricKind.dismiss), by: 2);
    final AggregateFeedMetrics decoded = AggregateFeedMetrics.fromJson(
      metrics.toJson(),
    );
    expect(decoded.counts, metrics.counts);
    expect(metrics.encode(), contains('politics'));

    final AggregateFeedMetrics tolerant = AggregateFeedMetrics.fromJson(
      <String, dynamic>{
        'counts': <Object?>[
          <String, dynamic>{'key': <String, dynamic>{}, 'count': 4},
          <String, dynamic>{'count': 'bad'},
          null,
        ],
      },
    );
    expect(tolerant.counts, isEmpty);
  });

  test('prunes counters beyond the retention window', () {
    final AggregateFeedMetrics metrics = AggregateFeedMetrics.empty()
        .increment(key(day: 1), by: 10)
        .increment(key(day: 30), by: 10);
    final AggregateFeedMetrics pruned = metrics.prune(
      now: DateTime.utc(2026, 12, 30),
    );
    expect(pruned.countFor(key(day: 1)), 0);
    expect(pruned.countFor(key(day: 30)), 10);
    expect(AggregateFeedMetrics.retentionDays, 30);
    expect(AggregateFeedMetrics.minimumBucketSize, 50);
  });
}
