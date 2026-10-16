import 'package:flutter/foundation.dart';

/// Optional weather strip in the For You header.
@immutable
class WeatherSnapshot {
  const WeatherSnapshot({
    required this.locationLabel,
    required this.temperatureC,
    required this.conditionLabel,
    required this.glyph,
    this.highC,
    this.lowC,
    this.humidityPercent,
    required this.updatedAt,
  });

  /// "Freetown" — the active [NewsLocation] label.
  final String locationLabel;

  final int temperatureC;
  final String conditionLabel;

  /// Icon key resolved by `WeatherGlyph` (e.g. `storm`, `sun`, `cloud`).
  final String glyph;

  final int? highC;
  final int? lowC;
  final int? humidityPercent;
  final DateTime updatedAt;

  /// "29° · Thundery showers" — the compact label used by the header chip.
  String get compactLabel => '$temperatureC° · $conditionLabel';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'locationLabel': locationLabel,
    'temperatureC': temperatureC,
    'conditionLabel': conditionLabel,
    'glyph': glyph,
    'highC': highC,
    'lowC': lowC,
    'humidityPercent': humidityPercent,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) =>
      WeatherSnapshot(
        locationLabel: json['locationLabel'] as String,
        temperatureC: (json['temperatureC'] as num).toInt(),
        conditionLabel: json['conditionLabel'] as String,
        glyph: json['glyph'] as String? ?? 'sun',
        highC: (json['highC'] as num?)?.toInt(),
        lowC: (json['lowC'] as num?)?.toInt(),
        humidityPercent: (json['humidityPercent'] as num?)?.toInt(),
        updatedAt: json['updatedAt'] == null
            ? DateTime.now()
            : DateTime.parse(json['updatedAt'] as String),
      );

  /// Used before the first successful weather fetch, so the header never jitters.
  static WeatherSnapshot placeholder(String locationLabel) => WeatherSnapshot(
    locationLabel: locationLabel,
    temperatureC: 29,
    conditionLabel: 'Thundery showers',
    glyph: 'storm',
    highC: 31,
    lowC: 24,
    humidityPercent: 82,
    updatedAt: DateTime.now(),
  );

  @override
  bool operator ==(Object other) =>
      other is WeatherSnapshot &&
      other.locationLabel == locationLabel &&
      other.temperatureC == temperatureC &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(locationLabel, temperatureC, updatedAt);
}
