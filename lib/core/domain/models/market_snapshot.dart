import 'package:flutter/foundation.dart';

/// A currency the Markets module quotes.
@immutable
class CurrencyInfo {
  const CurrencyInfo({
    required this.code,
    required this.name,
    required this.symbol,
    this.decimals = 2,
  });

  final String code;
  final String name;

  /// Prefix used in the UI, e.g. `Le` for the leone.
  final String symbol;

  /// Decimal places worth showing for this pair.
  final int decimals;
}

/// What the interactive "Markets" module shows, in display order.
///
/// Sierra Leone first: the leone pair is the one a reader actually needs. Both
/// the new and old leone codes are quoted because the two coexist during the
/// redenomination.
const List<CurrencyInfo> trackedCurrencies = <CurrencyInfo>[
  CurrencyInfo(code: 'SLE', name: 'Sierra Leone (new leone)', symbol: 'Le'),
  CurrencyInfo(code: 'SLL', name: 'Sierra Leone (old leone)', symbol: 'Le'),
  CurrencyInfo(code: 'GBP', name: 'British pound', symbol: '£', decimals: 4),
  CurrencyInfo(code: 'EUR', name: 'Euro', symbol: '€', decimals: 4),
  CurrencyInfo(code: 'NGN', name: 'Nigerian naira', symbol: '₦'),
  CurrencyInfo(code: 'GHS', name: 'Ghanaian cedi', symbol: '₵'),
  CurrencyInfo(code: 'XOF', name: 'West African CFA franc', symbol: 'CFA'),
];

/// One currency's rate against the base currency.
@immutable
class MarketRate {
  const MarketRate({
    required this.info,
    required this.perBase,
    this.decimalsOverride,
  });

  final CurrencyInfo info;

  /// Units of this currency per one unit of the snapshot's base.
  final double perBase;

  final int? decimalsOverride;

  int get decimals => decimalsOverride ?? info.decimals;

  /// e.g. "Le 24.36" or "£ 0.7508".
  String get formatted =>
      '${info.symbol} ${formatRate(perBase, decimals: decimals)}';
}

/// A currency board: one base currency, a set of rates and the instant they are
/// valid for.
///
/// Kept separate from the widget tree so the parse and the offline cache can be
/// tested without a network. Rates are quoted per 1 unit of [base].
@immutable
class MarketSnapshot {
  const MarketSnapshot({
    required this.base,
    required this.rates,
    required this.updatedAt,
    required this.source,
  });

  /// Base currency the rates are quoted against ("USD").
  final String base;

  /// Currency code → units per one [base].
  final Map<String, double> rates;

  final DateTime updatedAt;

  /// Attribution line, e.g. "open.er-api.com".
  final String source;

  /// Placeholder used when there is neither a network answer nor a cache.
  static final MarketSnapshot empty = MarketSnapshot(
    base: 'USD',
    rates: const <String, double>{},
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    source: 'open.er-api.com',
  );

  bool get isEmpty => rates.isEmpty;

  double? rateOf(String code) => rates[code.toUpperCase()];

  /// The tracked currencies this snapshot actually quotes, in display order.
  List<MarketRate> get board => <MarketRate>[
    for (final CurrencyInfo info in trackedCurrencies)
      if (rateOf(info.code) != null)
        MarketRate(info: info, perBase: rateOf(info.code)!),
  ];

  /// One unit of [code] expressed in the base currency, e.g. "£1 ≈ Le 32,443".
  double? crossInBase(String code) {
    final double? perBase = rateOf(code);
    if (perBase == null || perBase == 0) return null;
    return 1 / perBase;
  }

  factory MarketSnapshot.fromJson(Map<String, dynamic> json) {
    final Map<String, double> parsed = <String, double>{};
    final Object? rawRates = json['rates'];
    if (rawRates is Map) {
      for (final MapEntry<Object?, Object?> entry in rawRates.entries) {
        final String code = '${entry.key}';
        final Object? value = entry.value;
        if (value is num) parsed[code] = value.toDouble();
      }
    }
    return MarketSnapshot(
      base: '${json['base'] ?? 'USD'}',
      rates: parsed,
      updatedAt:
          _instant(json['updated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      source: '${json['source'] ?? 'open.er-api.com'}',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'base': base,
    'rates': rates,
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'source': source,
  };

  static DateTime? _instant(Object? value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        value > 100000000000 ? value.toInt() : value.toInt() * 1000,
        isUtc: true,
      );
    }
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }
}

/// Formats a rate with thousands separators and a sensible precision.
///
/// Six decimals for sub-unit rates (a pound buys 0.75 dollars), two for the
/// four-figure leone pairs, and grouping so 24357.93 reads as 24,357.93.
String formatRate(double value, {int decimals = 2}) {
  final String fixed = value.toStringAsFixed(decimals);
  final int dot = fixed.indexOf('.');
  final String whole = dot == -1 ? fixed : fixed.substring(0, dot);
  final String fraction = dot == -1 ? '' : fixed.substring(dot);

  final StringBuffer grouped = StringBuffer();
  for (int index = 0; index < whole.length; index++) {
    if (index > 0 && (whole.length - index) % 3 == 0) grouped.write(',');
    grouped.write(whole[index]);
  }
  return '${grouped.toString()}$fraction';
}
