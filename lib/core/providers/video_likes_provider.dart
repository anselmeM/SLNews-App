import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_log.dart';

import 'app_providers.dart';

/// Preferences key holding the reader's liked video ids.
const String videoLikesKey = 'video_likes.v1';

/// Liked video moments, stored on the device only.
///
/// A clip is not an article: putting a `video:` id through
/// [likesControllerProvider] would add it to the reader's saved/liked stories
/// and push it to the account as a synced reaction. The reel therefore keeps its
/// own set, and this state never leaves the phone.
final NotifierProvider<VideoLikesController, Set<String>> videoLikesProvider =
    NotifierProvider<VideoLikesController, Set<String>>(
      VideoLikesController.new,
      name: 'videoLikes',
    );

class VideoLikesController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    try {
      return ref.watch(preferencesStoreProvider).stringSet(videoLikesKey);
    } catch (_) {
      // Tests and keyless scopes have no store; starts empty and still toggles.
      return <String>{};
    }
  }

  bool isLiked(String videoId) => state.contains(videoId);

  Future<void> toggle(String videoId) async {
    final Set<String> next = <String>{...state};
    if (!next.remove(videoId)) next.add(videoId);
    state = next;
    try {
      await ref
          .read(preferencesStoreProvider)
          .putStringSet(videoLikesKey, next);
    } catch (error) {
      // Persistence is best-effort: the tap must still change the icon.
      AppLog.debug('Video likes: persist failed: $error');
    }
  }
}
