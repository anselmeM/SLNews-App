import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth/account_scope.dart';
import '../domain/models/app_settings.dart';
import '../domain/models/article.dart';
import '../push/push_service.dart';
import '../domain/models/follow_models.dart';
import '../domain/models/notification_item.dart';
import '../domain/models/digest_preferences.dart';
import '../domain/repositories/notification_repository.dart';
import '../domain/repositories/user_state_repository.dart';
import '../domain/sync/sync_repository.dart';
import 'app_providers.dart';
import 'auth_providers.dart';
import 'digest_preferences_store.dart';
import 'personalization_profile.dart';
import 'sync_controller.dart';

import 'package:slnews_mobile/core/utils/app_log.dart';

part 'controllers_account_state.dart';

/// Reader preferences (theme, text scale, home location, alerts).
final NotifierProvider<SettingsController, AppSettings>
settingsControllerProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
  name: 'settings',
);

class SettingsController extends Notifier<AppSettings> {
  bool _persistedPersonalize = true;

  @override
  AppSettings build() {
    final UserStateRepository repository = ref.watch(userStateProvider);
    // Digest choices are device-local by design: they do not follow an account.
    final DigestPreferences digest = ref
        .watch(digestPreferencesStoreProvider)
        .read();
    final AppSettings settings = AppSettings(
      themeMode: AppThemeMode.fromWire(repository.themeMode),
      textScale: repository.textScale,
      breakingNewsAlertsEnabled: repository.breakingNewsAlertsEnabled,
      editorsPicksEnabled: repository.editorsPicksEnabled,
      interactiveContentEnabled: repository.interactiveContentEnabled,
      sportsAlertsEnabled: repository.sportsAlertsEnabled,
      followedTopicAlertsEnabled: repository.followedTopicAlertsEnabled,
      weatherForecastEnabled: repository.weatherForecastEnabled,
      personalizeFeed: repository.personalizeFeed,
      digestEnabled: digest.digestEnabled,
      quietHoursStart: digest.quietHoursStart,
      quietHoursEnd: digest.quietHoursEnd,
      onboardingCompleted: repository.onboardingCompleted,
    );
    _persistedPersonalize = settings.personalizeFeed;
    return settings;
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    await ref.read(userStateProvider).setThemeMode(mode.wireValue);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setTextScale(double scale) async {
    await ref.read(userStateProvider).setTextScale(scale);
    state = state.copyWith(textScale: scale);
  }

  /// Advances the reader's `aA` control to the next step.
  Future<void> cycleTextScale() => setTextScale(state.nextTextScale);

  Future<void> setBreakingNewsAlertsEnabled(bool enabled) async {
    await ref.read(userStateProvider).setBreakingNewsAlertsEnabled(enabled);
    state = state.copyWith(breakingNewsAlertsEnabled: enabled);
    await _syncPushSegments();
    try {
      final PushService push = ref.read(pushServiceProvider);
      if (enabled) {
        final bool granted = await push.enable();
        if (!granted) {
          await ref.read(userStateProvider).setBreakingNewsAlertsEnabled(false);
          state = state.copyWith(breakingNewsAlertsEnabled: false);
        }
      } else {
        await push.disable();
      }
    } catch (error) {
      AppLog.debug('SettingsController: push toggle failed: $error');
    }
  }

  Future<void> setEditorsPicksEnabled(bool enabled) async {
    await ref.read(userStateProvider).setEditorsPicksEnabled(enabled);
    state = state.copyWith(editorsPicksEnabled: enabled);
  }

  Future<void> _syncPushSegments() async {
    try {
      await ref
          .read(pushServiceProvider)
          .syncSegments(
            followedIds: ref
                .read(followingControllerProvider)
                .followedIds
                .toSet(),
            settings: state,
          );
    } catch (error) {
      AppLog.debug('SettingsController: push segments failed: $error');
    }
  }

  Future<void> setInteractiveContentEnabled(bool enabled) async {
    await ref.read(userStateProvider).setInteractiveContentEnabled(enabled);
    state = state.copyWith(interactiveContentEnabled: enabled);
  }

  Future<void> setSportsAlertsEnabled(bool enabled) async {
    await ref.read(userStateProvider).setSportsAlertsEnabled(enabled);
    state = state.copyWith(sportsAlertsEnabled: enabled);
    await _syncPushSegments();
  }

  Future<void> setFollowedTopicAlertsEnabled(bool enabled) async {
    await ref.read(userStateProvider).setFollowedTopicAlertsEnabled(enabled);
    state = state.copyWith(followedTopicAlertsEnabled: enabled);
    await _syncPushSegments();
    try {
      if (enabled) {
        await ref.read(pushServiceProvider).enable();
      }
    } catch (error) {
      AppLog.debug('SettingsController: topic alert permission failed: $error');
    }
  }

  Future<void> setWeatherForecastEnabled(bool enabled) async {
    await ref.read(userStateProvider).setWeatherForecastEnabled(enabled);
    state = state.copyWith(weatherForecastEnabled: enabled);
  }

  Future<void> _personalizeWrite = Future<void>.value();
  int _personalizeRequest = 0;

  Future<void> setPersonalizeFeed(bool enabled) async {
    // Optimistic update so a rapid second tap sees (and can reverse) the first
    // intent even while persistence is still in flight. Writes are serialized
    // so the last tap always wins on disk.
    final int request = ++_personalizeRequest;
    state = state.copyWith(personalizeFeed: enabled);
    final Future<void> write = _personalizeWrite.then(
      (_) => ref.read(userStateProvider).setPersonalizeFeed(enabled),
    );
    _personalizeWrite = write.catchError((Object _) {});
    try {
      await write;
      _persistedPersonalize = enabled;
    } catch (error) {
      AppLog.debug('SettingsController: personalize preference failed: $error');
      if (request == _personalizeRequest) {
        // Restore the last durable value, not an optimistic value from an
        // earlier failed tap.
        state = state.copyWith(personalizeFeed: _persistedPersonalize);
      }
    }
  }

  /// Enables or disables the daily follow digest on this device.
  Future<void> setDigestEnabled(bool enabled) async {
    final DigestPreferencesStore store = ref.read(
      digestPreferencesStoreProvider,
    );
    final DigestPreferences current = store.read();
    final DigestPreferences next = DigestPreferences(
      digestEnabled: enabled,
      quietHoursStart: current.quietHoursStart,
      quietHoursEnd: current.quietHoursEnd,
    );
    await store.write(next);
    state = state.copyWith(digestEnabled: enabled);
  }

  /// Sets or clears the digest quiet-hours window.
  ///
  /// Both endpoints must change together; a single endpoint or an equal-time
  /// window is rejected instead of silently erasing the saved window.
  Future<void> setQuietHours({int? start, int? end}) async {
    if ((start == null) != (end == null)) {
      throw ArgumentError('Quiet hours need both a start and an end');
    }
    if (start != null && start == end) {
      throw ArgumentError('Quiet hours need different start and end times');
    }
    final DigestPreferencesStore store = ref.read(
      digestPreferencesStoreProvider,
    );
    final DigestPreferences current = store.read();
    final DigestPreferences next = DigestPreferences(
      digestEnabled: current.digestEnabled,
      quietHoursStart: start,
      quietHoursEnd: end,
    );
    await store.write(next);
    state = state.copyWith(
      quietHoursStart: start,
      quietHoursEnd: end,
      clearQuietHours: start == null,
    );
  }

  /// Marks the first-run picker as done and persists it.
  Future<void> completeOnboarding() async {
    await ref.read(userStateProvider).setOnboardingCompleted(true);
    state = state.copyWith(onboardingCompleted: true);
  }
}

/// Breaking-news alert history shown in the Following tab.
final AsyncNotifierProvider<NotificationsController, List<NotificationItem>>
notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, List<NotificationItem>>(
      NotificationsController.new,
      name: 'notifications',
    );

class NotificationsController extends AsyncNotifier<List<NotificationItem>> {
  @override
  Future<List<NotificationItem>> build() =>
      ref.watch(notificationRepositoryProvider).history();

  int get unreadCount =>
      state.value?.where((NotificationItem item) => !item.isRead).length ?? 0;

  Future<void> markRead(String id) async {
    final NotificationRepository repository = ref.read(
      notificationRepositoryProvider,
    );
    await repository.markRead(id);
    final List<NotificationItem> items = await repository.history();
    state = AsyncData<List<NotificationItem>>(items);
  }

  Future<void> markAllRead() async {
    final NotificationRepository repository = ref.read(
      notificationRepositoryProvider,
    );
    await repository.markAllRead();
    final List<NotificationItem> items = await repository.history();
    state = AsyncData<List<NotificationItem>>(items);
  }

  Future<void> reload() async {
    state = AsyncData<List<NotificationItem>>(
      await ref.read(notificationRepositoryProvider).history(),
    );
  }
}

/// Refreshes every ingest-backed stream in one call (pull-to-refresh).
final Provider<Future<void> Function()>
refreshFeedsProvider = Provider<Future<void> Function()>((Ref ref) {
  return () async {
    await ref.read(articleRepositoryProvider).refresh();
    ref.invalidate(topStoriesProvider);
    ref.invalidate(categoryFeedProvider);
    ref.invalidate(articleProvider);
    // League feeds are lazy and cached in the source; a pull-to-refresh must
    // clear both so a failed/empty feed can recover and new stories land.
    try {
      ref.read(leagueNewsSourceProvider).clearCache();
    } catch (_) {
      // Source is not configured in this build/test harness.
    }
    ref.invalidate(leagueNewsProvider);
  };
}, name: 'refreshFeeds');
