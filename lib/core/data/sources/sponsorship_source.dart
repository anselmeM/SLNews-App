import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/ad_unit.dart';
import '../sources/api_client.dart';

/// Fetches directly sold sponsorship units from the SLNews backend.
///
/// The endpoint is public and returns units already shaped like [AdUnit]; this
/// source only has to turn JSON into models and never throw, because an ad
/// surface must never break the feed it sits in.
class SponsorshipSource {
  /// Creates a source that talks to [baseUrl] through [client].
  SponsorshipSource({required ApiClient client, required this.baseUrl})
    : _fetch = ((String url) => client.getJson(url));

  /// Test seam: a plain fetcher with no HTTP client or platform channel.
  @visibleForTesting
  SponsorshipSource.forFetcher(Future<Object?> Function(String url) fetch)
    : baseUrl = 'https://example.invalid',
      _fetch = fetch;

  static const Duration timeout = Duration(seconds: 5);

  final String baseUrl;
  final Future<Object?> Function(String url) _fetch;

  /// Sold units for [placement]; empty when nothing is sold, unreachable or
  /// malformed.
  Future<List<AdUnit>> units(String placement) async {
    final String url =
        '${baseUrl.replaceAll(RegExp(r"/+$"), "")}/api/mobile/v1/sponsorships'
        '?placement=${Uri.encodeQueryComponent(placement)}';
    try {
      final Object? payload = await _fetch(url).timeout(timeout);
      final Object? items = payload is Map ? payload['items'] : null;
      if (items is! List) return const <AdUnit>[];
      final List<AdUnit> units = <AdUnit>[];
      for (final Object? item in items) {
        if (item is! Map) continue;
        try {
          units.add(AdUnit.fromSponsorship(Map<String, dynamic>.from(item)));
        } catch (error) {
          debugPrint('SponsorshipSource: skipping malformed unit: $error');
        }
      }
      return List<AdUnit>.unmodifiable(units);
    } catch (error) {
      debugPrint('SponsorshipSource: unavailable: $error');
      return const <AdUnit>[];
    }
  }
}
