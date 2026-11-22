import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/sources/feed_source.dart';
import 'package:slnews_mobile/core/data/sources/rss_feed_source.dart';
import 'package:slnews_mobile/core/domain/models/article.dart';
import 'package:slnews_mobile/core/utils/stable_id.dart';

/// WordPress-style RSS 2.0, the shape The Sierra Leone Telegraph serves.
const String rssFixture = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"
  xmlns:content="http://purl.org/rss/1.0/modules/content/"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:media="http://search.yahoo.com/mrss/">
  <channel>
    <title>Test Feed</title>
    <item>
      <title><![CDATA[Court case &amp; the &#8216;speaker&#8217; ruling]]></title>
      <link>https://www.thesierraleonetelegraph.com/court-case/</link>
      <guid isPermaLink="false">https://www.thesierraleonetelegraph.com/?p=1</guid>
      <dc:creator><![CDATA[Abdul Rashid Thomas]]></dc:creator>
      <pubDate>Tue, 13 Oct 2026 13:30:25 +0000</pubDate>
      <category><![CDATA[Politics &amp; Law]]></category>
      <category><![CDATA[Breaking News]]></category>
      <media:thumbnail url="https://i0.wp.com/example.com/photo.jpg" />
      <description><![CDATA[<p>Proceedings resumed this morning.</p>
<p>The post <a href="https://example.com/a">Court case</a> appeared first on <a href="https://example.com">Feed</a>.</p>]]></description>
      <content:encoded><![CDATA[<p>Proceedings resumed this morning at the Supreme Court.</p>
<script>window.tracker = 1;</script>
<style>.hide { display: none; }</style>
<h2>What happens next</h2>
<img src="/media/photos/court.jpg" alt="court" />
<p>Lawyers for both sides made arguments about the two-thirds rule.</p>]]></content:encoded>
    </item>
    <item>
      <title>Export figures rise for a third quarter</title>
      <guid isPermaLink="true">https://www.thesierraleonetelegraph.com/export-figures/</guid>
      <author>newsroom@example.com (Fatmata Kargbo)</author>
      <description>Diamond exports rose again, the agency said, with more stones passing through official valuation.</description>
      <media:content medium="video" url="https://cdn.example.com/clip.mp4" />
      <enclosure url="https://cdn.example.com/photo-2.jpg" type="image/jpeg" length="1024" />
    </item>
  </channel>
</rss>
''';

/// Atom 1.0, the shape most JSON-first outlets still expose for syndication.
const String atomFixture = '''
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Politico SL</title>
  <entry>
    <title>Parliament committee backs royalty changes</title>
    <link rel="alternate" type="text/html" href="/articles/royalty-changes"/>
    <id>tag:politicosl.com,2026:royalty</id>
    <published>2026-10-12T09:05:00Z</published>
    <updated>2026-10-12T10:00:00Z</updated>
    <author><name>Isatu Bangura</name></author>
    <summary>Committee approves amendments to mining royalty sharing.</summary>
    <content type="html">&lt;p&gt;The committee approved the amendments.&lt;/p&gt;</content>
  </entry>
  <entry>
    <title>Second entry</title>
    <link rel="self" href="https://politicosl.com/feed/"/>
    <id>https://politicosl.com/articles/second-entry</id>
    <updated>2026-10-11T07:30:00Z</updated>
    <summary>Second summary.</summary>
  </entry>
</feed>
''';

const FeedSourceConfig telegraphConfig = FeedSourceConfig(
  id: 'sltelegraph',
  outlet: 'The Sierra Leone Telegraph',
  publisherId: 'sltelegraph',
  wordmark: 'SLT',
  url: 'https://www.thesierraleonetelegraph.com/feed/',
  kind: FeedSourceKind.rss,
  categoryId: 'politics',
  websiteUrl: 'https://www.thesierraleonetelegraph.com',
);

const FeedSourceConfig politicoConfig = FeedSourceConfig(
  id: 'politicosl',
  outlet: 'Politico SL',
  publisherId: 'politicosl',
  wordmark: 'POLITICO',
  url: 'https://politicosl.com/feed/',
  kind: FeedSourceKind.rss,
  websiteUrl: 'https://politicosl.com',
);

void main() {
  final DateTime now = DateTime.utc(2026, 10, 15, 12);

  group('RssParser with RSS 2.0', () {
    late List<Article> articles;

    setUpAll(() {
      articles = RssParser.parse(rssFixture, config: telegraphConfig, now: now);
    });

    test('reads every item', () {
      expect(articles, hasLength(2));
    });

    test('decodes CDATA and entities in the title', () {
      expect(
        articles.first.title,
        'Court case & the \u2018speaker\u2019 ruling',
      );
    });

    test('derives a stable id from the canonical link', () {
      expect(
        articles.first.id,
        StableId.fromUrl('https://www.thesierraleonetelegraph.com/court-case/'),
      );
      expect(
        articles.first.sourceUrl,
        'https://www.thesierraleonetelegraph.com/court-case',
      );
    });

    test('keeps publisher identity from the configuration', () {
      expect(articles.first.publisher.id, 'sltelegraph');
      expect(articles.first.publisher.name, 'The Sierra Leone Telegraph');
      expect(articles.first.publisher.isWire, isFalse);
      expect(articles.first.categoryId, 'politics');
    });

    test(
      'classifies a business headline when the feed has no category tag',
      () {
        const String document = '''
<rss version="2.0"><channel><item>
  <title>Bank of Sierra Leone holds policy rate as inflation cools</title>
  <link>https://politicosl.com/business/policy-rate</link>
  <description>The central bank kept its benchmark rate unchanged.</description>
</item></channel></rss>''';
        final Article article = RssParser.parse(
          document,
          config: politicoConfig,
          now: now,
        ).single;
        expect(article.categoryId, 'business');
      },
    );

    test('parses the RFC-822 date', () {
      expect(
        articles.first.publishedAt,
        DateTime.utc(2026, 10, 13, 13, 30, 25),
      );
    });

    test('strips WordPress boilerplate from the summary', () {
      expect(articles.first.summary, 'Proceedings resumed this morning.');
    });

    test('sanitises the body: no scripts, styles or inline images', () {
      final String body = articles.first.bodyHtml;
      expect(body, contains('<h2>What happens next</h2>'));
      expect(
        body,
        contains(
          'Lawyers for both sides made arguments about the two-thirds rule.',
        ),
      );
      expect(body, isNot(contains('<script')));
      expect(body, isNot(contains('window.tracker')));
      expect(body, isNot(contains('<style')));
      expect(body, isNot(contains('display: none')));
      expect(body, isNot(contains('<img')));
    });

    test('uses the media thumbnail as the hero image', () {
      expect(
        articles.first.imageUrl,
        'https://i0.wp.com/example.com/photo.jpg',
      );
    });

    test('reads dc:creator and categories', () {
      expect(articles.first.author, 'Abdul Rashid Thomas');
      expect(articles.first.tags, <String>['Politics & Law', 'Breaking News']);
      expect(articles.first.readingMinutes, greaterThanOrEqualTo(1));
    });

    test('falls back to guid, enclosure image and now for sparse items', () {
      final Article second = articles[1];
      expect(
        second.sourceUrl,
        'https://www.thesierraleonetelegraph.com/export-figures',
      );
      expect(second.imageUrl, 'https://cdn.example.com/photo-2.jpg');
      expect(second.publishedAt, now);
      expect(second.tags, isEmpty);
    });

    test('unwraps a parenthesised author name', () {
      expect(articles[1].author, 'Fatmata Kargbo');
    });

    test('honours the limit', () {
      expect(
        RssParser.parse(
          rssFixture,
          config: telegraphConfig,
          limit: 1,
          now: now,
        ),
        hasLength(1),
      );
      expect(
        RssParser.parse(
          rssFixture,
          config: telegraphConfig,
          limit: 0,
          now: now,
        ),
        isEmpty,
      );
    });
  });

  group('RssParser with Atom', () {
    late List<Article> articles;

    setUpAll(() {
      articles = RssParser.parse(atomFixture, config: politicoConfig, now: now);
    });

    test('resolves a site-relative alternate link against the feed URL', () {
      expect(articles, hasLength(2));
      expect(
        articles.first.sourceUrl,
        'https://politicosl.com/articles/royalty-changes',
      );
      expect(
        articles.first.id,
        StableId.fromUrl('https://politicosl.com/articles/royalty-changes'),
      );
    });

    test('prefers published over updated and reads the ISO timestamp', () {
      expect(articles.first.publishedAt, DateTime.utc(2026, 10, 12, 9, 5));
      expect(articles[1].publishedAt, DateTime.utc(2026, 10, 11, 7, 30));
    });

    test('reads the nested author name and unescapes html content', () {
      expect(articles.first.author, 'Isatu Bangura');
      expect(
        articles.first.bodyHtml,
        contains('<p>The committee approved the amendments.</p>'),
      );
      expect(
        articles.first.summary,
        'Committee approves amendments to mining royalty sharing.',
      );
    });

    test('ignores rel="self" links and falls back to the atom id', () {
      expect(
        articles[1].sourceUrl,
        'https://politicosl.com/articles/second-entry',
      );
    });
  });

  group('RssParser resilience', () {
    test('returns an empty list for malformed XML', () {
      expect(
        RssParser.parse('<rss><channel><item>', config: telegraphConfig),
        isEmpty,
      );
      expect(
        RssParser.parse('not xml at all', config: telegraphConfig),
        isEmpty,
      );
      expect(RssParser.parse('   ', config: telegraphConfig), isEmpty);
    });

    test('recovers documents that use undefined HTML entities', () {
      const String document = '''
<rss version="2.0"><channel><item>
  <title>Water&nbsp;shutdown&nbsp;&mdash; western Freetown</title>
  <link>https://awoko.org/water</link>
  <description>The company said&hellip; supplies resume later.</description>
</item></channel></rss>''';
      final List<Article> articles = RssParser.parse(
        document,
        config: telegraphConfig,
        now: now,
      );
      expect(articles, hasLength(1));
      expect(articles.single.title, contains('\u2014'));
      expect(articles.single.title, isNot(contains('&nbsp;')));
      expect(articles.single.summary, contains('\u2026'));
    });

    test('falls back to now when the date is missing or unparseable', () {
      const String document = '''
<rss version="2.0"><channel><item>
  <title>No date here</title>
  <link>https://awoko.org/no-date</link>
  <pubDate>yesterday-ish</pubDate>
</item></channel></rss>''';
      final List<Article> articles = RssParser.parse(
        document,
        config: telegraphConfig,
        now: now,
      );
      expect(articles.single.publishedAt, now);
    });

    test('skips items without a title instead of emitting empty rows', () {
      const String document = '''
<rss version="2.0"><channel>
  <item><link>https://awoko.org/untitled</link></item>
  <item><title>Named story</title><link>https://awoko.org/named</link></item>
</channel></rss>''';
      final List<Article> articles = RssParser.parse(
        document,
        config: telegraphConfig,
        now: now,
      );
      expect(articles, hasLength(1));
      expect(articles.single.title, 'Named story');
    });

    test('lifts a relative inline image out of the body when no media element exists', () {
      const String document = '''
<rss version="2.0"><channel><item>
  <title>Body image only</title>
  <link>https://awoko.org/body-image</link>
  <content:encoded xmlns:content="http://purl.org/rss/1.0/modules/content/"><![CDATA[
    <p>First paragraph.</p>
    <img src="/media/photos/court.jpg" alt="court" />
    <p>Read the <a href="/story/full">full ruling</a>.</p>]]></content:encoded>
</item></channel></rss>''';
      final Article article = RssParser.parse(
        document,
        config: telegraphConfig,
        now: now,
      ).single;
      expect(
        article.imageUrl,
        'https://www.thesierraleonetelegraph.com/media/photos/court.jpg',
      );
      expect(article.bodyHtml, isNot(contains('<img')));
      // Relative links inside the copy are resolved against the feed URL.
      expect(
        article.bodyHtml,
        contains('https://www.thesierraleonetelegraph.com/story/full'),
      );
    });
  });
}
