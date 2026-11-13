import 'package:flutter/foundation.dart';

import '../../domain/models/index_quote.dart';
import 'api_client.dart';

import 'package:slnews_mobile/core/utils/app_log.dart';

/// Reads the index board for the Stocks section.
///
/// Source: Yahoo Finance's public chart endpoint, which is keyless and answers
/// with the session's price, the previous close and every intraday close - the
/// three things the reference board shows (price, percent move, sparkline).
/// One request per symbol: the endpoint has no batch form that stays keyless,
/// and four small reads are cheap enough.
///
/// Never throws: like the markets module this is a bonus surface, so an offline
/// reader gets the cached board (or nothing) rather than a broken feed.
class IndexQuoteSource {
  IndexQuoteSource(this._api);

  static const String sourceLabel = 'yahoo/finance';

  /// The indices the reference board lists.
  static const List<({String symbol, String name, String subtitle})> tracked =
      <({String symbol, String name, String subtitle})>[
        (symbol: '^IXIC', name: 'Nasdaq Comp', subtitle: 'NASDAQ Composite'),
        (symbol: '^RUT', name: 'Russell 2000', subtitle: 'Russell 2000 Index'),
        (
          symbol: '^DJI',
          name: 'Dow Jones',
          subtitle: 'Dow Jones Industrial Average',
        ),
        (symbol: '^GSPC', name: 'S&P 500', subtitle: 'S&P 500 Index'),
        (
          symbol: '^GSPTSE',
          name: 'TSX Comp',
          subtitle: 'S&P/TSX Composite index',
        ),
      ];

  final ApiClient _api;

  /// Chart endpoint for one symbol; `range=1d` keeps the sparkline to one day.
  static String chartUrl(String symbol) =>
      'https://query1.finance.yahoo.com/v8/finance/chart/'
      '${Uri.encodeComponent(symbol)}?range=1d&interval=5m';

  Future<IndexBoard?> fetch() async {
    final List<IndexQuote> quotes = <IndexQuote>[];
    for (final ({String symbol, String name, String subtitle}) entry
        in tracked) {
      try {
        final Object? payload = await _api.getJson(chartUrl(entry.symbol));
        final ({double price, double changePercent, List<double> sparkline})?
        parsed = parseChart(payload);
        if (parsed == null) continue;
        quotes.add(
          IndexQuote(
            symbol: entry.symbol,
            name: entry.name,
            subtitle: entry.subtitle,
            price: parsed.price,
            changePercent: parsed.changePercent,
            sparkline: parsed.sparkline,
          ),
        );
      } catch (error) {
        AppLog.debug('IndexQuoteSource: ${entry.symbol} unavailable ($error)');
      }
    }
    if (quotes.isEmpty) return null;
    return IndexBoard(
      quotes: quotes,
      updatedAt: DateTime.now(),
      sourceLabel: sourceLabel,
      isOpen: marketOpen(DateTime.now()),
    );
  }

  /// Pulls price, session move and sparkline out of a chart payload.
  ///
  /// Anything that is not the documented chart shape is rejected rather than
  /// half-read, so an error page cannot masquerade as a quote.
  @visibleForTesting
  static ({double price, double changePercent, List<double> sparkline})?
  parseChart(Object? payload) {
    if (payload is! Map) return null;
    final Object? chart = payload['chart'];
    if (chart is! Map) return null;
    final Object? results = chart['result'];
    if (results is! List || results.isEmpty) return null;
    final Object? result = results.first;
    if (result is! Map) return null;
    final Object? meta = result['meta'];
    if (meta is! Map) return null;

    final List<double> closes = <double>[];
    final Object? indicators = result['indicators'];
    if (indicators is Map) {
      final Object? quoteList = indicators['quote'];
      if (quoteList is List && quoteList.isNotEmpty) {
        final Object? quote = quoteList.first;
        if (quote is Map) {
          final Object? rawCloses = quote['close'];
          if (rawCloses is List) {
            for (final Object? close in rawCloses) {
              if (close is num) closes.add(close.toDouble());
            }
          }
        }
      }
    }

    final double? price = (meta['regularMarketPrice'] as num?)?.toDouble();
    final double? previous =
        (meta['chartPreviousClose'] as num?)?.toDouble() ??
        (meta['previousClose'] as num?)?.toDouble();
    final double? last = price ?? (closes.isEmpty ? null : closes.last);
    if (last == null || last <= 0) return null;

    final double change = (previous != null && previous > 0)
        ? (last - previous) / previous * 100
        : 0;

    return (price: last, changePercent: change, sparkline: _thin(closes, 24));
  }

  /// Evenly samples [points] so the cache and the painter stay small.
  static List<double> _thin(List<double> points, int limit) {
    if (points.length <= limit) return points;
    final List<double> sampled = <double>[];
    final double step = points.length / limit;
    for (int index = 0; index < limit; index++) {
      sampled.add(points[(index * step).floor().clamp(0, points.length - 1)]);
    }
    return sampled;
  }

  /// Whether the New York session is open, in New York time.
  ///
  /// US daylight saving runs from the second Sunday in March to the first Sunday
  /// in November, which is enough to place 09:30-16:00 ET without a time-zone
  /// database; the label is a status hint, not a trading signal.
  @visibleForTesting
  static bool marketOpen(DateTime now) {
    final DateTime utc = now.toUtc();
    if (utc.weekday == DateTime.saturday || utc.weekday == DateTime.sunday) {
      return false;
    }
    final int minutes =
        ((utc.hour + _newYorkOffset(utc) + 24) % 24) * 60 + utc.minute;
    return minutes >= 9 * 60 + 30 && minutes < 16 * 60;
  }

  static int _newYorkOffset(DateTime utc) {
    final DateTime dstStart = _nthSunday(utc.year, 3, 2);
    final DateTime dstEnd = _nthSunday(utc.year, 11, 1);
    final DateTime day = DateTime.utc(utc.year, utc.month, utc.day);
    final bool daylight = !day.isBefore(dstStart) && day.isBefore(dstEnd);
    return daylight ? -4 : -5;
  }

  static DateTime _nthSunday(int year, int month, int n) {
    DateTime date = DateTime.utc(year, month, 1);
    while (date.weekday != DateTime.sunday) {
      date = date.add(const Duration(days: 1));
    }
    return date.add(Duration(days: 7 * (n - 1)));
  }
}
