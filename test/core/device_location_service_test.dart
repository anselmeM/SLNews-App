import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:slnews_mobile/core/location/device_location_service.dart';

class _Probe implements DeviceLocationProbe {
  _Probe({
    this.servicesOn = true,
    this.permission = LocationPermission.whileInUse,
    this.requestedPermission = LocationPermission.whileInUse,
    this.position,
    this.positionError,
    this.placemarks = const <Placemark>[],
    this.geocodeError,
    this.settingsResult = true,
  });

  final bool servicesOn;
  final LocationPermission permission;
  final LocationPermission requestedPermission;
  final Position? position;
  final Object? positionError;
  final List<Placemark> placemarks;
  final Object? geocodeError;
  final bool settingsResult;

  @override
  Future<bool> serviceEnabled() async => servicesOn;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => requestedPermission;

  @override
  Future<Position> currentPosition() async {
    final Object? error = positionError;
    if (error != null) throw error;
    return position!;
  }

  @override
  Future<List<Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    final Object? error = geocodeError;
    if (error != null) throw error;
    return placemarks;
  }

  @override
  Future<bool> openSettings() async => settingsResult;
}

final Position _londonPosition = Position(
  latitude: 51.50736,
  longitude: -0.12764,
  timestamp: DateTime.utc(2026, 11, 24),
  accuracy: 100,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

const Placemark _london = Placemark(
  locality: 'London',
  administrativeArea: 'England',
  country: 'United Kingdom',
);

void main() {
  test('reports disabled location services', () async {
    final service = GeolocatorDeviceLocationService(
      probe: _Probe(servicesOn: false),
    );

    final result = await service.current();

    expect(result.status, DeviceLocationStatus.servicesDisabled);
    expect(result.location, isNull);
  });

  test('reports a permanently denied permission', () async {
    final service = GeolocatorDeviceLocationService(
      probe: _Probe(permission: LocationPermission.deniedForever),
    );

    expect(
      (await service.current()).status,
      DeviceLocationStatus.deniedForever,
    );
  });

  test('asks once and reports a normal denial', () async {
    final service = GeolocatorDeviceLocationService(
      probe: _Probe(
        permission: LocationPermission.denied,
        requestedPermission: LocationPermission.denied,
      ),
    );

    expect((await service.current()).status, DeviceLocationStatus.denied);
  });

  test('maps a granted position to a rounded, labelled place', () async {
    final service = GeolocatorDeviceLocationService(
      probe: _Probe(
        position: _londonPosition,
        placemarks: const <Placemark>[_london],
      ),
    );

    final result = await service.current();

    expect(result.status, DeviceLocationStatus.granted);
    expect(result.location!.id, 'geo:51.51,-0.13');
    expect(result.location!.label, 'London');
    expect(result.location!.region, 'United Kingdom');
    expect(result.location!.latitude, 51.51);
    expect(result.location!.longitude, -0.13);
  });

  test(
    'falls back to a neutral label when reverse geocoding is empty',
    () async {
      final service = GeolocatorDeviceLocationService(
        probe: _Probe(position: _londonPosition),
      );

      final result = await service.current();

      expect(result.location!.label, 'My location');
      expect(result.location!.region, isEmpty);
    },
  );

  test('still returns a forecast-ready place when geocoding fails', () async {
    final service = GeolocatorDeviceLocationService(
      probe: _Probe(
        position: _londonPosition,
        geocodeError: StateError('geocoder offline'),
      ),
    );

    final result = await service.current();

    expect(result.status, DeviceLocationStatus.granted);
    expect(result.location!.label, 'My location');
  });

  test('reports a timeout as unavailable', () async {
    final service = GeolocatorDeviceLocationService(
      probe: _Probe(positionError: TimeoutException('slow fix')),
    );

    expect((await service.current()).status, DeviceLocationStatus.unavailable);
  });

  test('reports disabled services thrown during a fix', () async {
    final service = GeolocatorDeviceLocationService(
      probe: _Probe(positionError: const LocationServiceDisabledException()),
    );

    expect(
      (await service.current()).status,
      DeviceLocationStatus.servicesDisabled,
    );
  });

  test('reports unexpected platform errors as unavailable', () async {
    final service = GeolocatorDeviceLocationService(
      probe: _Probe(positionError: StateError('platform')),
    );

    expect((await service.current()).status, DeviceLocationStatus.unavailable);
  });

  test('opens settings through the probe', () async {
    final service = GeolocatorDeviceLocationService(
      probe: _Probe(settingsResult: true),
    );

    expect(await service.openSettings(), isTrue);
  });

  test('rounds coordinates to two decimals', () {
    expect(GeolocatorDeviceLocationService.roundCoordinate(51.50736), 51.51);
    expect(GeolocatorDeviceLocationService.roundCoordinate(-0.12764), -0.13);
  });

  test('uses the first non-empty label part', () {
    expect(
      GeolocatorDeviceLocationService.firstNonEmpty(<String?>[
        null,
        '  ',
        'London',
        'England',
      ]),
      'London',
    );
    expect(
      GeolocatorDeviceLocationService.firstNonEmpty(<String?>[null, ' ']),
      isEmpty,
    );
  });
}
