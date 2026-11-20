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
    this.breakingNewsAlertsEnabled = true,
    this.editorsPicksEnabled = false,
    this.interactiveContentEnabled = true,
    this.sportsAlertsEnabled = true,
    this.followedTopicAlertsEnabled = true,
    this.weatherForecastEnabled = true,
    this.digestEnabled = true,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.onboardingCompleted = false,
  });

  final AppThemeMode themeMode;

  /// Multiplier applied to the system text scale by the article reader's `aA`.
  final double textScale;

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

  /// Alerts for the topics and newspapers the reader follows.
  final bool followedTopicAlertsEnabled;

  /// When false the weather row is hidden from the feeds.
  final bool weatherForecastEnabled;

  /// Daily follow-digest delivery and its local quiet window (minutes).
  final bool digestEnabled;
  final int? quietHoursStart;
  final int? quietHoursEnd;

  /// True once the first-run topic/location picker has been completed.
  final bool onboardingCompleted;

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
    bool? breakingNewsAlertsEnabled,
    bool? editorsPicksEnabled,
    bool? interactiveContentEnabled,
    bool? sportsAlertsEnabled,
    bool? followedTopicAlertsEnabled,
    bool? weatherForecastEnabled,
    bool? digestEnabled,
    int? quietHoursStart,
    int? quietHoursEnd,
    bool clearQuietHours = false,
    bool? onboardingCompleted,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      textScale: textScale ?? this.textScale,
      breakingNewsAlertsEnabled:
          breakingNewsAlertsEnabled ?? this.breakingNewsAlertsEnabled,
      editorsPicksEnabled: editorsPicksEnabled ?? this.editorsPicksEnabled,
      interactiveContentEnabled:
          interactiveContentEnabled ?? this.interactiveContentEnabled,
      sportsAlertsEnabled: sportsAlertsEnabled ?? this.sportsAlertsEnabled,
      followedTopicAlertsEnabled:
          followedTopicAlertsEnabled ?? this.followedTopicAlertsEnabled,
      weatherForecastEnabled:
          weatherForecastEnabled ?? this.weatherForecastEnabled,
      digestEnabled: digestEnabled ?? this.digestEnabled,
      quietHoursStart: clearQuietHours
          ? null
          : (quietHoursStart ?? this.quietHoursStart),
      quietHoursEnd: clearQuietHours
          ? null
          : (quietHoursEnd ?? this.quietHoursEnd),
      // Carrying this through matters: the shell shows onboarding until it
      // flips, so dropping it here made completing onboarding a no-op for the
      // in-memory state (the flag only survived until the next app start).
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.textScale == textScale &&
      other.breakingNewsAlertsEnabled == breakingNewsAlertsEnabled &&
      other.editorsPicksEnabled == editorsPicksEnabled &&
      other.interactiveContentEnabled == interactiveContentEnabled &&
      other.sportsAlertsEnabled == sportsAlertsEnabled &&
      other.followedTopicAlertsEnabled == followedTopicAlertsEnabled &&
      other.weatherForecastEnabled == weatherForecastEnabled &&
      other.digestEnabled == digestEnabled &&
      other.quietHoursStart == quietHoursStart &&
      other.quietHoursEnd == quietHoursEnd &&
      other.onboardingCompleted == onboardingCompleted;

  @override
  int get hashCode => Object.hash(
    themeMode,
    textScale,
    breakingNewsAlertsEnabled,
    editorsPicksEnabled,
    interactiveContentEnabled,
    sportsAlertsEnabled,
    followedTopicAlertsEnabled,
    weatherForecastEnabled,
    digestEnabled,
    quietHoursStart,
    quietHoursEnd,
    onboardingCompleted,
  );
}
