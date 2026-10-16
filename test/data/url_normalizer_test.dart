import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/utils/url_normalizer.dart';

void main() {
  group('UrlNormalizer.canonical', () {
    test('lowercases scheme and host but keeps the path case', () {
      expect(
        UrlNormalizer.canonical('HTTPS://WWW.Awoko.ORG/News/Story'),
        'https://www.awoko.org/News/Story',
      );
    });

    test('strips fragments, tracking parameters and trailing slashes', () {
      expect(
        UrlNormalizer.canonical('https://awoko.org/story/'),
        'https://awoko.org/story',
      );
      expect(
        UrlNormalizer.canonical('https://awoko.org/story#comments'),
        'https://awoko.org/story',
      );
      expect(
        UrlNormalizer.canonical(
          'https://awoko.org/story?utm_source=x&utm_medium=y&fbclid=z&gclid=q',
        ),
        'https://awoko.org/story',
      );
      expect(
        UrlNormalizer.canonical('https://awoko.org/'),
        'https://awoko.org',
      );
    });

    test('keeps meaningful query parameters and sorts them', () {
      expect(
        UrlNormalizer.canonical('https://awoko.org/story?b=2&utm_source=x&a=1'),
        'https://awoko.org/story?a=1&b=2',
      );
    });

    test('drops default ports and preserves other ones', () {
      expect(
        UrlNormalizer.canonical('https://awoko.org:443/story'),
        'https://awoko.org/story',
      );
      expect(
        UrlNormalizer.canonical('http://awoko.org:8080/story'),
        'http://awoko.org:8080/story',
      );
    });

    test('returns an empty string for empty input and survives junk', () {
      expect(UrlNormalizer.canonical('   '), '');
      expect(UrlNormalizer.canonical('awoko.org/story/'), 'awoko.org/story');
    });
  });

  group('UrlNormalizer.absolute', () {
    const String base = 'https://www.thesierraleonetelegraph.com/feed/';

    test('resolves site-relative and protocol-relative links', () {
      expect(
        UrlNormalizer.absolute('/story/one', base: base),
        'https://www.thesierraleonetelegraph.com/story/one',
      );
      expect(
        UrlNormalizer.absolute('story/two', base: base),
        'https://www.thesierraleonetelegraph.com/feed/story/two',
      );
      expect(
        UrlNormalizer.absolute('//cdn.example.com/a.jpg', base: base),
        'https://cdn.example.com/a.jpg',
      );
    });

    test('passes absolute http(s) links through canonically', () {
      expect(
        UrlNormalizer.absolute(
          'https://Awoko.org/story/?utm_source=x',
          base: base,
        ),
        'https://awoko.org/story',
      );
    });

    test('rejects non-http schemes, empty input and unusable bases', () {
      expect(
        UrlNormalizer.absolute('mailto:news@awoko.org', base: base),
        isNull,
      );
      expect(UrlNormalizer.absolute('javascript:alert(1)', base: base), isNull);
      expect(UrlNormalizer.absolute('', base: base), isNull);
      expect(UrlNormalizer.absolute(null, base: base), isNull);
      expect(UrlNormalizer.absolute('/story', base: 'not-a-url'), isNull);
    });
  });

  group('UrlNormalizer.hostLabel', () {
    test('reads a tidy host from full and bare URLs', () {
      expect(UrlNormalizer.hostLabel('https://awoko.org'), 'awoko.org');
      expect(
        UrlNormalizer.hostLabel('https://www.awoko.org/news'),
        'awoko.org',
      );
      expect(
        UrlNormalizer.hostLabel(
          'https://feeds.bbci.co.uk/news/world/africa/rss.xml',
        ),
        'feeds.bbci.co.uk',
      );
      expect(UrlNormalizer.hostLabel('awoko.org/news'), 'awoko.org');
      expect(UrlNormalizer.hostLabel('awoko.org:8080/news'), 'awoko.org');
      expect(UrlNormalizer.hostLabel(''), '');
    });
  });
}
