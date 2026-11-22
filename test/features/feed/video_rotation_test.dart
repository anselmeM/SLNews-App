import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/video_moment.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';

VideoMoment clip(
  String id,
  String source, {
  String? youtubeId,
  int minute = 0,
}) {
  return VideoMoment(
    id: 'video:$id',
    title: '$source clip $id',
    source: source,
    thumbnailUrl: '',
    url: 'https://www.youtube.com/watch?v=${youtubeId ?? id}',
    youtubeId: youtubeId ?? id,
    publishedAt: DateTime.utc(2026, 11, 20, 10, minute),
  );
}

void main() {
  test('interleaves sources instead of letting one channel fill the rail', () {
    final List<VideoMoment> ordered = interleaveVideos(<VideoMoment>[
      clip('a1', 'AYV', minute: 5),
      clip('a2', 'AYV', minute: 4),
      clip('a3', 'AYV', minute: 3),
      clip('s1', 'SLBC', minute: 2),
      clip('s2', 'SLBC', minute: 1),
    ]);

    // Newest-first within each source, alternating sources.
    expect(ordered.map((VideoMoment video) => video.id), <String>[
      'video:a1',
      'video:s1',
      'video:a2',
      'video:s2',
      'video:a3',
    ]);
  });

  test('drops duplicate video ids, including the same YouTube id', () {
    final List<VideoMoment> ordered = interleaveVideos(<VideoMoment>[
      clip('one', 'AYV', youtubeId: 'duplicate'),
      clip('two', 'SLBC', youtubeId: 'duplicate'),
      clip('three', 'SLBC'),
      clip('three', 'AYV'), // same app id under another source
    ]);

    expect(ordered, hasLength(2));
    expect(ordered.map((VideoMoment video) => video.youtubeId), <String>[
      'duplicate',
      'three',
    ]);
  });

  test('empty input stays empty', () {
    expect(interleaveVideos(const <VideoMoment>[]), isEmpty);
  });
}
