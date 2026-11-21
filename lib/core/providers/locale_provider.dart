import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_language.dart';
import 'app_providers.dart';

/// Preference key for the reader's language choice.
const String localePreferenceKey = 'settings.locale';

/// The reader's chosen UI language, or null to follow the device.
final NotifierProvider<LocaleController, Locale?> localeControllerProvider =
    NotifierProvider<LocaleController, Locale?>(
      LocaleController.new,
      name: 'localeController',
    );

class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() {
    try {
      return AppLanguage.fromStorage(
        ref.read(preferencesStoreProvider).string(localePreferenceKey),
      ).locale;
    } catch (_) {
      // No store in a widget-test scope: fall back to the device language.
      return null;
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (!language.hasTranslation) return;
    state = language.locale;
    try {
      await ref
          .read(preferencesStoreProvider)
          .putString(localePreferenceKey, language.storageValue);
    } catch (_) {
      // The in-memory choice still applies for this session.
    }
  }

  AppLanguage get selected => switch (state?.languageCode) {
    'en' => AppLanguage.english,
    'fr' => AppLanguage.french,
    _ => AppLanguage.system,
  };
}
