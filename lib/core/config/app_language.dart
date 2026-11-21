import 'dart:ui';

/// Languages the app can present.
///
/// Krio is reserved in the enum so the picker can explain it, but no catalog
/// ships until a translator reviews the copy; selecting it is disabled.
enum AppLanguage {
  system,
  english,
  french,
  krio;

  /// Stable value stored in preferences; `system` means "follow the device".
  String get storageValue => switch (this) {
    AppLanguage.system => 'system',
    AppLanguage.english => 'en',
    AppLanguage.french => 'fr',
    AppLanguage.krio => 'kri',
  };

  /// Flutter locale, or null to inherit the device locale.
  Locale? get locale => switch (this) {
    AppLanguage.system => null,
    AppLanguage.english => const Locale('en'),
    AppLanguage.french => const Locale('fr'),
    AppLanguage.krio => const Locale('kri'),
  };

  bool get hasTranslation => this != AppLanguage.krio;

  /// Maps a resolved Flutter locale back to the picker value.
  static AppLanguage fromLocale(Locale? locale) =>
      switch (locale?.languageCode) {
        'en' => AppLanguage.english,
        'fr' => AppLanguage.french,
        _ => AppLanguage.system,
      };

  static AppLanguage fromStorage(String? value) {
    for (final AppLanguage language in AppLanguage.values) {
      if (language.storageValue == value) return language;
    }
    return AppLanguage.system;
  }

  /// Endonym shown in the picker, independent of the current UI language.
  String get endonym => switch (this) {
    AppLanguage.system => 'System default',
    AppLanguage.english => 'English',
    AppLanguage.french => 'Français',
    AppLanguage.krio => 'Krio',
  };
}
