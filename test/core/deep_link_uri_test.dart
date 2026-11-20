import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/routing/deep_link_uri.dart';

/// Platform URIs arrive in two shapes; the router only understands routes.
/// These cases pin the mapping so a link never lands on the not-found page.
void main() {
  test('a custom-scheme article link becomes the article route', () {
    expect(
      normalizeDeepLink(Uri.parse('slnews://article/slnews-api:4821')),
      Uri.parse('/article/slnews-api:4821'),
    );
  });

  test('an HTTPS App Link becomes the article route', () {
    expect(
      normalizeDeepLink(Uri.parse('https://slnews.sl/article/web:cm123')),
      Uri.parse('/article/web:cm123'),
    );
  });

  test('query parameters survive so campaign links keep their tag', () {
    expect(
      normalizeDeepLink(
        Uri.parse('https://slnews.sl/article/abc?utm_source=whatsapp'),
      ),
      Uri.parse('/article/abc?utm_source=whatsapp'),
    );
  });

  test('internal routes are left untouched', () {
    for (final String route in <String>[
      '/for_you',
      '/article/abc',
      '/following',
      '/sports?tab=team',
    ]) {
      expect(normalizeDeepLink(Uri.parse(route)), Uri.parse(route));
    }
  });

  test('app shortcut links map to their tabs', () {
    expect(
      normalizeDeepLink(Uri.parse('slnews://search')),
      Uri.parse('/search'),
    );
    expect(normalizeDeepLink(Uri.parse('slnews://saved')), Uri.parse('/saved'));
    expect(
      normalizeDeepLink(Uri.parse('slnews://following')),
      Uri.parse('/following'),
    );
  });

  test('unknown hosts and schemes are left for the not-found route', () {
    expect(
      normalizeDeepLink(Uri.parse('https://example.com/article/abc')),
      Uri.parse('https://example.com/article/abc'),
    );
    expect(
      normalizeDeepLink(Uri.parse('https://slnews.sl/privacy')),
      Uri.parse('https://slnews.sl/privacy'),
    );
    expect(
      normalizeDeepLink(Uri.parse('slnews://team/lal')),
      Uri.parse('slnews://team/lal'),
    );
  });

  test('a custom-scheme link without an id is left alone', () {
    expect(
      normalizeDeepLink(Uri.parse('slnews://article')),
      Uri.parse('slnews://article'),
    );
  });

  test('the claimed host list matches the manifest placeholder value', () {
    expect(appLinkHosts, contains('slnews.sl'));
  });
}
