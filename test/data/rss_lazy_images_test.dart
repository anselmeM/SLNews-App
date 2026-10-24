import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/sources/feed_source.dart';
import 'package:slnews_mobile/core/data/sources/rss_feed_source.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';

const FeedSourceConfig config = FeedSourceConfig(
  id: 'test',
  outlet: 'Test Outlet',
  publisherId: 'test',
  wordmark: 'TEST',
  url: 'https://example.com/feed',
  kind: FeedSourceKind.rss,
  categoryId: 'news',
);

String fixture(String imageTag) =>
    """
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/">
  <channel>
    <title>Test</title>
    <item>
      <title>Lazy image story</title>
      <link>https://example.com/story</link>
      <guid>https://example.com/story</guid>
      <pubDate>Tue, 13 Oct 2026 13:30:25 +0000</pubDate>
      <content:encoded><![CDATA[<p>Body</p>$imageTag]]></content:encoded>
    </item>
  </channel>
</rss>
''';

Article parseOne(String tag) =>
    RssParser.parse(fixture(tag), config: config).single;

void main() {
  test('reads data-src lazy images', () {
    final Article article = parseOne(
      '<img data-src="https://media.example.com/lazy.jpg" src="data:image/gif;base64,R0lGOD" />',
    );
    expect(article.imageUrl, 'https://media.example.com/lazy.jpg');
  });

  test('reads data-lazy-src images', () {
    expect(
      parseOne('<img data-lazy-src="https://cdn.example.com/lazy2.jpg" />')
          .imageUrl,
      'https://cdn.example.com/lazy2.jpg',
    );
  });

  test('picks the largest srcset candidate', () {
    final Article article = parseOne(
      '<img srcset="https://cdn.example.com/s.jpg 320w, https://cdn.example.com/l.jpg 1200w" />',
    );
    expect(article.imageUrl, 'https://cdn.example.com/l.jpg');
  });

  test('resolves a relative lazy URL against the article link', () {
    expect(
      parseOne('<img data-src="/media/rel.jpg" />').imageUrl,
      'https://example.com/media/rel.jpg',
    );
  });
}
