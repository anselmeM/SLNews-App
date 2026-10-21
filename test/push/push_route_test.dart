import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/push/push_route.dart';

void main() {
  test('maps article URLs to the article route', () {
    expect(
      pushRouteFor(<String, dynamic>{'url': '/article/abc'}),
      '/article/abc',
    );
    expect(pushRouteFor(<String, dynamic>{'articleId': 'xyz'}), '/article/xyz');
  });

  test('maps video and section URLs', () {
    expect(pushRouteFor(<String, dynamic>{'url': '/video/v1'}), '/video/v1');
    expect(
      pushRouteFor(<String, dynamic>{'url': '/section/sports'}),
      '/section/sports',
    );
    expect(
      pushRouteFor(<String, dynamic>{'url': '/top_stories'}),
      '/top_stories',
    );
  });

  test('ignores unknown or empty payloads', () {
    expect(pushRouteFor(<String, dynamic>{}), isNull);
    expect(pushRouteFor(<String, dynamic>{'url': '/'}), isNull);
    expect(
      pushRouteFor(<String, dynamic>{'url': 'https://example.com'}),
      isNull,
    );
    expect(pushRouteFor(<String, dynamic>{'url': '/article/'}), isNull);
  });
}
