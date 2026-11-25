import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/domain/models/weather_location_state.dart';
import 'package:slnews_mobile/core/location/device_location_service.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';

import '../support/fakes.dart';

class _FakeDeviceLocationService implements DeviceLocationService {
  _FakeDeviceLocationService(this.result);

  DeviceLocationResult result;
  bool settingsOpened = false;
  int calls = 0;
  bool? lastRequestPermission;

  @override
  Future<DeviceLocationResult> current({bool requestPermission = true}) async {
    calls++;
    lastRequestPermission = requestPermission;
    return result;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened = true;
    return true;
  }
}

void main() {
  late InMemoryPreferencesStore store;
  late _FakeDeviceLocationService service;

  const NewsLocation london = NewsLocation(
    id: 'geo:51.51,-0.13',
    label: 'London',
    region: 'United Kingdom',
    latitude: 51.51,
    longitude: -0.13,
  );

  ProviderContainer build({DeviceLocationResult? result}) {
    store = InMemoryPreferencesStore();
    service = _FakeDeviceLocationService(
      result ??
          const DeviceLocationResult(
            status: DeviceLocationStatus.granted,
            location: london,
          ),
    );
    final ProviderContainer c = ProviderContainer(
      overrides: <Override>[
        preferencesStoreProvider.overrideWithValue(store),
        userStateProvider.overrideWithValue(FakeUserStateRepository()),
        deviceLocationServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('starts from the saved news location', () {
    final ProviderContainer c = build();
    final WeatherLocationState state = c.read(
      weatherLocationControllerProvider,
    );

    expect(state.location.id, 'city:freetown');
    expect(state.usingDevice, isFalse);
  });

  test('useCurrentLocation persists and exposes the device place', () async {
    final ProviderContainer c = build();
    final WeatherLocationController controller = c.read(
      weatherLocationControllerProvider.notifier,
    );

    final DeviceLocationStatus status = await controller.useCurrentLocation();

    expect(status, DeviceLocationStatus.granted);
    final WeatherLocationState state = c.read(
      weatherLocationControllerProvider,
    );
    expect(state.location.label, 'London');
    expect(state.location.latitude, 51.51);
    expect(state.usingDevice, isTrue);
    expect(
      store.string(WeatherLocationController.savedDeviceLocationKey),
      isNotNull,
    );
    expect(
      store.boolean(WeatherLocationController.useDeviceLocationKey),
      isTrue,
    );
  });

  test('a persisted device location restores without a new lookup', () async {
    final ProviderContainer first = build();
    await first
        .read(weatherLocationControllerProvider.notifier)
        .useCurrentLocation();

    final _FakeDeviceLocationService unused = _FakeDeviceLocationService(
      const DeviceLocationResult(status: DeviceLocationStatus.denied),
    );
    final ProviderContainer second = ProviderContainer(
      overrides: <Override>[
        preferencesStoreProvider.overrideWithValue(store),
        userStateProvider.overrideWithValue(FakeUserStateRepository()),
        deviceLocationServiceProvider.overrideWithValue(unused),
      ],
    );
    addTearDown(second.dispose);
    final WeatherLocationState state = second.read(
      weatherLocationControllerProvider,
    );

    expect(state.location.label, 'London');
    expect(state.usingDevice, isTrue);
  });

  test('denied permission leaves the saved location in place', () async {
    final ProviderContainer c = build(
      result: const DeviceLocationResult(status: DeviceLocationStatus.denied),
    );
    final WeatherLocationController controller = c.read(
      weatherLocationControllerProvider.notifier,
    );

    final DeviceLocationStatus status = await controller.useCurrentLocation();

    expect(status, DeviceLocationStatus.denied);
    final WeatherLocationState state = c.read(
      weatherLocationControllerProvider,
    );
    expect(state.location.id, 'city:freetown');
    expect(state.usingDevice, isFalse);
    expect(state.status, DeviceLocationStatus.denied);
    expect(
      store.boolean(WeatherLocationController.useDeviceLocationKey),
      isNull,
    );
  });

  test(
    'switching back restores the news location and clears the saved place',
    () async {
      final ProviderContainer c = build();
      final WeatherLocationController controller = c.read(
        weatherLocationControllerProvider.notifier,
      );
      await controller.useCurrentLocation();

      await controller.useNewsLocation();

      final WeatherLocationState state = c.read(
        weatherLocationControllerProvider,
      );
      expect(state.location.id, 'city:freetown');
      expect(state.usingDevice, isFalse);
      expect(
        store.boolean(WeatherLocationController.useDeviceLocationKey),
        isFalse,
      );
      expect(
        store.string(WeatherLocationController.savedDeviceLocationKey),
        isNull,
      );
    },
  );

  test(
    'an opted-in resume refresh updates the place without asking again',
    () async {
      final ProviderContainer c = build();
      final WeatherLocationController controller = c.read(
        weatherLocationControllerProvider.notifier,
      );
      await controller.useCurrentLocation();
      service.result = const DeviceLocationResult(
        status: DeviceLocationStatus.granted,
        location: NewsLocation(
          id: 'geo:48.86,2.35',
          label: 'Paris',
          region: 'France',
          latitude: 48.86,
          longitude: 2.35,
        ),
      );

      await controller.refreshDeviceLocation();

      final WeatherLocationState state = c.read(
        weatherLocationControllerProvider,
      );
      expect(state.location.label, 'Paris');
      expect(service.calls, 2);
      expect(service.lastRequestPermission, isFalse);
    },
  );

  test('a failed resume refresh keeps the saved place', () async {
    final ProviderContainer c = build();
    final WeatherLocationController controller = c.read(
      weatherLocationControllerProvider.notifier,
    );
    await controller.useCurrentLocation();
    service.result = const DeviceLocationResult(
      status: DeviceLocationStatus.unavailable,
    );

    await controller.refreshDeviceLocation();

    final WeatherLocationState state = c.read(
      weatherLocationControllerProvider,
    );
    expect(state.location.label, 'London');
    expect(state.usingDevice, isTrue);
    expect(state.busy, isFalse);
  });

  test(
    'an opt-out with a failed legacy clear still disables device weather',
    () async {
      final InMemoryPreferencesStore previous = store;
      final _PartialFailureStore failing = _PartialFailureStore(
        base: previous,
        failClear: true,
      );
      final ProviderContainer maybe = ProviderContainer(
        overrides: <Override>[
          preferencesStoreProvider.overrideWithValue(failing),
          userStateProvider.overrideWithValue(FakeUserStateRepository()),
          deviceLocationServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(maybe.dispose);
      final WeatherLocationController controller = maybe.read(
        weatherLocationControllerProvider.notifier,
      );
      await controller.useCurrentLocation();
      await controller.useNewsLocation();

      final ProviderContainer reopened = ProviderContainer(
        overrides: <Override>[
          preferencesStoreProvider.overrideWithValue(failing),
          userStateProvider.overrideWithValue(FakeUserStateRepository()),
          deviceLocationServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(reopened.dispose);
      expect(
        reopened.read(weatherLocationControllerProvider).usingDevice,
        isFalse,
      );
    },
  );

  test('an opt-out survives a failed state document and flag write', () async {
    final _PartialFailureStore failing = _PartialFailureStore(
      base: store,
      failAtomic: true,
      failFlag: true,
    );
    ProviderContainer buildWithStore() => ProviderContainer(
      overrides: <Override>[
        preferencesStoreProvider.overrideWithValue(failing),
        userStateProvider.overrideWithValue(FakeUserStateRepository()),
        deviceLocationServiceProvider.overrideWithValue(service),
      ],
    );
    final ProviderContainer c = buildWithStore();
    addTearDown(c.dispose);
    final WeatherLocationController controller = c.read(
      weatherLocationControllerProvider.notifier,
    );
    await controller.useCurrentLocation();
    await controller.useNewsLocation();

    final ProviderContainer reopened = buildWithStore();
    addTearDown(reopened.dispose);
    expect(
      reopened.read(weatherLocationControllerProvider).usingDevice,
      isFalse,
    );
  });

  test('openSettings is forwarded to the platform service', () async {
    final ProviderContainer c = build();
    final bool opened = await c
        .read(weatherLocationControllerProvider.notifier)
        .openSystemSettings();

    expect(opened, isTrue);
    expect(service.settingsOpened, isTrue);
  });
}

class _PartialFailureStore extends InMemoryPreferencesStore {
  _PartialFailureStore({
    required this.base,
    this.failClear = false,
    this.failAtomic = false,
    this.failFlag = false,
  });

  final InMemoryPreferencesStore base;
  final bool failClear;
  final bool failAtomic;
  final bool failFlag;

  @override
  String? string(String key) => base.string(key);

  @override
  bool? boolean(String key) => base.boolean(key);

  @override
  double? number(String key) => base.number(key);

  @override
  Set<String> stringSet(String key) => base.stringSet(key);

  @override
  Future<void> putString(String key, String value) =>
      base.putString(key, value);

  @override
  Future<void> putBool(String key, bool value) {
    if ((failClear || failFlag) &&
        key == WeatherLocationController.useDeviceLocationKey) {
      return Future<void>.error(StateError('bool write failed'));
    }
    return base.putBool(key, value);
  }

  @override
  Future<void> remove(String key) {
    if (failClear) return Future<void>.error(StateError('remove failed'));
    return base.remove(key);
  }

  @override
  Future<void> putStringSet(String key, Set<String> values) =>
      base.putStringSet(key, values);

  @override
  Future<void> putNumber(String key, double value) =>
      base.putNumber(key, value);

  @override
  Future<void> init() => base.init();
}
