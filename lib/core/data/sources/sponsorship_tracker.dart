import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/ad_unit.dart';
import 'api_client.dart';

import 'package:slnews_mobile/core/utils/app_log.dart';

/// Posts impression/tap counters for directly sold sponsorship units.
///
/// Fire-and-forget by design: measurement must never delay or break a feed. House
/// (seeded) units are ignored — the backend only knows sold campaigns.
class SponsorshipTracker {
  SponsorshipTracker({required ApiClient client, required this.baseUrl})
    : _post = ((String url, Map<String, dynamic> body) =>
          client.postJson(url, body));

  /// Test seam.
  @visibleForTesting
  SponsorshipTracker.forPoster(
    Future<Object?> Function(String url, Map<String, dynamic> body) post,
  ) : baseUrl = 'https://example.invalid',
      _post = post;

  final String baseUrl;
  final Future<Object?> Function(String url, Map<String, dynamic> body) _post;

  /// One impression per sold unit per app session. A widget remount (list
  /// recycling, refresh, retry) must not bill the advertiser twice.
  final Set<String> _impressed = <String>{};

  void impression(AdUnit unit) {
    if (!unit.isSold || !_impressed.add(unit.id)) return;
    _send(unit, 'impression', onFailure: () => _impressed.remove(unit.id));
  }

  void tap(AdUnit unit) => _send(unit, 'tap');

  void _send(AdUnit unit, String type, {VoidCallback? onFailure}) {
    if (!unit.isSold) return;
    final String url =
        '${baseUrl.replaceAll(RegExp(r"/+$"), "")}'
        '/api/mobile/v1/sponsorships/events';
    unawaited(
      _post(url, <String, dynamic>{'id': unit.id, 'type': type}).then<void>(
        (Object? _) {},
        onError: (Object error, StackTrace stack) {
          onFailure?.call();
          AppLog.debug('SponsorshipTracker: $type not counted: $error');
        },
      ),
    );
  }
}
