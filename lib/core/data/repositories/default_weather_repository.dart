import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/follow_models.dart';
import '../../domain/models/weather_snapshot.dart';
import '../../domain/repositories/weather_repository.dart';
import '../seed/seed_data.dart';
import '../seed/seed_loader.dart';
import '../sources/api_client.dart';

import 'package:slnews_mobile/core/utils/app_log.dart';

/// Current conditions for the active location.
///
/// Resolution order is remote (when an endpoint is configured) → seeded
/// snapshot → an explicit unavailable state. The repository never invents a
/// forecast for an unknown place.
class DefaultWeatherRepository implements WeatherRepository {
  /// Creates a repository over [seedLoader].
  ///
  /// [endpointTemplate] may contain `{id}`, `{label}`, `{lat}` and `{lon}`
  /// placeholders; without it the repository is seed-only.
  DefaultWeatherRepository({
    required SeedLoader seedLoader,
    ApiClient? client,
    String? endpointTemplate,
  }) : _seeds = seedLoader,
       _api = client,
       _template = endpointTemplate {
    unawaited(_ready);
  }

  final SeedLoader _seeds;
  final ApiClient? _api;
  final String? _template;

  Map<String, WeatherSnapshot> _weather = const <String, WeatherSnapshot>{};

  late final Future<void> _ready = _hydrate();

  /// Resolves once the seeded snapshots are loaded.
  Future<void> ready() => _ready;

  @override
  Future<WeatherSnapshot> current(NewsLocation location) async {
    await _ready;
    // A coordinate endpoint cannot forecast an unknown point. Fetching with
    // substituted 0,0 would present the Gulf of Guinea as the place's weather.
    final bool hasCoordinates =
        location.latitude != null && location.longitude != null;
    final WeatherSnapshot? live = hasCoordinates
        ? await _fetch(location)
        : null;
    if (live != null) return live;
    final WeatherSnapshot? seeded = _weather[location.id];
    if (seeded != null) {
      return seeded.copyWith(locationId: location.id);
    }
    return WeatherSnapshot.unavailable(location.label, locationId: location.id);
  }

  Future<void> _hydrate() async {
    try {
      final SeedData seed = await _seeds.load();
      _weather = seed.weather;
    } catch (error) {
      AppLog.debug('DefaultWeatherRepository: seed unavailable: $error');
    }
  }

  /// Maps an Open-Meteo `current` block to the app's snapshot vocabulary.
  ///
  /// WMO weather codes are grouped into the glyph set the header understands
  /// (`sun`, `cloud`, `rain`, `storm`, `snow`) so the chip renders anywhere.
  @visibleForTesting
  static WeatherSnapshot? mapOpenMeteo(
    Map<String, dynamic> current,
    NewsLocation location,
  ) {
    final Object? temp = current['temperature_2m'];
    if (temp is! num) return null;
    final int? code = (current['weather_code'] as num?)?.toInt();
    final (String label, String glyph) = describeWeatherCode(code);
    final int? humidity = (current['relative_humidity_2m'] as num?)?.toInt();
    return WeatherSnapshot(
      locationLabel: location.label,
      locationId: location.id,
      temperatureC: temp.round(),
      conditionLabel: label,
      glyph: glyph,
      humidityPercent: humidity,
      updatedAt: DateTime.now(),
    );
  }

  /// Condition label and glyph for a WMO weather code.
  @visibleForTesting
  static (String, String) describeWeatherCode(int? code) {
    final int? c = code;
    if (c == null) return ('Cloudy', 'cloud');
    return switch (c) {
      0 || 1 => ('Sunny', 'sun'),
      2 || 3 => ('Partly cloudy', 'cloud'),
      45 || 48 => ('Fog', 'cloud'),
      >= 51 && <= 67 => ('Rain', 'rain'),
      >= 71 && <= 77 => ('Snow', 'snow'),
      >= 80 && <= 82 => ('Showers', 'rain'),
      >= 85 && <= 86 => ('Snow showers', 'snow'),
      >= 95 => ('Thundery showers', 'storm'),
      _ => ('Cloudy', 'cloud'),
    };
  }

  Future<WeatherSnapshot?> _fetch(NewsLocation location) async {
    final ApiClient? client = _api;
    final String? template = _template;
    if (client == null || template == null || template.isEmpty) return null;
    if (location.latitude == null || location.longitude == null) return null;

    final String url = template
        .replaceAll('{id}', Uri.encodeQueryComponent(location.id))
        .replaceAll('{label}', Uri.encodeQueryComponent(location.label))
        .replaceAll('{lat}', (location.latitude ?? 0).toString())
        .replaceAll('{lon}', (location.longitude ?? 0).toString());

    try {
      final Object? payload = await client.getJson(url);
      final Object? node = payload is Map
          ? payload['current'] ?? payload['data'] ?? payload
          : payload;
      if (node is! Map) return null;
      // Open-Meteo's shape is recognised by its weather code.
      if (node['weather_code'] != null) {
        final Map<String, dynamic> current = <String, dynamic>{};
        node.forEach((Object? key, Object? value) {
          if (key is String) current[key] = value;
        });
        final WeatherSnapshot? live = mapOpenMeteo(current, location);
        if (live != null) return live;
      }

      final Map<String, dynamic> json = <String, dynamic>{};
      node.forEach((Object? key, Object? value) {
        if (key is String) json[key] = value;
      });
      json['locationLabel'] = json['locationLabel'] ?? location.label;
      json['conditionLabel'] =
          json['conditionLabel'] ??
          json['condition'] ??
          json['summary'] ??
          'Unknown';
      json['updatedAt'] = json['updatedAt'] ?? DateTime.now().toIso8601String();
      final WeatherSnapshot parsed = WeatherSnapshot.fromJson(json);
      return parsed.locationId == null
          ? parsed.copyWith(locationId: location.id)
          : parsed;
    } catch (error) {
      AppLog.debug(
        'DefaultWeatherRepository: live weather unavailable: $error',
      );
      return null;
    }
  }
}
