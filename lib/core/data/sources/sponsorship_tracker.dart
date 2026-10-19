import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/ad_unit.dart';
import 'api_client.dart';

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

  void impression(AdUnit unit) => _send(unit, 'impression');

  void tap(AdUnit unit) => _send(unit, 'tap');

  void _send(AdUnit unit, String type) {
    if (!unit.isSold) return;
    final String url =
        '${baseUrl.replaceAll(RegExp(r"/+$"), "")}'
        '/api/mobile/v1/sponsorships/events';
    unawaited(
      _post(url, <String, dynamic>{'id': unit.id, 'type': type}).then<void>(
        (Object? _) {},
        onError: (Object error, StackTrace stack) {
          debugPrint('SponsorshipTracker: $type not counted: $error');
        },
      ),
    );
  }
}
