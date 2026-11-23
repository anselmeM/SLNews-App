import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/app_settings.dart';
import 'package:slnews_mobile/core/domain/models/digest_preferences.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/controllers.dart';
import 'package:slnews_mobile/core/providers/digest_preferences_store.dart';

import '../support/fakes.dart';

const DigestPreferences prefs = DigestPreferences(
  digestEnabled: false,
  quietHoursStart: 22 * 60,
  quietHoursEnd: 7 * 60,
  timezoneOffsetMinutes: 60,
);

void main() {
  group('DigestPreferences', () {
    test('round-trips the local document', () {
      expect(DigestPreferences.fromJson(prefs.toJson()), prefs);
      expect(DigestPreferences.clockLabel(1320), '22:00');
      expect(DigestPreferences.clockLabel(null), isNull);
    });

    test('requires a complete, non-empty quiet-hours window', () {
      expect(const DigestPreferences().hasQuietHours, isFalse);
      expect(
        const DigestPreferences(quietHoursStart: 60).hasQuietHours,
        isFalse,
      );
      expect(
        const DigestPreferences(
          quietHoursStart: 22 * 60,
          quietHoursEnd: 7 * 60,
        ).hasQuietHours,
        isTrue,
      );
    });
  });

  group('device-local digest storage', () {
    late FakeUserStateRepository userState;
    late ProviderContainer container;

    setUp(() {
      userState = FakeUserStateRepository();
      container = ProviderContainer(
        overrides: [userStateProvider.overrideWithValue(userState)],
      );
      addTearDown(container.dispose);
    });

    test(
      'writes one device document, not an account-scoped document',
      () async {
        final DigestPreferencesStore store = container.read(
          digestPreferencesStoreProvider,
        );
        expect(store.read(), const DigestPreferences());

        await store.write(prefs);

        expect(store.read(), prefs);
        expect(
          userState.digestCache.keys,
          contains(DigestPreferencesStore.deviceKey),
        );
        expect(
          jsonDecode(userState.digestCache[DigestPreferencesStore.deviceKey]!),
          prefs.toJson(),
        );
      },
    );

    test('migrates the old signed-out local document once', () async {
      userState.digestCache[DigestPreferencesStore.legacyLocalKey] = jsonEncode(
        prefs.toJson(),
      );

      final DigestPreferencesStore store = container.read(
        digestPreferencesStoreProvider,
      );

      expect(store.read(), prefs);
      await Future<void>.delayed(Duration.zero);
      expect(
        userState.digestCache[DigestPreferencesStore.deviceKey],
        isNotNull,
      );
    });

    test('settings writes stay device-local', () async {
      final SettingsController controller = container.read(
        settingsControllerProvider.notifier,
      );

      await controller.setDigestEnabled(false);
      await controller.setQuietHours(start: 22 * 60, end: 7 * 60);

      final AppSettings settings = container.read(settingsControllerProvider);
      expect(settings.digestEnabled, isFalse);
      expect(settings.quietHoursStart, 22 * 60);
      expect(settings.quietHoursEnd, 7 * 60);
      expect(
        jsonDecode(userState.digestCache[DigestPreferencesStore.deviceKey]!),
        <String, dynamic>{
          'digestEnabled': false,
          'quietHoursStart': 22 * 60,
          'quietHoursEnd': 7 * 60,
          'timezoneOffsetMinutes': 0,
        },
      );
    });

    test('rejects partial and equal-time quiet windows', () async {
      final SettingsController controller = container.read(
        settingsControllerProvider.notifier,
      );
      await expectLater(
        controller.setQuietHours(start: 60),
        throwsArgumentError,
      );
      await expectLater(
        controller.setQuietHours(start: 60, end: 60),
        throwsArgumentError,
      );
    });
  });
}
