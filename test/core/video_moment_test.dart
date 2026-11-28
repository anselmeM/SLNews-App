import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/video_moment.dart';

/// The rail's payload may or may not carry a clip length; parsing must accept the
/// shapes the scraper can send and stay silent when it knows nothing.
void main() {
  VideoMoment parse(Map<String, dynamic> json) =>
      VideoMoment.fromJson(<String, dynamic>{
        'video_id': 'v1',
        'title': 'Clip',
        'source': 'ABC 7 Chicago',
        'url': 'https://youtu.be/dQw4w9WgXcQ',
        ...json,
      });

  test('reads a duration in seconds', () {
    expect(
      parse(<String, dynamic>{'duration_seconds': 65}).duration,
      const Duration(seconds: 65),
    );
    expect(
      parse(<String, dynamic>{'duration': 90}).duration,
      const Duration(seconds: 90),
    );
  });

  test('reads a colon duration string', () {
    expect(
      parse(<String, dynamic>{'duration': '1:05'}).duration,
      const Duration(seconds: 65),
    );
    expect(
      parse(<String, dynamic>{'duration': '1:02:03'}).duration,
      const Duration(seconds: 3723),
    );
  });

  test('leaves the duration unknown rather than inventing one', () {
    expect(parse(<String, dynamic>{}).duration, isNull);
    expect(parse(<String, dynamic>{'duration': 0}).duration, isNull);
    expect(parse(<String, dynamic>{'duration': 'unknown'}).duration, isNull);
    expect(parse(<String, dynamic>{'duration': -5}).duration, isNull);
  });

  test('persists the duration as seconds', () {
    final VideoMoment moment = parse(<String, dynamic>{'duration_seconds': 65});
    expect(moment.toJson()['duration_seconds'], 65);

    final VideoMoment restored = VideoMoment.fromJson(moment.toJson());
    expect(restored.duration, const Duration(seconds: 65));
  });

  test('accepts the scraper numeric id by falling back to video_id', () {
    final VideoMoment moment = VideoMoment.fromJson(<String, dynamic>{
      'id': 617,
      'video_id': 'Igado43VyiE',
      'title': 'Live clip',
    });

    expect(moment.id, 'Igado43VyiE');
    expect(moment.youtubeId, 'Igado43VyiE');
  });

  test('other fields still degrade as before', () {
    final VideoMoment moment = parse(<String, dynamic>{'source': ''});
    expect(moment.source, 'SLNews');
    expect(moment.thumbnailUrl, '');
  });
}
