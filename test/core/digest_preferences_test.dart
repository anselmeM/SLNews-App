import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/data/repositories/default_user_state_repository.dart';
import 'package:slnews_mobile/core/data/sources/notification_preferences_source.dart';
import 'package:slnews_mobile/core/domain/auth/auth_repository.dart';
import 'package:slnews_mobile/core/domain/models/app_settings.dart';
import 'package:slnews_mobile/core/domain/models/digest_preferences.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/auth_providers.dart';
import 'package:slnews_mobile/core/providers/controllers.dart';
import 'package:slnews_mobile/core/providers/locale_provider.dart';

import '../support/fakes.dart';

class _FakeGateway implements DigestPreferencesGateway {
  final List<DigestPreferences> saved = <DigestPreferences>[];
  final List<Map<String, dynamic>> patches = <Map<String, dynamic>>[];
  DigestPreferences? server;
  bool failSave = false;
  bool failFetch = false;
  Duration saveDelay = Duration.zero;

  @override
  Future<void> save(Map<String, dynamic> fields) async {
    if (failSave) throw StateError('offline');
    if (saveDelay > Duration.zero) await Future<void>.delayed(saveDelay);
    patches.add(Map<String, dynamic>.of(fields));
    final DigestPreferences current = server ?? const DigestPreferences();
    server = DigestPreferences(
      digestEnabled: fields.containsKey('digestCadence')
          ? fields['digestCadence'] != 'off'
          : current.digestEnabled,
      quietHoursStart: fields.containsKey('quietHoursStart')
          ? (fields['quietHoursStart'] as num?)?.toInt()
          : current.quietHoursStart,
      quietHoursEnd: fields.containsKey('quietHoursEnd')
          ? (fields['quietHoursEnd'] as num?)?.toInt()
          : current.quietHoursEnd,
      timezoneOffsetMinutes: fields.containsKey('timezoneOffsetMinutes')
          ? (fields['timezoneOffsetMinutes'] as num).toInt()
          : current.timezoneOffsetMinutes,
    );
    saved.add(server!);
  }

  @override
  Future<DigestPreferences?> fetch() async {
    if (failFetch) throw StateError('offline');
    return server;
  }
}

class _SwitchableAuth extends AuthController {
  AuthState _state = const AuthState(
    status: AuthStatus.signedIn,
    user: AuthUser(id: 'user-1'),
  );

  @override
  AuthState build() => _state;

  void switchTo(AuthState next) {
    _state = next;
    state = next;
  }
}

const DigestPreferences prefs = DigestPreferences(
  digestEnabled: false,
  quietHoursStart: 22 * 60,
  quietHoursEnd: 7 * 60,
  timezoneOffsetMinutes: 60,
);

/// Gateway that blocks the first save, letting a test observe whether a second
/// save can start before the first finishes.
class _BlockingGateway implements DigestPreferencesGateway {
  final Completer<void> firstStarted = Completer<void>();
  final Completer<void> releaseFirst = Completer<void>();
  final List<Map<String, dynamic>> patches = <Map<String, dynamic>>[];
  int active = 0;
  int maxActive = 0;

  @override
  Future<void> save(Map<String, dynamic> fields) async {
    active++;
    if (active > maxActive) maxActive = active;
    if (!firstStarted.isCompleted) firstStarted.complete();
    await releaseFirst.future;
    patches.add(Map<String, dynamic>.of(fields));
    active--;
  }

  @override
  Future<DigestPreferences?> fetch() async => null;
}

void main() {
  group('DigestPreferences', () {
    test('maps the local choice onto the server contract', () {
      expect(prefs.toServerJson(), <String, dynamic>{
        'digestCadence': 'off',
        'quietHoursStart': 1320,
        'quietHoursEnd': 420,
        'timezoneOffsetMinutes': 60,
      });
      expect(DigestPreferences.clockLabel(1320), '22:00');
      expect(DigestPreferences.clockLabel(420), '07:00');
      expect(DigestPreferences.clockLabel(null), isNull);
    });

    test('decodes local and server payloads', () {
      final DigestPreferences local = DigestPreferences.fromJson(
        prefs.toJson(),
      );
      expect(local, prefs);
      expect(
        DigestPreferences.fromServerJson(<String, dynamic>{
          'digestCadence': 'daily',
          'quietHoursStart': 60,
          'quietHoursEnd': 120,
          'timezoneOffsetMinutes': -60,
        }),
        const DigestPreferences(
          quietHoursStart: 60,
          quietHoursEnd: 120,
          timezoneOffsetMinutes: -60,
        ),
      );
    });

    test('hasQuietHours requires a complete, non-empty window', () {
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

  group('scoped repository storage', () {
    test('keeps accounts separate and persists pending work', () async {
      final InMemoryPreferencesStore store = InMemoryPreferencesStore();
      final DefaultUserStateRepository repository = DefaultUserStateRepository(
        preferences: store,
      );

      final String json = jsonEncode(prefs.toJson());
      await repository.setDigestPreferencesFor('user-1', json);
      await repository.setPendingDigestPreferencesFor('user-1', json);

      expect(repository.digestPreferencesFor('user-1'), json);
      expect(repository.pendingDigestPreferencesFor('user-1'), json);
      expect(repository.digestPreferencesFor('user-2'), isNull);
      // The scoping is visible at the raw key level, not just the API: no
      // device-wide digest key exists for another account to inherit.
      expect(store.string('settings.digestPreferences.user-1'), json);
      expect(store.string('settings.digestPreferences.user-2'), isNull);
      expect(store.string('settings.digestPreferencesPending.user-1'), json);
      expect(store.string('settings.digestPreferencesPending.user-2'), isNull);
      expect(repository.pendingDigestPreferencesFor('user-2'), isNull);

      // Quiet hours are one field pair inside the single document. There are no
      // separate start/end keys an interrupted write could leave mismatched.
      final Map<String, dynamic> stored = jsonDecode(
        store.string('settings.digestPreferences.user-1')!,
      ) as Map<String, dynamic>;
      expect(stored['quietHoursStart'], 22 * 60);
      expect(stored['quietHoursEnd'], 7 * 60);
      expect(store.string('settings.quietStartMinutes'), isNull);
      expect(store.string('settings.quietEndMinutes'), isNull);
      expect(store.string('settings.digestEnabled'), isNull);
      expect(store.string('settings.digestEnabled.user-1'), isNull);

      final DefaultUserStateRepository reopened = DefaultUserStateRepository(
        preferences: store,
      );
      expect(reopened.digestPreferencesFor('user-1'), json);

      await reopened.setPendingDigestPreferencesFor('user-1', null);
      expect(reopened.pendingDigestPreferencesFor('user-1'), isNull);
    });
  });

  test(
    'migrates legacy device-wide digest keys into the scoped cache',
    () async {
      final InMemoryPreferencesStore store = InMemoryPreferencesStore(
        <String, Object?>{
          'settings.digestEnabled': false,
          'settings.quietStartMinutes': '1260',
          'settings.quietEndMinutes': '360',
        },
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          preferencesStoreProvider.overrideWithValue(store),
          userStateProvider.overrideWithValue(
            DefaultUserStateRepository(preferences: store),
          ),
          authControllerProvider.overrideWith(() => _SwitchableAuth()),
          notificationPreferencesSourceProvider.overrideWithValue(
            _FakeGateway(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final AppSettings settings = container.read(settingsControllerProvider);
      expect(settings.digestEnabled, isFalse);
      expect(settings.quietHoursStart, 1260);
      expect(settings.quietHoursEnd, 360);

      await Future<void>.delayed(Duration.zero);

      expect(store.string('settings.digestPreferences.user-1'), isNotNull);
      expect(store.boolean('settings.digestEnabled'), isNull);
      expect(store.string('settings.quietStartMinutes'), isNull);
      expect(store.string('settings.quietEndMinutes'), isNull);
    },
  );

  group('SettingsController digest sync', () {
    late _SwitchableAuth auth;
    late FakeUserStateRepository user;
    late _FakeGateway gateway;
    late ProviderContainer container;

    ProviderContainer build() {
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          userStateProvider.overrideWithValue(user),
          notificationPreferencesSourceProvider.overrideWithValue(gateway),
          authControllerProvider.overrideWith(() => auth),
          preferencesStoreProvider.overrideWithValue(
            InMemoryPreferencesStore(),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      auth = _SwitchableAuth();
      user = FakeUserStateRepository();
      gateway = _FakeGateway();
      container = build();
    });

    test('saves locally and pushes one serialized payload', () async {
      final SettingsController controller = container.read(
        settingsControllerProvider.notifier,
      );

      await controller.setDigestEnabled(false);
      await controller.setQuietHours(start: 22 * 60, end: 7 * 60);
      await controller.flushDigestSync();

      expect(container.read(settingsControllerProvider).digestEnabled, isFalse);
      expect(gateway.saved, hasLength(2));
      // Only changed fields ever travel, never an unrelated stale snapshot.
      const Set<String> allowed = <String>{
        'digestCadence',
        'quietHoursStart',
        'quietHoursEnd',
        'timezoneOffsetMinutes',
      };
      for (final Map<String, dynamic> patch in gateway.patches) {
        expect(patch.keys, everyElement(isIn(allowed)));
      }
      expect(gateway.saved.last.digestEnabled, isFalse);
      expect(gateway.saved.last.quietHoursStart, 1320);
      expect(user.pendingDigestCache['user-1'], isNull);
    });

    test(
      'clearing quiet hours clears both endpoints locally and remotely',
      () async {
        final SettingsController controller = container.read(
          settingsControllerProvider.notifier,
        );
        await controller.setQuietHours(start: 22 * 60, end: 7 * 60);
        await controller.setQuietHours();
        await controller.flushDigestSync();

        final AppSettings settings = container.read(settingsControllerProvider);
        expect(settings.quietHoursStart, isNull);
        expect(settings.quietHoursEnd, isNull);
        expect(gateway.saved.last.quietHoursStart, isNull);
        expect(gateway.saved.last.quietHoursEnd, isNull);
      },
    );

    test('rejects partial and equal-time quiet windows', () async {
      final SettingsController controller = container.read(
        settingsControllerProvider.notifier,
      );

      expect(() => controller.setQuietHours(start: 60), throwsArgumentError);
      expect(() => controller.setQuietHours(end: 60), throwsArgumentError);
      expect(
        () => controller.setQuietHours(start: 60, end: 60),
        throwsArgumentError,
      );
      expect(
        container.read(settingsControllerProvider).quietHoursStart,
        isNull,
      );
      expect(gateway.saved, isEmpty);
    });

    test(
      'a failed save stays pending and retries after reconnecting',
      () async {
        gateway.failSave = true;
        final SettingsController controller = container.read(
          settingsControllerProvider.notifier,
        );

        await controller.setDigestEnabled(false);
        await controller.flushDigestSync();

        expect(user.pendingDigestCache['user-1'], isNotNull);
        expect(
          container.read(settingsControllerProvider).digestEnabled,
          isFalse,
        );

        gateway.failSave = false;
        await controller.retryPendingDigestPreferences();
        await controller.flushDigestSync();

        expect(gateway.saved.last.digestEnabled, isFalse);
        expect(user.pendingDigestCache['user-1'], isNull);
      },
    );

    test('server preferences hydrate the device after sign-in', () async {
      gateway.server = const DigestPreferences(
        digestEnabled: false,
        quietHoursStart: 21 * 60,
        quietHoursEnd: 6 * 60,
      );

      await container
          .read(settingsControllerProvider.notifier)
          .refreshDigestPreferences();

      final AppSettings settings = container.read(settingsControllerProvider);
      expect(settings.digestEnabled, isFalse);
      expect(settings.quietHoursStart, 1260);
      expect(settings.quietHoursEnd, 360);
      expect(gateway.saved, isEmpty, reason: 'hydration must not write back');
      expect(user.digestCache['user-1'], isNotNull);
    });

    test('a pending local change is pushed rather than replaced by the server', () async {
      final SettingsController controller = container.read(
        settingsControllerProvider.notifier,
      );
      gateway.failSave = true;
      await controller.setDigestEnabled(false);
      await controller.flushDigestSync();

      // The server still has the old value; refresh must push the pending one.
      gateway.server = const DigestPreferences(digestEnabled: true);
      gateway.failSave = false;
      await controller.refreshDigestPreferences();
      await controller.flushDigestSync();

      expect(gateway.saved.last.digestEnabled, isFalse);
      expect(container.read(settingsControllerProvider).digestEnabled, isFalse);
    });

    test(
      'switching accounts loads that account\'s own local choices',
      () async {
        final SettingsController controller = container.read(
          settingsControllerProvider.notifier,
        );
        await controller.setDigestEnabled(false);
        await controller.flushDigestSync();
        expect(
          container.read(settingsControllerProvider).digestEnabled,
          isFalse,
        );

        auth.switchTo(
          const AuthState(
            status: AuthStatus.signedIn,
            user: AuthUser(id: 'user-2'),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(settingsControllerProvider).digestEnabled,
          isTrue,
          reason: 'user-2 must not inherit user-1 preferences',
        );
      },
    );

    test(
      'signed-out readers keep local changes without a failed PUT',
      () async {
        // Initialise the auth notifier before switching it.
        container.read(authControllerProvider);
        auth.switchTo(AuthState.signedOut);
        await Future<void>.delayed(Duration.zero);
        final SettingsController controller = container.read(
          settingsControllerProvider.notifier,
        );

        await controller.setDigestEnabled(false);
        await controller.flushDigestSync();

        expect(gateway.saved, isEmpty);
        expect(user.pendingDigestCache['user-1'], isNull);
        expect(user.pendingDigestCache['local'], isNotNull);
      },
    );

    test('serializes saves: only one PUT is in flight at a time', () async {
      final _BlockingGateway blocking = _BlockingGateway();
      container.dispose();
      container = ProviderContainer(
        overrides: <Override>[
          userStateProvider.overrideWithValue(user),
          notificationPreferencesSourceProvider.overrideWithValue(blocking),
          authControllerProvider.overrideWith(() => auth),
          preferencesStoreProvider.overrideWithValue(
            InMemoryPreferencesStore(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final SettingsController controller = container.read(
        settingsControllerProvider.notifier,
      );

      await controller.setDigestEnabled(false);
      await blocking.firstStarted.future;
      // The second change happens while the first PUT is still blocked.
      await controller.setDigestEnabled(true);
      await Future<void>.delayed(Duration.zero);
      expect(
        blocking.maxActive,
        1,
        reason: 'a newer PUT must wait for the in-flight one',
      );
      blocking.releaseFirst.complete();
      await controller.flushDigestSync();
      expect(blocking.patches, hasLength(2));
      expect(blocking.patches.last['digestCadence'], 'daily');
    });

    test('a signed-out change is adopted and pushed after sign-in', () async {
      container.read(authControllerProvider);
      auth.switchTo(AuthState.signedOut);
      await Future<void>.delayed(Duration.zero);
      final SettingsController controller = container.read(
        settingsControllerProvider.notifier,
      );
      await controller.setDigestEnabled(false);
      await controller.flushDigestSync();
      expect(user.pendingDigestCache['local'], isNotNull);
      expect(gateway.saved, isEmpty);

      auth.switchTo(
        const AuthState(
          status: AuthStatus.signedIn,
          user: AuthUser(id: 'user-1'),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await controller.refreshDigestPreferences();
      await controller.flushDigestSync();

      expect(gateway.saved.last.digestEnabled, isFalse);
      expect(user.pendingDigestCache['local'], isNull);
      expect(container.read(settingsControllerProvider).digestEnabled, isFalse);
    });
  });

  test('locale controller remains independent of digest storage', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        preferencesStoreProvider.overrideWithValue(InMemoryPreferencesStore()),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(localeControllerProvider), isNull);
  });
}
