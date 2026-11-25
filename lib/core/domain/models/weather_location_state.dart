import 'package:flutter/foundation.dart';

import 'follow_models.dart';
import '../../location/device_location_service.dart';

/// Reader-visible weather location state.
///
/// This is intentionally separate from the news-location setting: the news feed
/// stays Sierra Leone-first, while the weather card can follow the device.
@immutable
class WeatherLocationState {
  const WeatherLocationState({
    required this.location,
    this.usingDevice = false,
    this.busy = false,
    this.status,
  });

  final NewsLocation location;
  final bool usingDevice;
  final bool busy;
  final DeviceLocationStatus? status;

  WeatherLocationState copyWith({
    NewsLocation? location,
    bool? usingDevice,
    bool? busy,
    DeviceLocationStatus? status,
    bool clearStatus = false,
  }) {
    return WeatherLocationState(
      location: location ?? this.location,
      usingDevice: usingDevice ?? this.usingDevice,
      busy: busy ?? this.busy,
      status: clearStatus ? null : status ?? this.status,
    );
  }
}
