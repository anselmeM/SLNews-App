import 'package:flutter/material.dart';

/// Reader-selected theme mode, persisted as a stable wire value.
enum AppThemeMode {
  system,
  light,
  dark;

  static AppThemeMode fromWire(String? raw) => switch (raw) {
    'light' => AppThemeMode.light,
    'dark' => AppThemeMode.dark,
    _ => AppThemeMode.system,
  };

  String get wireValue => name;

  ThemeMode get materialMode => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };

  String get label => switch (this) {
    AppThemeMode.system => 'System',
    AppThemeMode.light => 'Light',
    AppThemeMode.dark => 'Dark',
  };
}

/// Everything the settings screen and the reader's text-size control mutate.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.textScale = 1,
    this.activeLocationId = 'city:freetown',
    this.breakingNewsAlertsEnabled = true,
  });

  final AppThemeMode themeMode;

  /// Multiplier applied to the system text scale by the article reader's `aA`.
  final double textScale;

  final String activeLocationId;
  final bool breakingNewsAlertsEnabled;

  /// Steps the reader's `aA` control walks through.
  static const List<double> textScaleSteps = <double>[0.9, 1, 1.15, 1.3, 1.5];

  double get nextTextScale {
    for (final double step in textScaleSteps) {
      if (step > textScale + 0.001) return step;
    }
    return textScaleSteps.first;
  }

  AppSettings copyWith({
    AppThemeMode? themeMode,
    double? textScale,
    String? activeLocationId,
    bool? breakingNewsAlertsEnabled,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      textScale: textScale ?? this.textScale,
      activeLocationId: activeLocationId ?? this.activeLocationId,
      breakingNewsAlertsEnabled:
          breakingNewsAlertsEnabled ?? this.breakingNewsAlertsEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.textScale == textScale &&
      other.activeLocationId == activeLocationId &&
      other.breakingNewsAlertsEnabled == breakingNewsAlertsEnabled;

  @override
  int get hashCode => Object.hash(
    themeMode,
    textScale,
    activeLocationId,
    breakingNewsAlertsEnabled,
  );
}
