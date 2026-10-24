import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/utils/url_normalizer.dart';

void main() {
  group('secureImage', () {
    test('upgrades http image URLs to https', () {
      expect(
        UrlNormalizer.secureImage('http://media.example.com/a.jpg'),
        'https://media.example.com/a.jpg',
      );
    });

    test('keeps https image URLs unchanged', () {
      expect(
        UrlNormalizer.secureImage('https://cdn.example.com/a.jpg?v=2'),
        'https://cdn.example.com/a.jpg?v=2',
      );
    });

    test('rejects relative, data and empty URLs', () {
      expect(UrlNormalizer.secureImage('/media/a.jpg'), isNull);
      expect(UrlNormalizer.secureImage('data:image/png;base64,xx'), isNull);
      expect(UrlNormalizer.secureImage(''), isNull);
      expect(UrlNormalizer.secureImage(null), isNull);
    });
  });
}
