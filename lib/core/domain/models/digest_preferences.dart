import 'package:flutter/foundation.dart';

/// Reader-controlled delivery settings for the daily follow digest.
///
/// These choices are deliberately device-local and are never sent to an SLNews
/// account or server; signing in only syncs saved stories, likes and follows.
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

  /// Local document field names.
  static const String enabledField = 'digestEnabled';
  static const String quietHoursStartField = 'quietHoursStart';
  static const String quietHoursEndField = 'quietHoursEnd';
  static const String timezoneOffsetField = 'timezoneOffsetMinutes';

  /// Device-local document payload.
  Map<String, dynamic> toJson() => <String, dynamic>{
    enabledField: digestEnabled,
    quietHoursStartField: quietHoursStart,
    quietHoursEndField: quietHoursEnd,
    timezoneOffsetField: timezoneOffsetMinutes,
  };

  /// Tolerant local-cache decoder: corrupt values fall back to defaults.
  factory DigestPreferences.fromJson(Map<String, dynamic> json) {
    final Object? enabled = json[enabledField];
    final Object? start = json[quietHoursStartField];
    final Object? end = json[quietHoursEndField];
    final Object? offset = json[timezoneOffsetField];
    return DigestPreferences(
      digestEnabled: enabled is bool ? enabled : true,
      quietHoursStart: start is num ? start.toInt() : null,
      quietHoursEnd: end is num ? end.toInt() : null,
      timezoneOffsetMinutes: offset is num ? offset.toInt() : 0,
    );
  }

  bool get hasQuietHours =>
      digestEnabled &&
      quietHoursStart != null &&
      quietHoursEnd != null &&
      quietHoursStart != quietHoursEnd;

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
