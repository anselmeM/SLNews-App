import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/data/repositories/default_user_state_repository.dart';
import 'package:slnews_mobile/core/data/sources/notification_preferences_source.dart';
import 'package:slnews_mobile/core/domain/models/digest_preferences.dart';
import 'package:slnews_mobile/core/domain/repositories/user_state_repository.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/controllers.dart';

import '../support/fakes.dart';

class _RecordingSink implements DigestPreferencesSink {
  final List<DigestPreferences> saved = <DigestPreferences>[];

  @override
  Future<void> save(DigestPreferences preferences) async {
    saved.add(preferences);
  }
}

void main() {
  group('DigestPreferences', () {
    test('maps the local choice onto the server contract', () {
      const DigestPreferences prefs = DigestPreferences(
        digestEnabled: false,
        quietHoursStart: 22 * 60,
        quietHoursEnd: 7 * 60,
        timezoneOffsetMinutes: 60,
      );

      expect(prefs.toServerJson(), <String, dynamic>{
        'digestCadence': 'off',
        'quietHoursStart': 1320,
        'quietHoursEnd': 420,
        'timezoneOffsetMinutes': 60,
      });
      expect(DigestPreferences.clockLabel(1320), '22:00');
      expect(DigestPreferences.clockLabel(420), '07:00');
      expect(DigestPreferences.clockLabel(null), isNull);
      expect(prefs.hasQuietHours, isFalse, reason: 'digest is off');
    });

    test('hasQuietHours requires a complete, non-empty window', () {
      const DigestPreferences off = DigestPreferences();
      expect(off.hasQuietHours, isFalse);

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

  group('DefaultUserStateRepository preferences', () {
    test('round-trips digest and quiet hours through the store', () async {
      final InMemoryPreferencesStore store = InMemoryPreferencesStore();
      final DefaultUserStateRepository repository = DefaultUserStateRepository(
        preferences: store,
      );

      expect(repository.digestEnabled, isTrue);
      expect(repository.quietHoursStart, isNull);
      expect(repository.quietHoursEnd, isNull);

      await repository.setDigestEnabled(false);
      await repository.setQuietHours(start: 21 * 60, end: 6 * 60);

      expect(repository.digestEnabled, isFalse);
      expect(repository.quietHoursStart, 1260);
      expect(repository.quietHoursEnd, 360);

      // Reopening the same store proves it was persisted, not just held.
      final DefaultUserStateRepository reopened = DefaultUserStateRepository(
        preferences: store,
      );
      expect(reopened.digestEnabled, isFalse);
      expect(reopened.quietHoursStart, 1260);

      await reopened.setQuietHours();
      expect(reopened.quietHoursStart, isNull);
      expect(reopened.quietHoursEnd, isNull);
    });
  });

  group('SettingsController digest changes', () {
    late FakeUserStateRepository user;
    late _RecordingSink sink;
    late ProviderContainer container;

    setUp(() {
      user = FakeUserStateRepository();
      sink = _RecordingSink();
      container = ProviderContainer(
        overrides: <Override>[
          userStateProvider.overrideWithValue(user),
          notificationPreferencesSourceProvider.overrideWithValue(sink),
        ],
      );
      addTearDown(container.dispose);
    });

    test('saves locally and pushes to the server', () async {
      final SettingsController controller = container.read(
        settingsControllerProvider.notifier,
      );

      await controller.setDigestEnabled(false);
      expect(user.digestEnabled, isFalse);
      expect(sink.saved, hasLength(1));
      expect(sink.saved.single.digestEnabled, isFalse);
      expect(
        sink.saved.single.timezoneOffsetMinutes,
        DateTime.now().timeZoneOffset.inMinutes,
      );

      await controller.setQuietHours(start: 22 * 60, end: 7 * 60);
      expect(user.quietHoursStart, 1320);
      expect(sink.saved.last.quietHoursStart, 1320);
      expect(sink.saved.last.quietHoursEnd, 420);

      await controller.setQuietHours();
      expect(user.quietHoursStart, isNull);
      expect(sink.saved.last.quietHoursStart, isNull);
    });

    test('an offline push failure does not lose the local choice', () async {
      final DigestPreferencesSink failing = _FailingSink();
      container.dispose();
      container = ProviderContainer(
        overrides: <Override>[
          userStateProvider.overrideWithValue(user),
          notificationPreferencesSourceProvider.overrideWithValue(failing),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(settingsControllerProvider.notifier)
          .setDigestEnabled(false);

      expect(user.digestEnabled, isFalse);
      expect(container.read(settingsControllerProvider).digestEnabled, isFalse);
    });
  });
}

class _FailingSink implements DigestPreferencesSink {
  @override
  Future<void> save(DigestPreferences preferences) async {
    throw StateError('offline');
  }
}
