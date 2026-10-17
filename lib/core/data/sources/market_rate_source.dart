import 'package:flutter/foundation.dart';

import '../../domain/models/market_snapshot.dart';
import 'api_client.dart';

/// Reads the Markets module's currency board.
///
/// Source: <https://open.er-api.com>, a documented, keyless exchange-rate feed
/// that quotes the Leone — which is what a SLNews reader actually needs, and the
/// reason this module is not an embedded third-party page: framing another site
/// breaks their terms, their layout and our offline mode, while one JSON read
/// gives the same numbers with our own UI and cache.
class MarketRateSource {
  MarketRateSource(this._api, {this.url = defaultUrl});

  /// The endpoint. `USD` base because a dollar price is how Sierra Leonean
  /// traders quote the leone.
  static const String defaultUrl = 'https://open.er-api.com/v6/latest/USD';

  /// Attribution shown under the board.
  static const String sourceLabel = 'open.er-api.com';

  final ApiClient _api;
  final String url;

  /// The current board, or `null` when the service is unreachable or answers
  /// with something that is not a rate table.
  ///
  /// Never throws: the module is a bonus surface and must degrade to its cache
  /// (or to an "unavailable" line) instead of breaking the feed.
  Future<MarketSnapshot?> fetch() async {
    try {
      final Object? payload = await _api.getJson(url);
      return parse(payload);
    } catch (error) {
      debugPrint('MarketRateSource: rates unavailable ($error)');
      return null;
    }
  }

  /// Turns the service payload into a snapshot.
  ///
  /// The feed answers `{"result":"success","base_code":"USD","rates":{...},
  /// "time_last_update_unix":…}`; anything else is treated as unusable rather
  /// than trusted, so a proxy error page cannot masquerade as a rate board.
  @visibleForTesting
  static MarketSnapshot? parse(Object? payload) {
    if (payload is! Map) return null;
    if (payload['result'] != null && payload['result'] != 'success') {
      return null;
    }

    final Object? rawRates = payload['rates'];
    if (rawRates is! Map) return null;

    final Map<String, double> rates = <String, double>{};
    for (final MapEntry<Object?, Object?> entry in rawRates.entries) {
      final Object? value = entry.value;
      if (value is num) rates['${entry.key}'.toUpperCase()] = value.toDouble();
    }
    if (rates.isEmpty) return null;

    final Object? updated =
        payload['time_last_update_unix'] ?? payload['time_last_update_utc'];

    return MarketSnapshot(
      base: '${payload['base_code'] ?? 'USD'}',
      rates: rates,
      updatedAt:
          _instant(updated) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      source: sourceLabel,
    );
  }

  static DateTime? _instant(Object? value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.toInt() * 1000,
        isUtc: true,
      );
    }
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }
}
