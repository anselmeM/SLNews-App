import 'dart:async';

import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';

import '../domain/models/follow_models.dart';

/// Outcome of asking the platform for the reader's current location.
enum DeviceLocationStatus {
  granted,
  denied,
  deniedForever,
  servicesDisabled,
  unavailable,
}

/// Result of one device-location lookup.
///
/// A successful result carries a [NewsLocation] whose label is a city/place
/// name from the platform geocoder and whose coordinates are rounded to roughly
/// one kilometre before they leave this class.
class DeviceLocationResult {
  const DeviceLocationResult({this.location, required this.status});

  final NewsLocation? location;
  final DeviceLocationStatus status;

  bool get isGranted => location != null;
}

/// Platform location lookup seam.
abstract interface class DeviceLocationService {
  /// Returns the current place, requesting permission only when
  /// [requestPermission] is true.
  Future<DeviceLocationResult> current();

  /// Opens the platform app settings so a permanently denied permission can be
  /// changed.
  Future<bool> openSettings();
}

/// Platform operations behind [GeolocatorDeviceLocationService].
///
/// Split from the service so the permission/label logic can be tested without a
/// device or a plugin channel.
abstract interface class DeviceLocationProbe {
  Future<bool> serviceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position> currentPosition();
  Future<List<geocoding.Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude,
  );
  Future<bool> openSettings();
}

/// `geolocator` + platform geocoder implementation.
class GeolocatorDeviceLocationService implements DeviceLocationService {
  GeolocatorDeviceLocationService({DeviceLocationProbe? probe})
    : _probe = probe ?? _PlatformLocationProbe();

  /// Low accuracy is deliberate: the weather card only needs the nearest town.
  static const Duration timeout = Duration(seconds: 10);

  final DeviceLocationProbe _probe;

  @override
  Future<DeviceLocationResult> current() async {
    try {
      if (!await _probe.serviceEnabled()) {
        return const DeviceLocationResult(
          status: DeviceLocationStatus.servicesDisabled,
        );
      }

      LocationPermission permission = await _probe.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _probe.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const DeviceLocationResult(
          status: DeviceLocationStatus.deniedForever,
        );
      }
      if (permission == LocationPermission.denied) {
        return const DeviceLocationResult(status: DeviceLocationStatus.denied);
      }

      final Position position = await _probe.currentPosition();

      // Round before persistence/network: at two decimal places the forecast
      // request still resolves the right town but no longer carries a precise
      // GPS fix.
      final double latitude = _round(position.latitude);
      final double longitude = _round(position.longitude);
      final _PlaceLabel place = await _placeLabel(latitude, longitude);

      return DeviceLocationResult(
        status: DeviceLocationStatus.granted,
        location: NewsLocation(
          id:
              'geo:${latitude.toStringAsFixed(2)},'
              '${longitude.toStringAsFixed(2)}',
          label: place.label,
          region: place.region,
          latitude: latitude,
          longitude: longitude,
        ),
      );
    } on TimeoutException {
      return const DeviceLocationResult(
        status: DeviceLocationStatus.unavailable,
      );
    } on LocationServiceDisabledException {
      return const DeviceLocationResult(
        status: DeviceLocationStatus.servicesDisabled,
      );
    } catch (_) {
      return const DeviceLocationResult(
        status: DeviceLocationStatus.unavailable,
      );
    }
  }

  @override
  Future<bool> openSettings() async {
    try {
      return await _probe.openSettings();
    } catch (_) {
      return false;
    }
  }

  /// Exposed for tests of the coordinate privacy rounding.
  static double roundCoordinate(double value) => (value * 100).round() / 100;

  static double _round(double value) => roundCoordinate(value);

  Future<_PlaceLabel> _placeLabel(double lat, double lon) async {
    try {
      final List<geocoding.Placemark> marks = await _probe
          .placemarkFromCoordinates(lat, lon);
      if (marks.isEmpty) {
        return const _PlaceLabel(label: 'My location', region: '');
      }
      final geocoding.Placemark mark = marks.first;
      final String label = firstNonEmpty(<String?>[
        mark.locality,
        mark.subAdministrativeArea,
        mark.administrativeArea,
        mark.country,
        'My location',
      ]);
      final String region = firstNonEmpty(<String?>[
        mark.country,
        mark.administrativeArea,
        mark.subAdministrativeArea,
        '',
      ]);
      return _PlaceLabel(label: label, region: region);
    } catch (_) {
      // Geocoding may be offline or missing a platform service. The forecast
      // still works with coordinates; use a neutral label.
      return const _PlaceLabel(label: 'My location', region: '');
    }
  }

  /// Exposed for tests; first non-empty value wins.
  static String firstNonEmpty(List<String?> values) {
    for (final String? value in values) {
      final String trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }
}

class _PlatformLocationProbe implements DeviceLocationProbe {
  final geocoding.Geocoding _geocoding = geocoding.Geocoding();

  @override
  Future<bool> serviceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<Position> currentPosition() => Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.low,
      timeLimit: GeolocatorDeviceLocationService.timeout,
    ),
  );

  @override
  Future<List<geocoding.Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude,
  ) => _geocoding.placemarkFromCoordinates(latitude, longitude);

  @override
  Future<bool> openSettings() => Geolocator.openAppSettings();
}

class _PlaceLabel {
  const _PlaceLabel({required this.label, required this.region});

  final String label;
  final String region;
}
