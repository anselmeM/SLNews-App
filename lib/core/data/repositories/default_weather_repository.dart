import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/follow_models.dart';
import '../../domain/models/weather_snapshot.dart';
import '../../domain/repositories/weather_repository.dart';
import '../seed/seed_data.dart';
import '../seed/seed_loader.dart';
import '../sources/api_client.dart';

/// Current conditions for the active location.
///
/// Resolution order is remote (when an endpoint is configured) → seeded
/// snapshot → [WeatherSnapshot.placeholder], so the header chip never shows a
/// spinner or an error.
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
    final WeatherSnapshot? live = await _fetch(location);
    if (live != null) return live;
    return _weather[location.id] ?? WeatherSnapshot.placeholder(location.label);
  }

  Future<void> _hydrate() async {
    try {
      final SeedData seed = await _seeds.load();
      _weather = seed.weather;
    } catch (error) {
      debugPrint('DefaultWeatherRepository: seed unavailable: $error');
    }
  }

  Future<WeatherSnapshot?> _fetch(NewsLocation location) async {
    final ApiClient? client = _api;
    final String? template = _template;
    if (client == null || template == null || template.isEmpty) return null;

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
      return WeatherSnapshot.fromJson(json);
    } catch (error) {
      debugPrint('DefaultWeatherRepository: live weather unavailable: $error');
      return null;
    }
  }
}
