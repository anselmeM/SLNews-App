import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/features/article/domain/article_web_mode.dart';

/// The "Read original" policy is what keeps the in-app page from becoming a
/// general-purpose browser: same-publisher links stay, everything else leaves.
void main() {
  final Uri article = Uri.parse(
    'https://www.dailymail.co.uk/news/article-1.html',
  );

  group('linkAction', () {
    test('keeps the same host and its subdomains inside the page', () {
      expect(
        ArticleWebMode.linkAction(
          target: Uri.parse('https://www.dailymail.co.uk/news/other.html'),
          article: article,
        ),
        ArticleLinkAction.allowInPage,
      );
      expect(
        ArticleWebMode.linkAction(
          target: Uri.parse('https://dailymail.co.uk/news/other.html'),
          article: article,
        ),
        ArticleLinkAction.allowInPage,
      );
    });

    test('sends other publishers to the platform', () {
      expect(
        ArticleWebMode.linkAction(
          target: Uri.parse('https://www.bbc.com/news'),
          article: article,
        ),
        ArticleLinkAction.openExternally,
      );
    });

    test('never executes javascript: links', () {
      expect(
        ArticleWebMode.linkAction(
          target: Uri.parse('javascript:alert(1)'),
          article: article,
        ),
        ArticleLinkAction.block,
      );
    });

    test('routes mail, telephone and app links to the platform', () {
      for (final String href in <String>[
        'mailto:tips@example.com',
        'tel:+23276123456',
        'intent://scan/#Intent;scheme=zxing;end',
      ]) {
        expect(
          ArticleWebMode.linkAction(target: Uri.parse(href), article: article),
          ArticleLinkAction.openExternally,
          reason: href,
        );
      }
    });

    test('treats in-page anchors as same-page navigation', () {
      expect(
        ArticleWebMode.linkAction(
          target: Uri.parse('#comments'),
          article: article,
        ),
        ArticleLinkAction.allowInPage,
      );
    });
  });

  group('canReadOriginal', () {
    test('accepts absolute http(s) links only', () {
      expect(ArticleWebMode.canReadOriginal('https://example.com/a'), isTrue);
      expect(ArticleWebMode.canReadOriginal('http://example.com/a'), isTrue);
      expect(ArticleWebMode.canReadOriginal(null), isFalse);
      expect(ArticleWebMode.canReadOriginal(''), isFalse);
      expect(ArticleWebMode.canReadOriginal('/relative/path'), isFalse);
      expect(ArticleWebMode.canReadOriginal('ftp://example.com/a'), isFalse);
    });
  });

  group('typographyScript', () {
    test('scales the root font size from the reader preference', () {
      final String script = ArticleWebMode.typographyScript(
        textScale: 1.15,
        dark: false,
      );

      expect(script, contains('fontSize="18px"'));
      expect(script, contains('colorScheme="light"'));
    });

    test('signals dark mode and installs the progress handler', () {
      final String script = ArticleWebMode.typographyScript(
        textScale: 1,
        dark: true,
      );

      expect(script, contains('colorScheme="dark"'));
      expect(script, contains('readingProgress'));
      expect(script, contains('slnews-reader-style'));
    });

    test('clamps extreme scales to a readable range', () {
      final String tiny = ArticleWebMode.typographyScript(
        textScale: 0.1,
        dark: false,
      );
      final String huge = ArticleWebMode.typographyScript(
        textScale: 9,
        dark: false,
      );

      expect(tiny, contains('fontSize="13px"'));
      expect(huge, contains('fontSize="32px"'));
    });
  });
}
