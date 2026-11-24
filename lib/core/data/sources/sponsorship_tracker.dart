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
///
/// Measurement is one event per view: every [impression] and every [tap] creates
/// a fresh event with a fresh `eventId`. The tracker deliberately does not
/// deduplicate a campaign per session any more; the server's unique event ledger
/// collapses only a retried copy of the *same* event, which is why a queued
/// event keeps its id until it is delivered or permanently rejected.
///
/// Every event also carries a stable anonymous `installId`: 32 lowercase hex
/// characters generated once per install with [Random.secure] and persisted in
/// [PreferencesStore] under [installIdKey]. It is never derived from, or linked
/// to, the reader's account identity.
class SponsorshipTracker {
  SponsorshipTracker({
    required ApiClient client,
    required this.baseUrl,
    this.store,
  }) : _newInstallId = _secureInstallId,
       _post = ((String url, Map<String, dynamic> body) =>
           client.postJson(url, body));

  /// Test seam.
  @visibleForTesting
  SponsorshipTracker.forPoster(
    Future<Object?> Function(String url, Map<String, dynamic> body) post, {
    this.store,
    String Function()? newInstallId,
  }) : baseUrl = 'https://example.invalid',
       _post = post,
       _newInstallId = newInstallId ?? _secureInstallId;

  static const String outboxKey = 'sponsorship_events.outbox.v1';

  /// Versioned preference key holding the anonymous install id.
  static const String installIdKey = 'sponsorship.installId.v1';

  static const int maxOutbox = 100;

  final String baseUrl;
  final PreferencesStore? store;
  final Future<Object?> Function(String url, Map<String, dynamic> body) _post;

  /// Generates a new install id; a test seam can replace the secure default.
  final String Function() _newInstallId;

  /// Resolved once per tracker and reused for every event it posts. Kept even
  /// when persistence fails so a tracker never reports two identities.
  String? _installId;

  Future<void> _outboxQueue = Future<void>.value();
  bool _flushing = false;

  /// Stable anonymous install id sent as `installId` on every event.
  ///
  /// The persisted value wins across launches and instances sharing this
  /// [store]. When it is absent (first launch, first event) the id is generated
  /// with [Random.secure] and written back best-effort. A tracker with no store
  /// still caches the generated value for its own lifetime.
  String get installId {
    final String? cached = _installId;
    if (cached != null) return cached;

    final String? stored = store?.string(installIdKey);
    final String id = _isValidInstallId(stored) ? stored! : _newInstallId();
    _installId = id;

    final PreferencesStore? preferences = store;
    if (preferences != null && id != stored) {
      unawaited(_persistInstallId(preferences, id));
    }
    return id;
  }

  /// Records one impression for [unit]. Every call is a separate event.
  void impression(AdUnit unit) {
    if (!unit.isSold) return;
    _send(unit, 'impression');
  }

  /// Records one tap for [unit]. Every call is a separate event.
  void tap(AdUnit unit) {
    if (!unit.isSold) return;
    _send(unit, 'tap');
  }

  /// Retries events left in the on-device outbox by a previous run.
  ///
  /// Each queued body already carries its own `eventId`, so a retried event is
  /// the same event to the server — never a new impression.
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

  void _send(AdUnit unit, String type) {
    final String eventId = _newEventId();
    final Map<String, dynamic> body = <String, dynamic>{
      'id': unit.id,
      'type': type,
      'eventId': eventId,
      'installId': installId,
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
          AppLog.debug('SponsorshipTracker: $type not counted: $error');
        },
      ),
    );
  }

  String _url() {
    return '${baseUrl.replaceAll(RegExp(r"/+$"), "")}'
        '/api/mobile/v1/sponsorships/events';
  }

  Future<void> _persistInstallId(PreferencesStore store, String id) async {
    try {
      await store.putString(installIdKey, id);
    } catch (error) {
      // Storage is best-effort: the tracker keeps this id for its lifetime and
      // the next launch may generate a new one rather than failing to measure.
      AppLog.debug('SponsorshipTracker: could not persist install id: $error');
    }
  }

  static final RegExp _installIdPattern = RegExp(r'^[0-9a-f]{32}$');

  static bool _isValidInstallId(String? value) =>
      value != null && _installIdPattern.hasMatch(value);

  /// 128 random bits rendered as 32 lowercase hex characters.
  static String _secureInstallId() {
    final StringBuffer id = StringBuffer();
    for (int index = 0; index < 16; index++) {
      id.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return id.toString();
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

  /// A fresh id for one event. Reused only by an outbox retry of that event.
  static String _newEventId() {
    final String random = List<String>.generate(
      12,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return 'ev_${DateTime.now().toUtc().microsecondsSinceEpoch}_$random';
  }
}
