import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/sources/api_client.dart';
import 'package:slnews_mobile/core/data/sources/sl_news_api_source.dart';
import 'package:slnews_mobile/core/data/sources/sl_news_video_source.dart';
import 'package:slnews_mobile/core/domain/models/video_moment.dart';

/// The `/v1/videos` parsing contract: the rail must survive a malformed row and
/// an unconfigured build, and must never throw into the feed page.
void main() {
  group('parse', () {
    test('reads the versioned payload and keeps the fields the card needs', () {
      final List<VideoMoment> videos = SlNewsVideoSource.parse(
        <String, Object?>{
          'data': <Object?>[
            <String, Object?>{
              'id': 'v1',
              'video_id': 'abc',
              'title': 'Leone Stars train',
              'summary': 'Ahead of the qualifier',
              'source': 'SLBC Sports',
              'category': 'sports',
              'url': 'https://youtu.be/abc',
              'thumbnail_url': 'https://img.test/abc.jpg',
              'published_at': '2026-10-15T07:30:00.000Z',
            },
          ],
          'meta': <String, Object?>{'page': 1, 'total': 1, 'has_more': false},
        },
      );

      expect(videos, hasLength(1));
      final VideoMoment video = videos.single;
      expect(video.id, 'v1');
      expect(video.title, 'Leone Stars train');
      expect(video.source, 'SLBC Sports');
      expect(video.thumbnailUrl, 'https://img.test/abc.jpg');
      expect(video.url, 'https://youtu.be/abc');
      expect(video.category, 'sports');
      expect(video.publishedAt, DateTime.utc(2026, 10, 15, 7, 30));
    });

    test('skips rows without an identity or a title', () {
      final List<VideoMoment> videos = SlNewsVideoSource.parse(
        <String, Object?>{
          'data': <Object?>[
            <String, Object?>{'title': 'No id here'},
            <String, Object?>{'id': 'v2'},
            <String, Object?>{'id': 'v3', 'title': 'Kept'},
            'not-an-object',
          ],
        },
      );

      expect(videos.map((VideoMoment video) => video.id), <String>['v3']);
    });

    test('sorts newest first and tolerates a missing date', () {
      final List<VideoMoment> videos = SlNewsVideoSource.parse(
        <String, Object?>{
          'data': <Object?>[
            <String, Object?>{
              'id': 'old',
              'title': 'Old',
              'published_at': '2026-10-10T00:00:00.000Z',
            },
            <String, Object?>{'id': 'undated', 'title': 'Undated'},
            <String, Object?>{
              'id': 'new',
              'title': 'New',
              'published_at': '2026-10-16T00:00:00.000Z',
            },
          ],
        },
      );

      expect(videos.map((VideoMoment video) => video.id), <String>[
        'new',
        'old',
        'undated',
      ]);
    });

    test('degrades to an empty list for a malformed body', () {
      expect(SlNewsVideoSource.parse(null), isEmpty);
      expect(SlNewsVideoSource.parse('not json'), isEmpty);
      expect(SlNewsVideoSource.parse(<String, Object?>{}), isEmpty);
    });
  });

  group('latest', () {
    test('an unconfigured build never touches the network', () async {
      final SlNewsVideoSource source = SlNewsVideoSource(
        const SlNewsApiConfig(baseUrl: '', apiKey: ''),
        ApiClient(),
      );

      expect(source.isConfigured, isFalse);
      expect(await source.latest(), isEmpty);
    });
  });
}
