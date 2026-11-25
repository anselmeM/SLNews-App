import 'package:flutter/foundation.dart';

import 'follow_models.dart';

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
    this.isAvailable = true,
    this.isLoading = false,
    this.locationId,
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

  /// False when live weather could not be loaded and no bundled snapshot
  /// applies (for example a device location while offline). The card hides the
  /// fake temperature instead of showing an invented forecast.
  final bool isAvailable;

  /// True while the first forecast for the selected place is still loading.
  final bool isLoading;

  /// Stable [NewsLocation.id] that produced this snapshot.
  ///
  /// The card refuses to show a snapshot whose id does not match the selected
  /// place, so a retained AsyncValue from the previous location cannot leak
  /// stale weather into the new place.
  final String? locationId;

  /// True when this snapshot belongs to [location].
  ///
  /// Older/seed snapshots may lack [locationId]; those fall back to the label.
  bool matches(NewsLocation location) {
    if (locationId != null) return locationId == location.id;
    return locationLabel == location.label;
  }

  /// "29° · Thundery showers" — the compact label used by the header chip.
  String get compactLabel =>
      isAvailable ? '$temperatureC° · $conditionLabel' : conditionLabel;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'locationLabel': locationLabel,
    'temperatureC': temperatureC,
    'conditionLabel': conditionLabel,
    'glyph': glyph,
    'highC': highC,
    'lowC': lowC,
    'humidityPercent': humidityPercent,
    'updatedAt': updatedAt.toIso8601String(),
    'isAvailable': isAvailable,
    'isLoading': isLoading,
    'locationId': locationId,
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
        isAvailable: json['isAvailable'] as bool? ?? true,
        isLoading: json['isLoading'] as bool? ?? false,
        locationId: json['locationId'] as String?,
      );

  /// Honest fallback for a location with no live forecast and no bundled seed.
  factory WeatherSnapshot.unavailable(
    String locationLabel, {
    String? locationId,
  }) => WeatherSnapshot(
    locationLabel: locationLabel,
    temperatureC: 0,
    conditionLabel: 'Weather unavailable',
    glyph: 'unavailable',
    updatedAt: DateTime.now(),
    isAvailable: false,
    locationId: locationId,
  );

  /// Honest loading state; it carries no temperature or condition.
  factory WeatherSnapshot.loading(String locationLabel, {String? locationId}) =>
      WeatherSnapshot(
        locationLabel: locationLabel,
        temperatureC: 0,
        conditionLabel: 'Loading weather…',
        glyph: 'loading',
        updatedAt: DateTime.now(),
        isAvailable: false,
        isLoading: true,
        locationId: locationId,
      );

  /// Legacy fixture kept for callers/tests that predate the honest states.
  /// Production code must use [unavailable] or a real forecast instead.
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

  WeatherSnapshot copyWith({
    String? locationLabel,
    String? locationId,
    int? temperatureC,
    String? conditionLabel,
    String? glyph,
    int? highC,
    int? lowC,
    int? humidityPercent,
    DateTime? updatedAt,
    bool? isAvailable,
    bool? isLoading,
  }) => WeatherSnapshot(
    locationLabel: locationLabel ?? this.locationLabel,
    locationId: locationId ?? this.locationId,
    temperatureC: temperatureC ?? this.temperatureC,
    conditionLabel: conditionLabel ?? this.conditionLabel,
    glyph: glyph ?? this.glyph,
    highC: highC ?? this.highC,
    lowC: lowC ?? this.lowC,
    humidityPercent: humidityPercent ?? this.humidityPercent,
    updatedAt: updatedAt ?? this.updatedAt,
    isAvailable: isAvailable ?? this.isAvailable,
    isLoading: isLoading ?? this.isLoading,
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
