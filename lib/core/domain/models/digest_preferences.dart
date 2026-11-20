import 'package:flutter/foundation.dart';

/// Reader-controlled delivery settings for the daily follow digest.
///
/// The server is the source of truth for sending, so every change is also
/// pushed there; this copy exists so Settings renders instantly and offline.
@immutable
class DigestPreferences {
  const DigestPreferences({
    this.digestEnabled = true,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.timezoneOffsetMinutes = 0,
  });

  /// False stops the daily digest entirely.
  final bool digestEnabled;

  /// Quiet window in minutes since local midnight; null when disabled.
  final int? quietHoursStart;
  final int? quietHoursEnd;

  /// The device's UTC offset when the preference was saved.
  final int timezoneOffsetMinutes;

  bool get hasQuietHours =>
      digestEnabled &&
      quietHoursStart != null &&
      quietHoursEnd != null &&
      quietHoursStart != quietHoursEnd;

  Map<String, dynamic> toServerJson() => <String, dynamic>{
    'digestCadence': digestEnabled ? 'daily' : 'off',
    'quietHoursStart': quietHoursStart,
    'quietHoursEnd': quietHoursEnd,
    'timezoneOffsetMinutes': timezoneOffsetMinutes,
  };

  /// `HH:MM` label for a minute-of-day, or null when unset.
  static String? clockLabel(int? minutes) {
    if (minutes == null || minutes < 0 || minutes >= 24 * 60) return null;
    final String hh = (minutes ~/ 60).toString().padLeft(2, '0');
    final String mm = (minutes % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  bool operator ==(Object other) =>
      other is DigestPreferences &&
      other.digestEnabled == digestEnabled &&
      other.quietHoursStart == quietHoursStart &&
      other.quietHoursEnd == quietHoursEnd &&
      other.timezoneOffsetMinutes == timezoneOffsetMinutes;

  @override
  int get hashCode => Object.hash(
    digestEnabled,
    quietHoursStart,
    quietHoursEnd,
    timezoneOffsetMinutes,
  );
}
