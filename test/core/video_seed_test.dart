import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/seed/video_seed.dart';
import 'package:slnews_mobile/core/domain/models/video_moment.dart';
import 'package:slnews_mobile/core/utils/video_embed.dart';

/// The bundled rail is the fallback a signed-out reader actually sees, so every
/// entry must be a real, playable clip — not a channel or search page.
void main() {
  test('every bundled moment is a playable video with a canonical id', () {
    expect(SlVideos.all, isNotEmpty);
    for (final VideoMoment video in SlVideos.all) {
      final VideoPlayback playback = resolvePlayback(
        video.url,
        knownId: video.youtubeId,
      );
      expect(
        playback.kind,
        VideoPlaybackKind.youtube,
        reason: '${video.id} must play, not open a page',
      );
      expect(playback.youtubeId, isNotNull, reason: video.id);
      expect(video.youtubeId, playback.youtubeId, reason: video.id);
      expect(video.thumbnailUrl, startsWith('https://'), reason: video.id);
      expect(video.title.trim(), isNotEmpty, reason: video.id);
      expect(video.source.trim(), isNotEmpty, reason: video.id);
    }
  });

  test('bundled ids are unique so the reel pages map one-to-one', () {
    final Set<String> ids = SlVideos.all
        .map((VideoMoment video) => video.id)
        .toSet();
    expect(ids, hasLength(SlVideos.all.length));
  });
}
