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
    this.editorsPicksEnabled = false,
    this.interactiveContentEnabled = true,
    this.sportsAlertsEnabled = true,
    this.weatherForecastEnabled = true,
  });

  final AppThemeMode themeMode;

  /// Multiplier applied to the system text scale by the article reader's `aA`.
  final double textScale;

  final String activeLocationId;
  final bool breakingNewsAlertsEnabled;

  /// Notification categories the reader can switch on or off.
  ///
  /// Defaults follow the reference screen: breaking news and sports alerts on,
  /// editor's picks and interactive content off. `interactiveContentEnabled` is
  /// persisted for the category the API does not produce yet, so enabling it is
  /// a real preference and not a lost toggle.
  final bool editorsPicksEnabled;
  final bool interactiveContentEnabled;
  final bool sportsAlertsEnabled;

  /// When false the weather row is hidden from the feeds.
  final bool weatherForecastEnabled;

  /// Language and region shown on the settings screen. The app ships one locale.
  static const String languageRegion = 'English (Sierra Leone)';

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
    bool? editorsPicksEnabled,
    bool? interactiveContentEnabled,
    bool? sportsAlertsEnabled,
    bool? weatherForecastEnabled,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      textScale: textScale ?? this.textScale,
      activeLocationId: activeLocationId ?? this.activeLocationId,
      breakingNewsAlertsEnabled:
          breakingNewsAlertsEnabled ?? this.breakingNewsAlertsEnabled,
      editorsPicksEnabled: editorsPicksEnabled ?? this.editorsPicksEnabled,
      interactiveContentEnabled:
          interactiveContentEnabled ?? this.interactiveContentEnabled,
      sportsAlertsEnabled: sportsAlertsEnabled ?? this.sportsAlertsEnabled,
      weatherForecastEnabled:
          weatherForecastEnabled ?? this.weatherForecastEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.textScale == textScale &&
      other.activeLocationId == activeLocationId &&
      other.breakingNewsAlertsEnabled == breakingNewsAlertsEnabled &&
      other.editorsPicksEnabled == editorsPicksEnabled &&
      other.interactiveContentEnabled == interactiveContentEnabled &&
      other.sportsAlertsEnabled == sportsAlertsEnabled &&
      other.weatherForecastEnabled == weatherForecastEnabled;

  @override
  int get hashCode => Object.hash(
    themeMode,
    textScale,
    activeLocationId,
    breakingNewsAlertsEnabled,
    editorsPicksEnabled,
    interactiveContentEnabled,
    sportsAlertsEnabled,
    weatherForecastEnabled,
  );
}
