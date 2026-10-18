import 'package:flutter/foundation.dart';

/// One market index quote, as the Stocks section shows it.
///
/// The reference board is four index rows with a price, a percentage move and a
/// sparkline; this is that shape, kept independent of whichever provider sourced
/// the numbers so the UI and cache do not depend on the wire format.
@immutable
class IndexQuote {
  const IndexQuote({
    required this.symbol,
    required this.name,
    required this.subtitle,
    required this.price,
    required this.changePercent,
    this.sparkline = const <double>[],
  });

  /// Provider symbol, e.g. `^IXIC`.
  final String symbol;

  /// Short label, e.g. "Nasdaq Comp".
  final String name;

  /// Long label, e.g. "NASDAQ Composite".
  final String subtitle;

  final double price;

  /// Percent move for the session; negative means down.
  final double changePercent;

  /// Intraday closes, oldest first, for the trend line. Empty when unavailable.
  final List<double> sparkline;

  bool get isUp => changePercent >= 0;

  /// "-2.94%" / "+0.10%".
  String get changeLabel =>
      '${isUp ? '+' : ''}${changePercent.toStringAsFixed(2)}%';

  /// "26,140.03" - grouped thousands, two decimals.
  String get priceLabel => formatQuotePrice(price);

  Map<String, Object?> toJson() => <String, Object?>{
    'symbol': symbol,
    'name': name,
    'subtitle': subtitle,
    'price': price,
    'changePercent': changePercent,
    'sparkline': sparkline,
  };

  factory IndexQuote.fromJson(Map<String, dynamic> json) => IndexQuote(
    symbol: json['symbol'] as String? ?? '',
    name: json['name'] as String? ?? '',
    subtitle: json['subtitle'] as String? ?? '',
    price: (json['price'] as num?)?.toDouble() ?? 0,
    changePercent: (json['changePercent'] as num?)?.toDouble() ?? 0,
    sparkline: <double>[
      for (final Object? point
          in (json['sparkline'] as List<Object?>? ?? const <Object?>[]))
        if (point is num) point.toDouble(),
    ],
  );
}

/// The index board with its provenance, so the UI can print attribution and
/// whether the market is open instead of implying live data.
@immutable
class IndexBoard {
  const IndexBoard({
    required this.quotes,
    required this.updatedAt,
    required this.sourceLabel,
    required this.isOpen,
  });

  final List<IndexQuote> quotes;
  final DateTime updatedAt;
  final String sourceLabel;
  final bool isOpen;

  bool get isEmpty => quotes.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    'quotes': <Map<String, Object?>>[
      for (final IndexQuote quote in quotes) quote.toJson(),
    ],
    'updatedAt': updatedAt.toIso8601String(),
    'sourceLabel': sourceLabel,
    'isOpen': isOpen,
  };

  factory IndexBoard.fromJson(Map<String, dynamic> json) => IndexBoard(
    quotes: <IndexQuote>[
      for (final Object? raw
          in (json['quotes'] as List<Object?>? ?? const <Object?>[]))
        if (raw is Map)
          IndexQuote.fromJson(<String, dynamic>{
            for (final MapEntry<Object?, Object?> entry in raw.entries)
              '${entry.key}': entry.value,
          }),
    ],
    updatedAt:
        DateTime.tryParse('${json['updatedAt']}')?.toLocal() ?? DateTime.now(),
    sourceLabel: json['sourceLabel'] as String? ?? '',
    isOpen: json['isOpen'] as bool? ?? false,
  );
}

/// "26140.03" -> "26,140.03". Grouping is done by hand because `intl` is not a
/// dependency and this is the only place the app needs it.
String formatQuotePrice(double value) {
  final String fixed = value.toStringAsFixed(2);
  final int dot = fixed.indexOf('.');
  final String whole = dot < 0 ? fixed : fixed.substring(0, dot);
  final String decimals = dot < 0 ? '00' : fixed.substring(dot + 1);
  final StringBuffer grouped = StringBuffer();
  for (int index = 0; index < whole.length; index++) {
    grouped.write(whole[index]);
    final int remaining = whole.length - index - 1;
    if (remaining > 0 && remaining % 3 == 0) grouped.write(',');
  }
  return '$grouped.$decimals';
}
