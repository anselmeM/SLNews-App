import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/app_settings.dart';
import '../domain/models/follow_models.dart';
import '../domain/models/notification_item.dart';
import '../domain/repositories/notification_repository.dart';
import '../domain/repositories/user_state_repository.dart';
import '../domain/sync/sync_repository.dart';
import 'app_providers.dart';
import 'sync_controller.dart';

/// Reader preferences (theme, text scale, home location, alerts).
final NotifierProvider<SettingsController, AppSettings>
settingsControllerProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
  name: 'settings',
);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final UserStateRepository repository = ref.watch(userStateProvider);
    return AppSettings(
      themeMode: AppThemeMode.fromWire(repository.themeMode),
      textScale: repository.textScale,
      activeLocationId: repository.activeLocationId,
      breakingNewsAlertsEnabled: repository.breakingNewsAlertsEnabled,
      editorsPicksEnabled: repository.editorsPicksEnabled,
      interactiveContentEnabled: repository.interactiveContentEnabled,
      sportsAlertsEnabled: repository.sportsAlertsEnabled,
      weatherForecastEnabled: repository.weatherForecastEnabled,
    );
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

  Future<void> setActiveLocation(String locationId) async {
    await ref.read(userStateProvider).setActiveLocationId(locationId);
    state = state.copyWith(activeLocationId: locationId);
    ref.invalidate(activeWeatherProvider);
    ref.invalidate(locationFeedProvider);
  }

  Future<void> setBreakingNewsAlertsEnabled(bool enabled) async {
    await ref.read(userStateProvider).setBreakingNewsAlertsEnabled(enabled);
    state = state.copyWith(breakingNewsAlertsEnabled: enabled);
  }

  Future<void> setEditorsPicksEnabled(bool enabled) async {
    await ref.read(userStateProvider).setEditorsPicksEnabled(enabled);
    state = state.copyWith(editorsPicksEnabled: enabled);
  }

  Future<void> setInteractiveContentEnabled(bool enabled) async {
    await ref.read(userStateProvider).setInteractiveContentEnabled(enabled);
    state = state.copyWith(interactiveContentEnabled: enabled);
  }

  Future<void> setSportsAlertsEnabled(bool enabled) async {
    await ref.read(userStateProvider).setSportsAlertsEnabled(enabled);
    state = state.copyWith(sportsAlertsEnabled: enabled);
  }

  Future<void> setWeatherForecastEnabled(bool enabled) async {
    await ref.read(userStateProvider).setWeatherForecastEnabled(enabled);
    state = state.copyWith(weatherForecastEnabled: enabled);
  }
}

/// Saved stories.
final NotifierProvider<BookmarksController, Set<String>>
bookmarksControllerProvider =
    NotifierProvider<BookmarksController, Set<String>>(
      BookmarksController.new,
      name: 'bookmarks',
    );

class BookmarksController extends Notifier<Set<String>> {
  @override
  Set<String> build() => ref.watch(userStateProvider).bookmarkedIds;

  bool isBookmarked(String articleId) => state.contains(articleId);

  Future<void> toggle(String articleId) async {
    final UserStateRepository repository = ref.read(userStateProvider);
    await repository.toggleBookmark(articleId);
    state = <String>{...repository.bookmarkedIds};
    await recordSyncChange(
      ref,
      SyncCollections.bookmarks,
      articleId,
      deleted: !state.contains(articleId),
    );
  }
}

/// Liked stories.
final NotifierProvider<LikesController, Set<String>> likesControllerProvider =
    NotifierProvider<LikesController, Set<String>>(
      LikesController.new,
      name: 'likes',
    );

class LikesController extends Notifier<Set<String>> {
  @override
  Set<String> build() => ref.watch(userStateProvider).likedIds;

  bool isLiked(String articleId) => state.contains(articleId);

  Future<void> toggle(String articleId) async {
    final UserStateRepository repository = ref.read(userStateProvider);
    await repository.toggleLike(articleId);
    state = <String>{...repository.likedIds};
    await recordSyncChange(
      ref,
      SyncCollections.reactions,
      articleId,
      deleted: !state.contains(articleId),
    );
  }
}

/// Followed teams, leagues, locations and topics.
final NotifierProvider<FollowingController, FollowingSnapshot>
followingControllerProvider =
    NotifierProvider<FollowingController, FollowingSnapshot>(
      FollowingController.new,
      name: 'following',
    );

class FollowingController extends Notifier<FollowingSnapshot> {
  @override
  FollowingSnapshot build() => ref.watch(followingRepositoryProvider).load();

  Future<void> toggle(FollowTarget target) async {
    state = await ref.read(followingRepositoryProvider).toggle(target);
    await recordSyncChange(
      ref,
      SyncCollections.follows,
      target.id,
      deleted: !state.isFollowed(target.id),
    );
  }

  Future<void> follow(FollowTarget target) async {
    state = await ref.read(followingRepositoryProvider).follow(target);
    await recordSyncChange(ref, SyncCollections.follows, target.id);
  }

  Future<void> unfollow(String targetId) async {
    state = await ref.read(followingRepositoryProvider).unfollow(targetId);
    await recordSyncChange(
      ref,
      SyncCollections.follows,
      targetId,
      deleted: true,
    );
  }
}

/// Records a local reader-state change for sync, tolerating a scope without a
/// sync stack.
///
/// Feature widget tests build a bare `ProviderScope` with only the repositories
/// they care about; the ledger and the sync repository are not overridden there.
/// A bookmark toggle must still work in that world, so a missing sync stack is
/// treated as "this build does not sync" rather than an error.
Future<void> recordSyncChange(
  Ref ref,
  String collection,
  String id, {
  bool deleted = false,
}) async {
  try {
    await ref
        .read(syncControllerProvider.notifier)
        .recordLocalChange(collection, id, deleted: deleted);
  } on UnimplementedError {
    // No sync stack in this scope (a feature test, or a build without one):
    // local state is still saved, it simply does not sync.
  } catch (error) {
    debugPrint('SLNews: sync hook skipped ($error)');
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
final Provider<Future<void> Function()> refreshFeedsProvider =
    Provider<Future<void> Function()>((Ref ref) {
      return () async {
        await ref.read(articleRepositoryProvider).refresh();
        ref.invalidate(topStoriesProvider);
        ref.invalidate(categoryFeedProvider);
        ref.invalidate(locationFeedProvider);
        ref.invalidate(articleProvider);
      };
    }, name: 'refreshFeeds');
