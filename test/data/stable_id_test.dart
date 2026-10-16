import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/utils/stable_id.dart';

void main() {
  group('StableId.fromUrl', () {
    test('matches the FNV-1a 64 reference value', () {
      // Golden locked against an independent FNV-1a implementation.
      expect(
        StableId.fromUrl('https://awoko.org/news/story'),
        'be3e06262331a9b7',
      );
    });

    test('is lowercase hex, 16 characters wide', () {
      final String id = StableId.fromUrl('https://awoko.org/news/story');
      expect(id.length, 16);
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(id), isTrue);
    });

    test('is stable across calls and normalises before hashing', () {
      final String first = StableId.fromUrl('https://awoko.org/news/story');
      expect(StableId.fromUrl('https://awoko.org/news/story'), first);
      // Trailing slash, case, tracking parameters and fragment are noise.
      expect(StableId.fromUrl('https://AWOKO.org/news/story/'), first);
      expect(
        StableId.fromUrl(
          'https://awoko.org/news/story/?utm_source=twitter&fbclid=abc#top',
        ),
        first,
      );
      expect(StableId.fromUrl('  https://awoko.org/news/story  '), first);
    });

    test('orders query parameters so equivalent URLs collide', () {
      expect(
        StableId.fromUrl('https://awoko.org/s?b=2&a=1'),
        StableId.fromUrl('https://awoko.org/s?a=1&b=2'),
      );
    });

    test('gives different ids to different stories', () {
      expect(
        StableId.fromUrl('https://awoko.org/news/one'),
        isNot(StableId.fromUrl('https://awoko.org/news/two')),
      );
    });

    test('never throws on unusable input', () {
      expect(StableId.fromUrl(''), isNotEmpty);
      expect(StableId.fromUrl('not a url at all'), isNotEmpty);
      expect(StableId.fromUrl('https://'), isNotEmpty);
    });
  });

  group('StableId.fromParts', () {
    test('matches the FNV-1a 64 reference value for joined parts', () {
      expect(
        StableId.fromParts(<String>['awoko', 'Title', '2026-10-15T00:00:00Z']),
        '6f21d5e1d70b30d5',
      );
      expect(
        StableId.fromParts(<String>['awoko', 'Title']),
        '7ba25efa416fdc3d',
      );
    });

    test('is order sensitive and separator safe', () {
      expect(
        StableId.fromParts(<String>['awoko', 'b']),
        isNot(StableId.fromParts(<String>['b', 'awoko'])),
      );
      // Without a separator these two lists would concatenate identically.
      expect(
        StableId.fromParts(<String>['ab', 'c']),
        isNot(StableId.fromParts(<String>['a', 'bc'])),
      );
    });

    test('produces hex ids of the same width as fromUrl', () {
      expect(StableId.fromParts(<String>['x']).length, 16);
    });
  });
}
