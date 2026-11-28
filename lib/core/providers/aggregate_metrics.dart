import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/analytics/aggregate_upload_outbox.dart';
import '../data/local/preferences_store.dart';
import '../domain/analytics/aggregate_feed_metrics.dart';
import '../domain/experiments/experiment_assignment.dart';
import '../domain/feed_mix.dart';
import '../domain/models/app_settings.dart';
import '../domain/models/article.dart';
import 'app_providers.dart';
import 'controllers.dart';
import 'experiments.dart';

/// The single device-local aggregate metrics document.
const String aggregateMetricsKey = 'experiments.aggregateMetrics.v1';

/// Consent-gated, local-only aggregate metrics.
///
/// Phase 3B-A never uploads these counters. Rows are category-level and
/// k-anonymous; impression de-duplication uses article ids only in memory for
/// the current process and never persists them.
final NotifierProvider<AggregateMetricsController, AggregateFeedMetrics>
aggregateMetricsProvider =
    NotifierProvider<AggregateMetricsController, AggregateFeedMetrics>(
      AggregateMetricsController.new,
      name: 'aggregateMetrics',
    );

class AggregateMetricsController extends Notifier<AggregateFeedMetrics> {
  Future<void> _writeBarrier = Future<void>.value();
  final Set<String> _sessionImpressions = <String>{};

  @override
  AggregateFeedMetrics build() {
    final bool enabled = ref.watch(
      settingsControllerProvider.select(
        (AppSettings settings) => settings.analyticsEnabled,
      ),
    );
    final PreferencesStore? preferences = _preferences();
    if (!enabled) {
      _sessionImpressions.clear();
      if (preferences != null && preferences.isAvailable) {
        unawaited(
          preferences.remove(aggregateMetricsKey).catchError((Object _) {}),
        );
        unawaited(
          AggregateUploadOutbox(preferences: preferences)
              .clear()
              .catchError((Object _) {}),
        );
      }
      return AggregateFeedMetrics.empty();
    }
    try {
      final String? raw = preferences?.string(aggregateMetricsKey);
      if (raw == null || raw.isEmpty) return AggregateFeedMetrics.empty();
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return AggregateFeedMetrics.empty();
      return AggregateFeedMetrics.fromJson(Map<String, dynamic>.from(decoded))
          .prune();
    } catch (_) {
      return AggregateFeedMetrics.empty();
    }
  }

  bool get _enabled => ref.read(settingsControllerProvider).analyticsEnabled;

  /// Records one action for an article without persisting its id.
  void recordArticle(FeedMetricKind metric, Article article, {DateTime? now}) {
    recordCategory(
      metric,
      categoryId: article.categoryId,
      audience: FeedMix.audienceOf(article),
      now: now,
    );
  }

  /// Records a category/audience action; used by the article and feed paths.
  void recordCategory(
    FeedMetricKind metric, {
    required String categoryId,
    required FeedAudience audience,
    DateTime? now,
  }) {
    if (!_enabled) return;
    final ExperimentAssignment assignment = ref.read(
      forYouRankingAssignmentProvider,
    );
    final DateTime when = now ?? DateTime.now();
    final AggregateMetricKey key = AggregateMetricKey(
      day: when,
      experimentKey: assignment.experimentKey,
      variant: assignment.variant,
      categoryId: categoryId,
      audience: audience,
      metric: metric,
    );
    state = state.increment(key).prune(now: when);
    _persist();
  }

  /// Counts each story at most once per app session.
  void recordImpressions(Iterable<Article> articles, {DateTime? now}) {
    if (!_enabled) return;
    final DateTime when = now ?? DateTime.now();
    final ExperimentAssignment assignment = ref.read(
      forYouRankingAssignmentProvider,
    );
    AggregateFeedMetrics next = state;
    bool changed = false;
    for (final Article article in articles) {
      if (!_sessionImpressions.add(article.id)) continue;
      changed = true;
      next = next.increment(
        AggregateMetricKey(
          day: when,
          experimentKey: assignment.experimentKey,
          variant: assignment.variant,
          categoryId: article.categoryId,
          audience: FeedMix.audienceOf(article),
          metric: FeedMetricKind.impression,
        ),
      );
    }
    if (!changed) return;
    state = next.prune(now: when);
    _persist();
  }

  /// Removes local counters after consent is withdrawn or on explicit reset.
  Future<void> clear() async {
    state = AggregateFeedMetrics.empty();
    _sessionImpressions.clear();
    final PreferencesStore? preferences = _preferences();
    if (preferences == null || !preferences.isAvailable) return;
    final Future<void> removal = _writeBarrier.then(
      (_) => preferences.remove(aggregateMetricsKey),
    );
    _writeBarrier = removal.catchError((Object _) {});
    await removal;
  }

  Future<void> flush() => _writeBarrier;

  void _persist() {
    final PreferencesStore? preferences = _preferences();
    if (preferences == null || !preferences.isAvailable) return;
    final String payload = state.encode();
    final Future<void> write = _writeBarrier.then(
      (_) => preferences.putString(aggregateMetricsKey, payload),
    );
    _writeBarrier = write.catchError((Object _) {});
  }

  PreferencesStore? _preferences() {
    try {
      return ref.read(preferencesStoreProvider);
    } catch (_) {
      return null;
    }
  }
}
