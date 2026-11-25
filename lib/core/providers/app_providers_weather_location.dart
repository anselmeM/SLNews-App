part of 'app_providers.dart';

class WeatherLocationController extends Notifier<WeatherLocationState> {
  static const String useDeviceLocationKey = 'weather.useDeviceLocation';
  static const String savedDeviceLocationKey = 'weather.deviceLocation';

  /// Authoritative consent + place document. Legacy keys above are read only
  /// when no authoritative document exists, so a stale legacy `false` cannot
  /// erase a newer successful opt-in.
  static const String deviceStateKey = 'weather.deviceState.v1';

  /// Latest explicit opt-out timestamps. Two independent channels make a
  /// failed state/legacy write fail closed instead of restoring stale consent.
  static const String deviceOptOutKey = 'weather.deviceOptOutAt.v1';
  static const String deviceOptOutEpochKey = 'weather.deviceOptOutEpoch.v1';

  /// Whole platform lookup bound, including service/permission probes.
  static Duration lookupTimeout = const Duration(seconds: 15);

  /// Avoid hammering the location/forecast services on frequent foregrounding.
  static const Duration autoRefreshCooldown = Duration(minutes: 5);

  Future<void> _persistBarrier = Future<void>.value();
  int _epoch = 0;
  DateTime? _lastAutoRefreshAt;

  @override
  WeatherLocationState build() {
    final String selectedId = ref.watch(userStateProvider).activeLocationId;
    final NewsLocation fallback = _fallbackFor(selectedId);
    final PreferencesStore? store = _preferencesOrNull();
    final _PersistedWeather persisted = _readPersisted(store);
    if (!persisted.enabled) {
      return WeatherLocationState(location: fallback);
    }
    final NewsLocation? saved = persisted.location;
    if (saved != null) {
      return WeatherLocationState(location: saved, usingDevice: true);
    }
    return WeatherLocationState(location: fallback);
  }

  _PersistedWeather _readPersisted(PreferencesStore? store) {
    if (store == null) return const _PersistedWeather.disabled();

    final _DeviceState? state = _readDeviceState(store);
    final DateTime? optOutAt = _readOptOutAt(store);

    if (state != null) {
      // An explicit opt-out that is newer than the state document wins. A
      // stale legacy flag never overrides a successfully written document.
      if (optOutAt != null && optOutAt.isAfter(state.savedAt)) {
        return const _PersistedWeather.disabled();
      }
      if (!state.enabled) return const _PersistedWeather.disabled();
      return _PersistedWeather(
        enabled: true,
        location: state.location ?? _readLegacyLocation(store),
      );
    }

    if (optOutAt != null) return const _PersistedWeather.disabled();

    // Migration path for installs that predate the state document.
    final bool? legacyEnabled = store.boolean(useDeviceLocationKey);
    if (legacyEnabled != true) return const _PersistedWeather.disabled();
    return _PersistedWeather(
      enabled: true,
      location: _readLegacyLocation(store),
    );
  }

  _DeviceState? _readDeviceState(PreferencesStore store) {
    final String? raw = store.string(deviceStateKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final Map<String, dynamic> json = Map<String, dynamic>.from(decoded);
      final Object? enabled = json['enabled'];
      if (enabled is! bool) return null;
      final DateTime savedAt =
          DateTime.tryParse(json['savedAt'] as String? ?? '') ??
          DateTime.utc(2020);
      NewsLocation? location;
      final Object? rawLocation = json['location'];
      if (rawLocation is Map) {
        final NewsLocation parsed = NewsLocation.fromJson(
          Map<String, dynamic>.from(rawLocation),
        );
        if (parsed.latitude != null && parsed.longitude != null) {
          location = parsed;
        }
      }
      return _DeviceState(
        enabled: enabled,
        location: location,
        savedAt: savedAt,
      );
    } catch (error) {
      AppLog.debug('WeatherLocation: unreadable device state: $error');
      return null;
    }
  }

  DateTime? _readOptOutAt(PreferencesStore store) {
    DateTime? latest;
    final String? raw = store.string(deviceOptOutKey);
    if (raw != null && raw.isNotEmpty) {
      latest = DateTime.tryParse(raw);
    }
    final double? epoch = store.number(deviceOptOutEpochKey);
    if (epoch != null && epoch > 0) {
      final DateTime fromEpoch = DateTime.fromMicrosecondsSinceEpoch(
        epoch.round(),
        isUtc: true,
      );
      if (latest == null || fromEpoch.isAfter(latest)) latest = fromEpoch;
    }
    return latest;
  }

  NewsLocation? _readLegacyLocation(PreferencesStore store) {
    final String? raw = store.string(savedDeviceLocationKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) {
        final NewsLocation parsed = NewsLocation.fromJson(
          Map<String, dynamic>.from(decoded),
        );
        if (parsed.latitude != null && parsed.longitude != null) return parsed;
      }
    } catch (error) {
      AppLog.debug('WeatherLocation: unreadable saved location: $error');
    }
    return null;
  }

  /// Requests the platform location, persists the resolved place, and updates
  /// the weather card. Returns the platform status so the sheet can offer
  /// "Open settings" when permission is permanently denied.
  Future<DeviceLocationStatus> useCurrentLocation() async {
    if (state.busy) {
      return state.status ?? DeviceLocationStatus.unavailable;
    }
    final int epoch = ++_epoch;
    _lastAutoRefreshAt = null;
    state = state.copyWith(busy: true, clearStatus: true);

    DeviceLocationResult result;
    try {
      result = await ref
          .read(deviceLocationServiceProvider)
          .current()
          .timeout(lookupTimeout);
    } catch (error) {
      AppLog.debug('WeatherLocation: current lookup failed: $error');
      if (epoch == _epoch) {
        state = state.copyWith(
          busy: false,
          status: DeviceLocationStatus.unavailable,
        );
      }
      return DeviceLocationStatus.unavailable;
    }

    if (epoch != _epoch) return DeviceLocationStatus.unavailable;
    final NewsLocation? location = result.location;
    if (location == null) {
      state = state.copyWith(busy: false, status: result.status);
      return result.status;
    }

    await _persistDeviceState(enabled: true, location: location);
    if (epoch != _epoch) return DeviceLocationStatus.unavailable;
    state = WeatherLocationState(location: location, usingDevice: true);
    return DeviceLocationStatus.granted;
  }

  /// Switches back to the saved news location and clears the device location.
  ///
  /// The state document, opt-out timestamp, and legacy keys are written
  /// independently so one failed write cannot silently restore sharing.
  Future<void> useNewsLocation() async {
    _epoch++;
    _lastAutoRefreshAt = null;
    final String selectedId = ref.read(userStateProvider).activeLocationId;
    state = WeatherLocationState(location: _fallbackFor(selectedId));
    await _persistDeviceState(enabled: false);
  }

  /// Refreshes the opted-in device place when the app returns to the
  /// foreground. Returns true only when a new place was applied.
  Future<bool> refreshDeviceLocation() async {
    if (!state.usingDevice || state.busy) return false;
    final DateTime now = DateTime.now();
    final DateTime? last = _lastAutoRefreshAt;
    if (last != null && now.difference(last) < autoRefreshCooldown) {
      return false;
    }
    _lastAutoRefreshAt = now;
    final int epoch = ++_epoch;
    state = state.copyWith(busy: true, clearStatus: true);

    try {
      final DeviceLocationResult result = await ref
          .read(deviceLocationServiceProvider)
          .current(requestPermission: false)
          .timeout(lookupTimeout);
      if (epoch != _epoch || !state.usingDevice) return false;
      final NewsLocation? location = result.location;
      if (location == null) {
        state = state.copyWith(busy: false);
        return false;
      }
      await _persistDeviceState(enabled: true, location: location);
      // The reader may have opted out while persistence was in flight.
      if (epoch != _epoch || !state.usingDevice) return false;
      state = WeatherLocationState(location: location, usingDevice: true);
      return true;
    } catch (error) {
      AppLog.debug('WeatherLocation: resume refresh failed: $error');
      if (epoch == _epoch) state = state.copyWith(busy: false);
      return false;
    }
  }

  Future<void> _persistDeviceState({
    required bool enabled,
    NewsLocation? location,
  }) {
    // Serialize persistence so an opt-out cannot be overwritten by an earlier
    // in-flight opt-in write.
    final Future<void> write = _persistBarrier.then(
      (_) => _writeDeviceState(enabled: enabled, location: location),
    );
    _persistBarrier = write.catchError((Object _) {});
    return write;
  }

  Future<void> _writeDeviceState({
    required bool enabled,
    NewsLocation? location,
  }) async {
    final PreferencesStore? store = _preferencesOrNull();
    if (store == null) return;
    final DateTime now = DateTime.now().toUtc();
    final String stamp = now.toIso8601String();

    if (enabled && location != null) {
      // The new state document carries a newer timestamp than any stale
      // opt-out tombstone, so a successful opt-in wins.
      for (final String key in <String>[
        deviceOptOutKey,
        deviceOptOutEpochKey,
      ]) {
        try {
          await store.remove(key);
        } catch (error) {
          AppLog.debug('WeatherLocation: could not clear opt-out: $error');
        }
      }
      final String document = jsonEncode(<String, dynamic>{
        'enabled': true,
        'location': location.toJson(),
        'savedAt': stamp,
      });
      bool written = false;
      try {
        await store.putString(deviceStateKey, document);
        written = true;
      } catch (error) {
        AppLog.debug('WeatherLocation: could not write device state: $error');
      }
      if (!written) {
        try {
          await store.remove(deviceStateKey);
        } catch (error) {
          AppLog.debug('WeatherLocation: could not clear device state: $error');
        }
      }
      try {
        await store.putString(
          savedDeviceLocationKey,
          jsonEncode(location.toJson()),
        );
      } catch (error) {
        AppLog.debug('WeatherLocation: could not save place: $error');
      }
      try {
        await store.putBool(useDeviceLocationKey, true);
      } catch (error) {
        AppLog.debug('WeatherLocation: could not save opt-in: $error');
      }
      return;
    }

    // Opt-out: the tombstone is written first so a failed state/legacy write
    // cannot restore sharing on the next launch.
    bool tombstoneWritten = false;
    try {
      await store.putString(deviceOptOutKey, stamp);
      tombstoneWritten = true;
    } catch (error) {
      AppLog.debug('WeatherLocation: could not write opt-out: $error');
    }
    try {
      await store.putNumber(
        deviceOptOutEpochKey,
        now.microsecondsSinceEpoch.toDouble(),
      );
      tombstoneWritten = true;
    } catch (error) {
      AppLog.debug('WeatherLocation: could not write opt-out epoch: $error');
    }
    bool stateWritten = false;
    try {
      await store.putString(
        deviceStateKey,
        jsonEncode(<String, dynamic>{
          'enabled': false,
          'location': null,
          'savedAt': stamp,
        }),
      );
      stateWritten = true;
    } catch (error) {
      AppLog.debug('WeatherLocation: could not write disabled state: $error');
    }
    if (!stateWritten) {
      try {
        await store.remove(deviceStateKey);
      } catch (error) {
        AppLog.debug('WeatherLocation: could not clear device state: $error');
      }
    }
    if (!tombstoneWritten && !stateWritten) {
      AppLog.debug(
        'WeatherLocation: opt-out could not be persisted; keeping the '
        'session-only opt-out',
      );
    }
    try {
      await store.putBool(useDeviceLocationKey, false);
    } catch (error) {
      AppLog.debug('WeatherLocation: could not clear opt-in: $error');
    }
    try {
      await store.remove(savedDeviceLocationKey);
    } catch (error) {
      AppLog.debug('WeatherLocation: could not clear saved place: $error');
    }
  }

  Future<bool> openSystemSettings() =>
      ref.read(deviceLocationServiceProvider).openSettings();

  /// Widget tests sometimes mount the weather card without the full app
  /// bootstrap. The location feature degrades to session-only when there is no
  /// preferences store instead of failing the whole card.
  PreferencesStore? _preferencesOrNull() {
    try {
      return ref.read(preferencesStoreProvider);
    } catch (_) {
      return null;
    }
  }

  static NewsLocation _fallbackFor(String locationId) {
    return SlLocations.all.firstWhere(
      (NewsLocation candidate) => candidate.id == locationId,
      orElse: () => SlLocations.fallback,
    );
  }
}

class _PersistedWeather {
  const _PersistedWeather({required this.enabled, required this.location});

  const _PersistedWeather.disabled() : enabled = false, location = null;

  final bool enabled;
  final NewsLocation? location;
}

class _DeviceState {
  const _DeviceState({
    required this.enabled,
    required this.location,
    required this.savedAt,
  });

  final bool enabled;
  final NewsLocation? location;
  final DateTime savedAt;
}
