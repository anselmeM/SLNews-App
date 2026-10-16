import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/models/ad_unit.dart';
import '../../domain/models/article.dart';
import '../../domain/models/follow_models.dart';
import '../../domain/models/notification_item.dart';
import '../../domain/models/sports_models.dart';
import '../../domain/models/weather_snapshot.dart';
import 'seed_data.dart';

/// Source of the bundled offline content.
abstract interface class SeedLoader {
  /// Resolves the bundle. Implementations never throw: a missing or malformed
  /// asset degrades to whatever could be parsed.
  Future<SeedData> load();
}

/// Reads the JSON files under `assets/seed/`.
///
/// Timestamps may be shipped either absolutely (`publishedAt`) or as an age in
/// minutes (`publishedMinutesAgo`, `receivedMinutesAgo`, `startsInMinutes`), so
/// the demo feed always reads "3 hours ago" instead of drifting stale.
class AssetSeedLoader implements SeedLoader {
  /// Creates a loader; [bundle] defaults to [rootBundle] at call time so tests
  /// can inject a fixture bundle.
  const AssetSeedLoader({AssetBundle? bundle}) : _assets = bundle;

  /// Asset path constants, also used by the seed test.
  static const String articlesAsset = 'assets/seed/articles.json';
  static const String sportsAsset = 'assets/seed/sports.json';
  static const String followablesAsset = 'assets/seed/followables.json';
  static const String notificationsAsset = 'assets/seed/notifications.json';
  static const String adsAsset = 'assets/seed/ads.json';
  static const String weatherAsset = 'assets/seed/weather.json';

  final AssetBundle? _assets;

  /// Parsed bundle, shared across instances because the assets are immutable in
  /// a running app. Only successful parses with content are cached, so a failed
  /// or empty read cannot poison a later load.
  static SeedData? _cache;

  @override
  Future<SeedData> load() async {
    final SeedData? cached = _cache;
    if (cached != null) return cached;

    final AssetBundle bundle = _assets ?? rootBundle;
    final DateTime now = DateTime.now();

    final List<Article> articles = <Article>[];
    for (final Map<String, dynamic> json in _objects(
      await _readJson(bundle, articlesAsset),
    )) {
      try {
        articles.add(_article(json, now));
      } catch (error) {
        debugPrint('AssetSeedLoader: skipping article ${json['id']}: $error');
      }
    }

    final Map<String, dynamic> sports = _map(
      await _readJson(bundle, sportsAsset),
    );
    final List<FollowTarget> followables = _mapped(
      await _readJson(bundle, followablesAsset),
      FollowTarget.fromJson,
    );
    final List<NotificationItem> notifications = <NotificationItem>[];
    for (final Map<String, dynamic> json in _objects(
      await _readJson(bundle, notificationsAsset),
    )) {
      try {
        notifications.add(_notification(json, now));
      } catch (error) {
        debugPrint(
          'AssetSeedLoader: skipping notification ${json['id']}: $error',
        );
      }
    }
    final List<AdUnit> ads = _mapped(
      await _readJson(bundle, adsAsset),
      AdUnit.fromJson,
    );
    final Map<String, WeatherSnapshot> weather = _weather(
      await _readJson(bundle, weatherAsset),
      now,
    );
    final List<TeamStanding> standings = <TeamStanding>[];
    for (final Map<String, dynamic> json in _objects(sports['standings'])) {
      try {
        standings.add(TeamStanding.fromJson(json));
      } catch (error) {
        debugPrint('AssetSeedLoader: skipping standing: $error');
      }
    }

    final SeedData data = SeedData(
      articles: articles,
      scoreboard: _scoreboard(sports, now),
      followables: followables,
      locations: SlLocations.all,
      notifications: notifications,
      ads: ads,
      weather: weather,
      standings: standings,
    );
    if (articles.isNotEmpty) _cache = data;
    return data;
  }

  static Article _article(Map<String, dynamic> json, DateTime now) {
    final Map<String, dynamic> normalised = Map<String, dynamic>.of(json);
    if (normalised['publishedAt'] == null) {
      final int minutesAgo = _int(normalised['publishedMinutesAgo']) ?? 0;
      normalised['publishedAt'] = now
          .subtract(Duration(minutes: minutesAgo))
          .toIso8601String();
    }
    return Article.fromJson(normalised);
  }

  static NotificationItem _notification(
    Map<String, dynamic> json,
    DateTime now,
  ) {
    final Map<String, dynamic> normalised = Map<String, dynamic>.of(json);
    if (normalised['receivedAt'] == null) {
      final int minutesAgo = _int(normalised['receivedMinutesAgo']) ?? 0;
      normalised['receivedAt'] = now
          .subtract(Duration(minutes: minutesAgo))
          .toIso8601String();
    }
    return NotificationItem.fromJson(normalised);
  }

  static ScoreboardSnapshot _scoreboard(
    Map<String, dynamic> sports,
    DateTime now,
  ) {
    final List<GameScore> games = <GameScore>[];
    for (final Map<String, dynamic> json in _objects(sports['games'])) {
      final Map<String, dynamic> normalised = Map<String, dynamic>.of(json);
      if (normalised['startsAt'] == null) {
        final int? startsInMinutes = _int(normalised['startsInMinutes']);
        if (startsInMinutes != null) {
          normalised['startsAt'] = now
              .add(Duration(minutes: startsInMinutes))
              .toIso8601String();
        }
      }
      try {
        games.add(GameScore.fromJson(normalised));
      } catch (error) {
        debugPrint(
          'AssetSeedLoader: skipping game ${normalised['id']}: $error',
        );
      }
    }

    DateTime updatedAt = now;
    final Object? stamped = sports['updatedAt'];
    if (stamped is String) {
      updatedAt = DateTime.tryParse(stamped) ?? now;
    } else {
      final int? minutesAgo = _int(sports['updatedMinutesAgo']);
      if (minutesAgo != null) {
        updatedAt = now.subtract(Duration(minutes: minutesAgo));
      }
    }

    return ScoreboardSnapshot(
      games: games,
      providerLabel: sports['providerLabel'] as String? ?? 'slnews',
      updatedAt: updatedAt,
    );
  }

  static Map<String, WeatherSnapshot> _weather(Object? decoded, DateTime now) {
    if (decoded is! Map) return const <String, WeatherSnapshot>{};
    final Map<String, WeatherSnapshot> snapshots = <String, WeatherSnapshot>{};
    decoded.forEach((Object? key, Object? value) {
      if (key is! String || value is! Map) return;
      final Map<String, dynamic> json = _map(value);
      if (json['updatedAt'] == null) {
        final int minutesAgo = _int(json['updatedMinutesAgo']) ?? 0;
        json['updatedAt'] = now
            .subtract(Duration(minutes: minutesAgo))
            .toIso8601String();
      }
      try {
        snapshots[key] = WeatherSnapshot.fromJson(json);
      } catch (error) {
        debugPrint('AssetSeedLoader: skipping weather for $key: $error');
      }
    });
    return snapshots;
  }

  static List<T> _mapped<T>(
    Object? decoded,
    T Function(Map<String, dynamic>) build,
  ) {
    final List<T> result = <T>[];
    for (final Map<String, dynamic> json in _objects(decoded)) {
      try {
        result.add(build(json));
      } catch (error) {
        debugPrint('AssetSeedLoader: skipping entry: $error');
      }
    }
    return result;
  }

  static Future<Object?> _readJson(AssetBundle bundle, String path) async {
    try {
      final String raw = await bundle.loadString(path);
      if (raw.trim().isEmpty) return null;
      return jsonDecode(raw);
    } catch (error) {
      debugPrint('AssetSeedLoader: could not read $path: $error');
      return null;
    }
  }

  /// Accepts a bare array or an envelope holding one under a known key.
  static List<Map<String, dynamic>> _objects(Object? decoded) {
    Object? list = decoded;
    if (decoded is Map) {
      for (final String key in const <String>[
        'items',
        'articles',
        'data',
        'results',
      ]) {
        final Object? candidate = decoded[key];
        if (candidate is List) {
          list = candidate;
          break;
        }
      }
    }
    if (list is! List) return const <Map<String, dynamic>>[];
    return <Map<String, dynamic>>[
      for (final Object? entry in list)
        if (entry is Map) _map(entry),
    ];
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map) return <String, dynamic>{};
    final Map<String, dynamic> mapped = <String, dynamic>{};
    value.forEach((Object? key, Object? entry) {
      if (key is String) mapped[key] = entry;
    });
    return mapped;
  }

  static int? _int(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}

/// Loader over an in-memory bundle, used by tests and previews.
class InMemorySeedLoader implements SeedLoader {
  /// Wraps [data] as a loader.
  const InMemorySeedLoader(this.data);

  /// Bundle returned by [load].
  final SeedData data;

  @override
  Future<SeedData> load() async => data;
}
