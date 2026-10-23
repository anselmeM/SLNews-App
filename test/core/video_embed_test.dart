import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/utils/video_embed.dart';

/// The reel has to play whatever URL an outlet publishes, so the classification
/// rules are the contract between the scraper payload and the in-app player.
void main() {
  group('youTubeIdFrom', () {
    test('reads every watch/share/shorts/embed shape', () {
      expect(
        youTubeIdFrom('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        youTubeIdFrom('https://youtube.com/watch?v=dQw4w9WgXcQ&t=42s'),
        'dQw4w9WgXcQ',
      );
      expect(
        youTubeIdFrom('https://m.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(youTubeIdFrom('https://youtu.be/dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
      expect(
        youTubeIdFrom('https://youtu.be/dQw4w9WgXcQ?si=abc'),
        'dQw4w9WgXcQ',
      );
      expect(
        youTubeIdFrom('https://www.youtube.com/shorts/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        youTubeIdFrom('https://www.youtube.com/embed/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('rejects non-YouTube hosts, missing ids and malformed ids', () {
      expect(
        youTubeIdFrom('https://www.youtube.com/results?search_query=freetown'),
        isNull,
      );
      expect(youTubeIdFrom('https://example.com/watch?v=dQw4w9WgXcQ'), isNull);
      expect(youTubeIdFrom('https://youtu.be/short'), isNull);
      expect(youTubeIdFrom('not a url'), isNull);
      expect(youTubeIdFrom(''), isNull);
    });
  });

  group('resolvePlayback', () {
    test('a YouTube link plays through the privacy-friendly embed', () {
      final VideoPlayback playback = resolvePlayback(
        'https://youtu.be/dQw4w9WgXcQ',
      );

      expect(playback.kind, VideoPlaybackKind.youtube);
      expect(playback.youtubeId, 'dQw4w9WgXcQ');
      expect(
        playback.embedUrl,
        startsWith('https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ'),
      );
      // Inline playback matters: without it iOS takes the clip full-screen.
      expect(playback.embedUrl, contains('playsinline=1'));
      expect(playback.externalUrl, 'https://youtu.be/dQw4w9WgXcQ');
      expect(playback.isPlayable, isTrue);
    });

    test('another outlet page is loaded in-app instead of in a browser', () {
      final VideoPlayback playback = resolvePlayback(
        'https://slbc.example/news/clip-1',
      );

      expect(playback.kind, VideoPlaybackKind.web);
      expect(playback.embedUrl, 'https://slbc.example/news/clip-1');
      expect(playback.externalUrl, 'https://slbc.example/news/clip-1');
      expect(playback.isPlayable, isTrue);
    });

    test('empty and non-web links are unsupported rather than opened', () {
      for (final String url in <String>[
        '',
        '   ',
        'not a url',
        'file:///tmp/a.mp4',
      ]) {
        final VideoPlayback playback = resolvePlayback(url);
        expect(playback.kind, VideoPlaybackKind.unsupported, reason: url);
        expect(playback.isPlayable, isFalse, reason: url);
      }
    });
  });

  test('falls back to the known id when the URL is a channel page', () {
    final VideoPlayback playback = resolvePlayback(
      'https://www.youtube.com/@AYVMedia',
      knownId: '3f4Y2N4w1bY',
    );
    expect(playback.kind, VideoPlaybackKind.youtube);
    expect(playback.embedUrl, contains('3f4Y2N4w1bY'));
  });
}
