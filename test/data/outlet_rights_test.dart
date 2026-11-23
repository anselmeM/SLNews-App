import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/seed/outlet_registry.dart';
import 'package:slnews_mobile/core/data/sources/feed_source.dart';

/// Content-rights guard for the production outlet registry.
///
/// Every external outlet is excerpt-only and may not show publisher-hosted
/// images until a signed licence or written permission is recorded in its
/// [FeedSourceConfig]. Adding a licensed outlet is a deliberate change that
/// must update this test at the same time.
void main() {
  test('every production outlet is excerpt-only', () {
    expect(OutletRegistry.all, isNotEmpty);
    for (final FeedSourceConfig config in OutletRegistry.all) {
      expect(config.allowsFullText, isFalse, reason: config.id);
      expect(config.allowsRemoteImages, isFalse, reason: config.id);
      expect(config.isPreviewOnly, isTrue, reason: config.id);
    }
  });

  test('outlet ids and feed URLs stay unique', () {
    final Set<String> ids = <String>{};
    final Set<String> urls = <String>{};
    for (final FeedSourceConfig config in OutletRegistry.all) {
      expect(ids.add(config.id), isTrue, reason: 'duplicate id ${config.id}');
      expect(
        urls.add(config.url),
        isTrue,
        reason: 'duplicate url ${config.url}',
      );
    }
  });
}
