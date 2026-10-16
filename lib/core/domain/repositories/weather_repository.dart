import '../models/weather_snapshot.dart';
import '../models/follow_models.dart';

/// Current conditions for the active location.
abstract interface class WeatherRepository {
  /// Always resolves; falls back to a bundled snapshot when offline.
  Future<WeatherSnapshot> current(NewsLocation location);
}
