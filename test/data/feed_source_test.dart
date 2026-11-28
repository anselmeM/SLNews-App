import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/sources/feed_source.dart';

void main() {
  group('FeedSourceKind', () {
    test('parses wire aliases and defaults to RSS', () {
      expect(FeedSourceKind.fromWire('rest_json'), FeedSourceKind.restJson);
      expect(FeedSourceKind.fromWire('JSON'), FeedSourceKind.restJson);
      expect(FeedSourceKind.fromWire('rest'), FeedSourceKind.restJson);
      expect(FeedSourceKind.fromWire('graphql'), FeedSourceKind.graphql);
      expect(FeedSourceKind.fromWire('gql'), FeedSourceKind.graphql);
      expect(FeedSourceKind.fromWire('rss'), FeedSourceKind.rss);
      expect(FeedSourceKind.fromWire('unknown'), FeedSourceKind.rss);
      expect(FeedSourceKind.fromWire(null), FeedSourceKind.rss);
    });

    test('serialises the enum name', () {
      expect(FeedSourceKind.restJson.wireValue, 'restJson');
      expect(FeedSourceKind.graphql.wireValue, 'graphql');
    });
  });

  group('FeedSourceConfig', () {
    const FeedSourceConfig minimal = FeedSourceConfig(
      id: 'awoko',
      outlet: 'Awoko',
      publisherId: 'awoko',
      wordmark: 'AWOKO',
      url: 'https://awoko.org/feed',
      kind: FeedSourceKind.rss,
    );

    test('defaults are excerpt-only and neutral', () {
      expect(minimal.categoryId, 'top');
      expect(minimal.websiteUrl, isNull);
      expect(minimal.authorityScore, 1);
      expect(minimal.isWire, isFalse);
      expect(minimal.country, 'Sierra Leone');
      expect(minimal.isPreviewOnly, isTrue);
    });

    test('full-text licensing controls preview posture', () {
      const FeedSourceConfig licensed = FeedSourceConfig(
        id: 'awoko',
        outlet: 'Awoko',
        publisherId: 'awoko',
        wordmark: 'AWOKO',
        url: 'https://awoko.org/feed',
        kind: FeedSourceKind.rss,
        allowsFullText: true,
      );
      expect(licensed.isPreviewOnly, isFalse);

      const FeedSourceConfig legacySummary = FeedSourceConfig(
        id: 'awoko',
        outlet: 'Awoko',
        publisherId: 'awoko',
        wordmark: 'AWOKO',
        url: 'https://awoko.org/feed',
        kind: FeedSourceKind.rss,
        allowsFullText: true,
        summaryOnly: true,
      );
      expect(legacySummary.isPreviewOnly, isTrue);
    });

    test('round-trips JSON and tolerates missing optional fields', () {
      const FeedSourceConfig configured = FeedSourceConfig(
        id: 'politicosl',
        outlet: 'Politico SL',
        publisherId: 'politico',
        wordmark: 'POLITICO',
        url: 'https://politicosl.com/feed',
        kind: FeedSourceKind.restJson,
        categoryId: 'politics',
        websiteUrl: 'https://politicosl.com',
        authorityScore: 1.5,
        isWire: true,
        summaryOnly: true,
        allowsFullText: false,
        allowsRemoteImages: true,
        country: 'Sierra Leone',
      );
      final FeedSourceConfig decoded = FeedSourceConfig.fromJson(
        configured.toJson(),
      );

      expect(decoded.id, configured.id);
      expect(decoded.outlet, configured.outlet);
      expect(decoded.publisherId, configured.publisherId);
      expect(decoded.wordmark, configured.wordmark);
      expect(decoded.url, configured.url);
      expect(decoded.kind, FeedSourceKind.restJson);
      expect(decoded.categoryId, 'politics');
      expect(decoded.websiteUrl, 'https://politicosl.com');
      expect(decoded.authorityScore, 1.5);
      expect(decoded.isWire, isTrue);
      expect(decoded.summaryOnly, isTrue);
      expect(decoded.allowsRemoteImages, isTrue);

      final FeedSourceConfig blank = FeedSourceConfig.fromJson(
        <String, dynamic>{},
      );
      expect(blank.id, '');
      expect(blank.kind, FeedSourceKind.rss);
      expect(blank.categoryId, 'top');
      expect(blank.authorityScore, 1);
      expect(blank.country, 'Sierra Leone');
    });

    test('identity is based on id and url', () {
      expect(
        minimal,
        const FeedSourceConfig(
          id: 'awoko',
          outlet: 'Different label',
          publisherId: 'other',
          wordmark: 'OTHER',
          url: 'https://awoko.org/feed',
          kind: FeedSourceKind.restJson,
        ),
      );
      expect(
        minimal ==
            const FeedSourceConfig(
              id: 'awoko',
              outlet: 'Awoko',
              publisherId: 'awoko',
              wordmark: 'AWOKO',
              url: 'https://other.example/feed',
              kind: FeedSourceKind.rss,
            ),
        isFalse,
      );
      expect(minimal.hashCode, isA<int>());
    });
  });
}
