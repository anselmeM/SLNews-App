import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/config/app_language.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/locale_provider.dart';
import 'package:slnews_mobile/l10n/app_localizations.dart';

void main() {
  group('catalogs', () {
    test('English and French resolve their own strings', () {
      expect(lookupAppLocalizations(const Locale('en')).navNews, 'News');
      expect(lookupAppLocalizations(const Locale('fr')).navNews, 'Actualités');
      expect(
        lookupAppLocalizations(const Locale('fr')).settingsAppearance,
        'Apparence',
      );
    });

    test('only translated locales are supported', () {
      expect(AppLocalizations.supportedLocales, hasLength(2));
      expect(
        AppLocalizations.supportedLocales.map(
          (Locale locale) => locale.languageCode,
        ),
        containsAll(<String>['en', 'fr']),
      );
      expect(
        AppLocalizations.supportedLocales.any(
          (Locale locale) => locale.languageCode == 'kri',
        ),
        isFalse,
        reason: 'Krio waits for a translator',
      );
    });
  });

  group('AppLanguage', () {
    test('maps storage values and locales', () {
      expect(AppLanguage.fromStorage('fr'), AppLanguage.french);
      expect(AppLanguage.fromStorage('en'), AppLanguage.english);
      expect(AppLanguage.fromStorage('kri'), AppLanguage.krio);
      expect(AppLanguage.fromStorage('nonsense'), AppLanguage.system);
      expect(AppLanguage.french.locale, const Locale('fr'));
      expect(AppLanguage.system.locale, isNull);
      expect(AppLanguage.krio.hasTranslation, isFalse);
      expect(AppLanguage.french.endonym, 'Français');
    });
  });

  group('LocaleController', () {
    test('persists the chosen language and restores it', () async {
      final InMemoryPreferencesStore store = InMemoryPreferencesStore();
      ProviderContainer build() => ProviderContainer(
        overrides: <Override>[
          preferencesStoreProvider.overrideWithValue(store),
        ],
      );

      final ProviderContainer container = build();
      addTearDown(container.dispose);
      expect(container.read(localeControllerProvider), isNull);

      await container
          .read(localeControllerProvider.notifier)
          .setLanguage(AppLanguage.french);

      expect(container.read(localeControllerProvider), const Locale('fr'));
      expect(store.string(localePreferenceKey), 'fr');
      expect(
        container.read(localeControllerProvider.notifier).selected,
        AppLanguage.french,
      );

      final ProviderContainer reopened = build();
      addTearDown(reopened.dispose);
      expect(reopened.read(localeControllerProvider), const Locale('fr'));
    });

    test('Krio cannot be selected until a catalog exists', () async {
      final InMemoryPreferencesStore store = InMemoryPreferencesStore();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          preferencesStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(localeControllerProvider.notifier)
          .setLanguage(AppLanguage.krio);

      expect(container.read(localeControllerProvider), isNull);
      expect(store.string(localePreferenceKey), isNull);
    });

    test('System default clears the stored choice', () async {
      final InMemoryPreferencesStore store = InMemoryPreferencesStore();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          preferencesStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      final LocaleController controller = container.read(
        localeControllerProvider.notifier,
      );

      await controller.setLanguage(AppLanguage.french);
      await controller.setLanguage(AppLanguage.system);

      expect(container.read(localeControllerProvider), isNull);
      expect(store.string(localePreferenceKey), 'system');
    });
  });
}
