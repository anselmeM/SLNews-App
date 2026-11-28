import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/analytics/aggregate_feed_metrics.dart';
import '../local/preferences_store.dart';

/// Phase 3B-A never uploads. The outbox is dormant until the gates in
/// `docs/EXPERIMENTS.md` are met and a signed endpoint exists.
const bool aggregateUploadEnabled = false;

const String aggregateUploadOutboxKey = 'experiments.aggregateOutbox.v1';

/// One k-anonymous aggregate batch waiting for an upload endpoint.
@immutable
class AggregateUploadBatch {
  const AggregateUploadBatch({
    required this.id,
    required this.createdAt,
    required this.rows,
  });

  final String id;
  final DateTime createdAt;
  final List<Map<String, dynamic>> rows;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'rows': rows,
  };

  static AggregateUploadBatch? fromJson(Object? value) {
    if (value is! Map) return null;
    final Map<String, dynamic> json = Map<String, dynamic>.from(value);
    final Object? id = json['id'];
    final Object? createdAt = json['createdAt'];
    final Object? rows = json['rows'];
    if (id is! String || createdAt is! String || rows is! List) return null;
    final DateTime? at = DateTime.tryParse(createdAt);
    if (at == null) return null;
    final List<Map<String, dynamic>> normalized = <Map<String, dynamic>>[
      for (final Object? row in rows)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
    if (normalized.length != rows.length) return null;
    return AggregateUploadBatch(id: id, createdAt: at, rows: normalized);
  }
}

/// Durable, deduplicated upload queue.
///
/// No production code calls [flush] in Phase 3B-A. The class accepts a sender
/// function so the network boundary is explicit and testable; the default
/// feature flag [aggregateUploadEnabled] stays false.
class AggregateUploadOutbox {
  AggregateUploadOutbox({required this.preferences, this.maxBatches = 10});

  final PreferencesStore preferences;
  final int maxBatches;

  Future<List<AggregateUploadBatch>> pending() async {
    if (!preferences.isAvailable) return const <AggregateUploadBatch>[];
    try {
      final String? raw = preferences.string(aggregateUploadOutboxKey);
      if (raw == null || raw.isEmpty) return const <AggregateUploadBatch>[];
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return const <AggregateUploadBatch>[];
      return <AggregateUploadBatch>[
        for (final Object? entry in decoded)
          if (AggregateUploadBatch.fromJson(entry)
              case final AggregateUploadBatch batch)
            batch,
      ];
    } catch (_) {
      return const <AggregateUploadBatch>[];
    }
  }

  /// Queues publishable (k-anonymous) rows once. Returns false when there is
  /// nothing publishable or the same batch is already queued.
  Future<bool> enqueue(AggregateFeedMetrics metrics) async {
    if (!preferences.isAvailable) return false;
    final List<Map<String, dynamic>> rows = metrics.publishableRows();
    if (rows.isEmpty) return false;
    final AggregateUploadBatch batch = AggregateUploadBatch(
      id: _batchId(rows),
      createdAt: DateTime.now().toUtc(),
      rows: rows,
    );
    final List<AggregateUploadBatch> current = List<AggregateUploadBatch>.of(
      await pending(),
    );
    if (current.any((AggregateUploadBatch item) => item.id == batch.id)) {
      return false;
    }
    current.add(batch);
    while (current.length > maxBatches) {
      current.removeAt(0);
    }
    await _write(current);
    return true;
  }

  /// Sends ready batches in order. Failed batches stay queued for the next
  /// launch; successful ones are deleted immediately.
  Future<int> flush({
    required Future<void> Function(AggregateUploadBatch batch) send,
    int maxAttempts = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    final List<AggregateUploadBatch> queue = List<AggregateUploadBatch>.of(
      await pending(),
    );
    int delivered = 0;
    for (final AggregateUploadBatch batch in queue) {
      bool sent = false;
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          await send(batch);
          sent = true;
          break;
        } catch (_) {
          if (attempt < maxAttempts) await Future<void>.delayed(retryDelay);
        }
      }
      if (!sent) break;
      delivered++;
      await _removeById(batch.id);
    }
    return delivered;
  }

  Future<void> clear() async {
    if (!preferences.isAvailable) return;
    await preferences.remove(aggregateUploadOutboxKey);
  }

  Future<void> _removeById(String id) async {
    final List<AggregateUploadBatch> current = <AggregateUploadBatch>[
      for (final AggregateUploadBatch batch in await pending())
        if (batch.id != id) batch,
    ];
    await _write(current);
  }

  Future<void> _write(List<AggregateUploadBatch> batches) async {
    if (!preferences.isAvailable) return;
    await preferences.putString(
      aggregateUploadOutboxKey,
      jsonEncode(<Map<String, dynamic>>[
        for (final AggregateUploadBatch batch in batches) batch.toJson(),
      ]),
    );
  }

  static String _batchId(List<Map<String, dynamic>> rows) {
    int hash = 0x811c9dc5;
    for (final int unit in jsonEncode(rows).codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
