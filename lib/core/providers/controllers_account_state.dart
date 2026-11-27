part of 'controllers.dart';

/// Saved stories.
final NotifierProvider<BookmarksController, Set<String>>
bookmarksControllerProvider =
    NotifierProvider<BookmarksController, Set<String>>(
      BookmarksController.new,
      name: 'bookmarks',
    );

class BookmarksController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    // Rebuild on identity change; the repository reads the active scope.
    ref.watch(activeAccountKeyProvider);
    return ref.watch(userStateProvider).bookmarkedIds;
  }

  bool isBookmarked(String articleId) => state.contains(articleId);

  Future<void> toggle(String articleId, {bool recordEngagement = true}) async {
    final bool wasSaved = state.contains(articleId);
    final String ownerAccount = _activeAccountKey(ref);
    final bool recordProfile = _personalizationEnabled(ref);
    final int profileGeneration = ref
        .read(personalizationProfileProvider.notifier)
        .generation;
    final UserStateRepository repository = ref.read(userStateProvider);
    await repository.toggleBookmark(articleId);
    state = <String>{...repository.bookmarkedIds};
    final bool nowSaved = state.contains(articleId);
    if (nowSaved) _askForPushAfterFirstAction(ref);
    if (recordEngagement && recordProfile && !wasSaved && nowSaved) {
      unawaited(
        _recordProfile(
          articleId,
          saved: true,
          accountKey: ownerAccount,
          generation: profileGeneration,
        ),
      );
    }
    await recordSyncChange(
      ref,
      SyncCollections.bookmarks,
      articleId,
      deleted: !nowSaved,
    );
  }

  Future<void> _recordProfile(
    String articleId, {
    required bool saved,
    required String accountKey,
    required int generation,
  }) async {
    try {
      if (!_personalizationEnabled(ref)) return;
      final Article? article = await ref
          .read(articleRepositoryProvider)
          .byId(articleId);
      if (article == null) return;
      if (!_personalizationEnabled(ref)) return;
      if (saved) {
        ref
            .read(personalizationProfileProvider.notifier)
            .recordSave(
              article,
              accountKey: accountKey,
              generation: generation,
            );
      } else {
        ref
            .read(personalizationProfileProvider.notifier)
            .recordLike(
              article,
              accountKey: accountKey,
              generation: generation,
            );
      }
    } catch (_) {
      // Personalization must never break saving or liking.
    }
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
  Set<String> build() {
    ref.watch(activeAccountKeyProvider);
    return ref.watch(userStateProvider).likedIds;
  }

  bool isLiked(String articleId) => state.contains(articleId);

  Future<void> toggle(String articleId, {bool recordEngagement = true}) async {
    final bool wasLiked = state.contains(articleId);
    final String ownerAccount = _activeAccountKey(ref);
    final bool recordProfile = _personalizationEnabled(ref);
    final int profileGeneration = ref
        .read(personalizationProfileProvider.notifier)
        .generation;
    final UserStateRepository repository = ref.read(userStateProvider);
    await repository.toggleLike(articleId);
    state = <String>{...repository.likedIds};
    final bool nowLiked = state.contains(articleId);
    if (nowLiked) _askForPushAfterFirstAction(ref);
    if (recordEngagement && recordProfile && !wasLiked && nowLiked) {
      unawaited(
        _recordProfile(
          articleId,
          saved: false,
          accountKey: ownerAccount,
          generation: profileGeneration,
        ),
      );
    }
    await recordSyncChange(
      ref,
      SyncCollections.reactions,
      articleId,
      deleted: !nowLiked,
    );
  }

  Future<void> _recordProfile(
    String articleId, {
    required bool saved,
    required String accountKey,
    required int generation,
  }) async {
    try {
      if (!_personalizationEnabled(ref)) return;
      final Article? article = await ref
          .read(articleRepositoryProvider)
          .byId(articleId);
      if (article == null) return;
      if (!_personalizationEnabled(ref)) return;
      if (saved) {
        ref
            .read(personalizationProfileProvider.notifier)
            .recordSave(
              article,
              accountKey: accountKey,
              generation: generation,
            );
      } else {
        ref
            .read(personalizationProfileProvider.notifier)
            .recordLike(
              article,
              accountKey: accountKey,
              generation: generation,
            );
      }
    } catch (_) {
      // Personalization must never break saving or liking.
    }
  }
}

/// Followed teams, leagues, locations and topics.
/// Full followable catalogue (seed), independent of what is followed.
final Provider<List<FollowTarget>> followCatalogueProvider =
    Provider<List<FollowTarget>>(
      (Ref ref) => ref.watch(followingRepositoryProvider).catalogue,
      name: 'followCatalogue',
    );

final NotifierProvider<FollowingController, FollowingSnapshot>
followingControllerProvider =
    NotifierProvider<FollowingController, FollowingSnapshot>(
      FollowingController.new,
      name: 'following',
    );

class FollowingController extends Notifier<FollowingSnapshot> {
  @override
  FollowingSnapshot build() {
    ref.watch(activeAccountKeyProvider);
    return ref.watch(followingRepositoryProvider).load();
  }

  Future<void> toggle(FollowTarget target) async {
    state = await ref.read(followingRepositoryProvider).toggle(target);
    if (state.isFollowed(target.id)) _askForPushAfterFirstAction(ref);
    await _syncPushSegments();
    await recordSyncChange(
      ref,
      SyncCollections.follows,
      target.id,
      deleted: !state.isFollowed(target.id),
    );
  }

  Future<void> follow(FollowTarget target) async {
    state = await ref.read(followingRepositoryProvider).follow(target);
    _askForPushAfterFirstAction(ref);
    await _syncPushSegments();
    await recordSyncChange(ref, SyncCollections.follows, target.id);
  }

  Future<void> unfollow(String targetId) async {
    state = await ref.read(followingRepositoryProvider).unfollow(targetId);
    await _syncPushSegments();
    await recordSyncChange(
      ref,
      SyncCollections.follows,
      targetId,
      deleted: true,
    );
  }

  Future<void> _syncPushSegments() async {
    try {
      await ref
          .read(pushServiceProvider)
          .syncSegments(
            followedIds: state.followedIds.toSet(),
            settings: ref.read(settingsControllerProvider),
          );
    } catch (error) {
      AppLog.debug('FollowingController: push segments failed: $error');
    }
  }
}

/// Records a local reader-state change for sync, tolerating a scope without a
/// sync stack.
///
/// Feature widget tests build a bare `ProviderScope` with only the repositories
/// they care about; the ledger and the sync repository are not overridden there.
/// A bookmark toggle must still work in that world, so a missing sync stack is
/// treated as "this build does not sync" rather than an error.
/// Nudges the OS permission prompt once, after a first save/like/follow.
bool _personalizationEnabled(Ref ref) {
  try {
    return ref.read(settingsControllerProvider).personalizeFeed;
  } catch (_) {
    return true;
  }
}

String _activeAccountKey(Ref ref) {
  try {
    return ref.read(activeAccountKeyProvider);
  } catch (_) {
    return localAccountIdFor(null);
  }
}

void _askForPushAfterFirstAction(Ref ref) {
  try {
    unawaited(ref.read(pushServiceProvider).requestIfNeeded());
  } catch (_) {
    // Push is not wired in this scope (tests, keyless builds).
  }
}

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
    AppLog.debug('SLNews: sync hook skipped ($error)');
  }
}
