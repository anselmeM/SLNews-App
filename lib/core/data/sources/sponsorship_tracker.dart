import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../domain/models/ad_unit.dart';
import '../local/preferences_store.dart';
import 'api_client.dart';

import 'package:slnews_mobile/core/utils/app_log.dart';

/// Posts impression/tap counters for directly sold sponsorship units.
///
/// Fire-and-forget by design: measurement must never delay or break a feed.
/// House (seeded) units are ignored — the backend only knows sold campaigns.
/// Each event gets a stable client id so an offline retry is deduplicated by the
/// server, and sold units count at most one impression and one tap per session.
class SponsorshipTracker {
  SponsorshipTracker({
    required ApiClient client,
    required this.baseUrl,
    this.store,
  }) : _post = ((String url, Map<String, dynamic> body) =>
           client.postJson(url, body));

  /// Test seam.
  @visibleForTesting
  SponsorshipTracker.forPoster(
    Future<Object?> Function(String url, Map<String, dynamic> body) post, {
    this.store,
  }) : baseUrl = 'https://example.invalid',
       _post = post;

  static const String outboxKey = 'sponsorship_events.outbox.v1';
  static const int maxOutbox = 100;

  final String baseUrl;
  final PreferencesStore? store;
  final Future<Object?> Function(String url, Map<String, dynamic> body) _post;

  final Set<String> _impressed = <String>{};
  final Set<String> _tapped = <String>{};

  /// A stable event id per unit/type, reused when a failed post is retried. The
  /// server's unique event ledger makes that retry idempotent.
  final Map<String, String> _eventIds = <String, String>{};
  Future<void> _outboxQueue = Future<void>.value();
  bool _flushing = false;

  void impression(AdUnit unit) {
    if (!unit.isSold || !_impressed.add(unit.id)) return;
    _send(unit, 'impression', onFailure: () => _impressed.remove(unit.id));
  }

  void tap(AdUnit unit) {
    if (!unit.isSold || !_tapped.add(unit.id)) return;
    _send(unit, 'tap', onFailure: () => _tapped.remove(unit.id));
  }

  /// Retries events left in the on-device outbox by a previous run.
  Future<void> flush() async {
    final PreferencesStore? store = this.store;
    if (store == null || _flushing) return;
    _flushing = true;
    try {
      final List<Map<String, dynamic>> events = _readOutbox(store);
      for (final Map<String, dynamic> event in events) {
        try {
          await _post(_url(), event);
          await _removeFromOutbox(store, event['eventId'] as String?);
        } catch (error) {
          if (_isPermanentFailure(error)) {
            // An expired token or an invalid event can never succeed on retry.
            // Drop it and keep delivering the events behind it.
            await _removeFromOutbox(store, event['eventId'] as String?);
            continue;
          }
          // Transient network/server failure: keep the queue for the next launch.
          break;
        }
      }
    } finally {
      _flushing = false;
    }
  }

  /// True for client errors that a retry cannot fix (expired token, rejected
  /// event). 408/429 are explicitly transient.
  static bool _isPermanentFailure(Object error) {
    if (error is! ApiException) return false;
    final int? status = error.statusCode;
    return status != null &&
        status >= 400 &&
        status < 500 &&
        status != 408 &&
        status != 429;
  }

  void _send(AdUnit unit, String type, {VoidCallback? onFailure}) {
    if (!unit.isSold) return;
    final String eventId = _eventIds.putIfAbsent(
      '${unit.id}:$type',
      _newEventId,
    );
    final Map<String, dynamic> body = <String, dynamic>{
      'id': unit.id,
      'type': type,
      'eventId': eventId,
      if (unit.eventToken != null) 'token': unit.eventToken,
    };
    unawaited(_enqueue(body));
    unawaited(
      _post(_url(), body).then<void>(
        (Object? _) => _removeFromOutbox(store, eventId),
        onError: (Object error, StackTrace stack) {
          if (_isPermanentFailure(error)) {
            // Do not leave an unsendable event at the head of the outbox or
            // retry it for the rest of the session.
            unawaited(_removeFromOutbox(store, eventId));
            AppLog.debug(
              'SponsorshipTracker: $type permanently rejected: $error',
            );
            return;
          }
          onFailure?.call();
          AppLog.debug('SponsorshipTracker: $type not counted: $error');
        },
      ),
    );
  }

  String _url() {
    return '${baseUrl.replaceAll(RegExp(r"/+$"), "")}'
        '/api/mobile/v1/sponsorships/events';
  }

  Future<void> _enqueue(Map<String, dynamic> event) {
    final PreferencesStore? store = this.store;
    if (store == null) return Future<void>.value();
    _outboxQueue = _outboxQueue.then((_) async {
      final List<Map<String, dynamic>> events = _readOutbox(store);
      events.removeWhere(
        (Map<String, dynamic> queued) => queued['eventId'] == event['eventId'],
      );
      events.add(event);
      if (events.length > maxOutbox) {
        events.removeRange(0, events.length - maxOutbox);
      }
      await store.putString(outboxKey, jsonEncode(events));
    });
    return _outboxQueue;
  }

  Future<void> _removeFromOutbox(
    PreferencesStore? store,
    String? eventId,
  ) async {
    if (store == null || eventId == null) return;
    _outboxQueue = _outboxQueue.then((_) async {
      final List<Map<String, dynamic>> events = _readOutbox(store);
      final int before = events.length;
      events.removeWhere(
        (Map<String, dynamic> queued) => queued['eventId'] == eventId,
      );
      if (events.length != before) {
        await store.putString(outboxKey, jsonEncode(events));
      }
    });
    await _outboxQueue;
  }

  List<Map<String, dynamic>> _readOutbox(PreferencesStore store) {
    try {
      final Object? decoded = jsonDecode(store.string(outboxKey) ?? '[]');
      if (decoded is! List) return <Map<String, dynamic>>[];
      return <Map<String, dynamic>>[
        for (final Object? item in decoded)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static final Random _random = Random.secure();

  static String _newEventId() {
    final String random = List<String>.generate(
      12,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return 'ev_${DateTime.now().toUtc().microsecondsSinceEpoch}_$random';
  }
}
