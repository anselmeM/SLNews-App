import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../feed_mix.dart';
import '../experiments/experiment_assignment.dart';

/// Aggregated feed outcomes that may eventually leave the device.
enum FeedMetricKind {
  impression,
  open,
  save,
  like,
  dismiss,
  continueReadingOpen,
}

/// One category-level, per-day counter.
///
/// Deliberately contains no account id, article id, reading position, search
/// term or precise location. A row is only published once it clears
/// [AggregateFeedMetrics.minimumBucketSize], so an individual story or reader
/// cannot be reconstructed from a bucket.
@immutable
class AggregateMetricKey {
  AggregateMetricKey({
    required DateTime day,
    required this.experimentKey,
    required this.variant,
    required String categoryId,
    required this.audience,
    required this.metric,
  }) : day = DateTime.utc(day.year, day.month, day.day),
       categoryId = _safeCategory(categoryId);

  final DateTime day;
  final String experimentKey;
  final ExperimentVariant variant;
  final String categoryId;
  final FeedAudience audience;
  final FeedMetricKind metric;

  /// Category ids are content taxonomy values, never article ids or free text.
  static String _safeCategory(String value) {
    final String normalized = value.trim().toLowerCase();
    return RegExp(r'^[a-z0-9-]{1,32}$').hasMatch(normalized)
        ? normalized
        : 'other';
  }

  String get dimensionKey =>
      '${day.toIso8601String().substring(0, 10)}|$experimentKey|'
      '${variant.name}|$categoryId|${audience.name}|${metric.name}';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'day': day.toIso8601String().substring(0, 10),
    'experimentKey': experimentKey,
    'variant': variant.name,
    'categoryId': categoryId,
    'audience': audience.name,
    'metric': metric.name,
  };

  static AggregateMetricKey? fromJson(Map<String, dynamic> json) {
    try {
      final String day = json['day'] as String;
      return AggregateMetricKey(
        day: DateTime.parse(day),
        experimentKey: json['experimentKey'] as String,
        variant: ExperimentVariant.values.byName(json['variant'] as String),
        categoryId: json['categoryId'] as String,
        audience: FeedAudience.values.byName(json['audience'] as String),
        metric: FeedMetricKind.values.byName(json['metric'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AggregateMetricKey &&
      other.day == day &&
      other.experimentKey == experimentKey &&
      other.variant == variant &&
      other.categoryId == categoryId &&
      other.audience == audience &&
      other.metric == metric;

  @override
  int get hashCode =>
      Object.hash(day, experimentKey, variant, categoryId, audience, metric);
}

/// Local counters for Phase 3 guardrails.
///
/// Nothing here is transmitted. Counters are aggregated by day, experiment
/// variant, category, audience and metric so the smallest possible record is a
/// cohort total rather than a reader event.
@immutable
class AggregateFeedMetrics {
  const AggregateFeedMetrics._(this._counts);

  factory AggregateFeedMetrics.empty() =>
      const AggregateFeedMetrics._(<AggregateMetricKey, int>{});

  factory AggregateFeedMetrics.fromJson(Map<String, dynamic> json) {
    final Map<AggregateMetricKey, int> counts = <AggregateMetricKey, int>{};
    final Object? rows = json['counts'];
    if (rows is List) {
      for (final Object? row in rows) {
        if (row is! Map) continue;
        final Map<String, dynamic> map = Map<String, dynamic>.from(row);
        final AggregateMetricKey? key = AggregateMetricKey.fromJson(
          map['key'] is Map
              ? Map<String, dynamic>.from(map['key'] as Map)
              : const <String, dynamic>{},
        );
        final Object? count = map['count'];
        if (key == null || count is! int || count <= 0) continue;
        counts[key] = count;
      }
    }
    return AggregateFeedMetrics._(counts);
  }

  /// Minimum cohort size before a row is considered for upload.
  static const int minimumBucketSize = 50;

  /// Local retention for aggregate counters.
  static const int retentionDays = 30;

  final Map<AggregateMetricKey, int> _counts;

  int get totalCount =>
      _counts.values.fold<int>(0, (int sum, int count) => sum + count);

  Map<AggregateMetricKey, int> get counts =>
      Map<AggregateMetricKey, int>.unmodifiable(_counts);

  int countFor(AggregateMetricKey key) => _counts[key] ?? 0;

  AggregateFeedMetrics increment(AggregateMetricKey key, {int by = 1}) {
    if (by <= 0) return this;
    return AggregateFeedMetrics._(<AggregateMetricKey, int>{
      ..._counts,
      key: countFor(key) + by,
    });
  }

  /// Drops zero/negative counters and rows older than [retentionDays].
  AggregateFeedMetrics prune({DateTime? now}) {
    final DateTime cutoff = (now ?? DateTime.now()).toUtc().subtract(
      const Duration(days: retentionDays),
    );
    return AggregateFeedMetrics._(<AggregateMetricKey, int>{
      for (final MapEntry<AggregateMetricKey, int> entry in _counts.entries)
        if (entry.value > 0 && !entry.key.day.isBefore(cutoff))
          entry.key: entry.value,
    });
  }

  /// Only k-anonymous buckets are eligible for eventual aggregation.
  List<Map<String, dynamic>> publishableRows({
    int minimumCount = minimumBucketSize,
  }) {
    final List<MapEntry<AggregateMetricKey, int>> eligible =
        <MapEntry<AggregateMetricKey, int>>[
          for (final MapEntry<AggregateMetricKey, int> entry in _counts.entries)
            if (entry.value >= minimumCount) entry,
        ];
    eligible.sort(
      (
        MapEntry<AggregateMetricKey, int> a,
        MapEntry<AggregateMetricKey, int> b,
      ) => a.key.dimensionKey.compareTo(b.key.dimensionKey),
    );
    return <Map<String, dynamic>>[
      for (final MapEntry<AggregateMetricKey, int> entry in eligible)
        <String, dynamic>{...entry.key.toJson(), 'count': entry.value},
    ];
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'counts': <Map<String, dynamic>>[
      for (final MapEntry<AggregateMetricKey, int> entry in _counts.entries)
        <String, dynamic>{'key': entry.key.toJson(), 'count': entry.value},
    ],
  };

  String encode() => jsonEncode(toJson());
}
