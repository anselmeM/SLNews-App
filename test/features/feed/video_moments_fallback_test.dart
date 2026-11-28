import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/data/sources/api_client.dart';
import 'package:slnews_mobile/core/data/sources/sl_news_api_source.dart';
import 'package:slnews_mobile/core/data/sources/sl_news_video_source.dart';
import 'package:slnews_mobile/core/data/seed/video_seed.dart';
import 'package:slnews_mobile/core/domain/models/video_moment.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';

import 'support/fakes.dart';

import 'package:slnews_mobile/core/providers/controllers.dart';

/// A configured source that returns no videos, like the production endpoint
/// while its video table is empty or the API is temporarily unreachable.
class _EmptyVideoSource extends SlNewsVideoSource {
  _EmptyVideoSource()
    : super(
        const SlNewsApiConfig(baseUrl: 'https://api.test', apiKey: 'test-key'),
        ApiClient(),
      );

  @override
  Future<List<VideoMoment>> latest({int limit = 8}) async =>
      const <VideoMoment>[];
}

/// Counts refresh attempts so the pull-to-refresh wiring can be asserted.
class _CountingVideoSource extends SlNewsVideoSource {
  _CountingVideoSource()
    : super(
        const SlNewsApiConfig(baseUrl: 'https://api.test', apiKey: 'test-key'),
        ApiClient(),
      );

  int calls = 0;

  @override
  Future<List<VideoMoment>> latest({int limit = 8}) async {
    calls++;
    return <VideoMoment>[
      VideoMoment(
        id: 'live-${limit == 50 ? calls : 0}',
        title: 'Live',
        source: 'SLBC',
        thumbnailUrl: '',
        url: '',
        publishedAt: DateTime.utc(2026, 11, 27),
      ),
    ];
  }
}

void main() {
  test('a configured build with no live videos keeps the bundled rail', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        preferencesStoreProvider.overrideWithValue(InMemoryPreferencesStore()),
        slNewsVideoSourceProvider.overrideWithValue(_EmptyVideoSource()),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(slNewsVideoSourceProvider), isNotNull);
    expect(
      container.read(videoMomentsProvider).map((VideoMoment v) => v.id),
      SlVideos.all.map((VideoMoment v) => v.id),
    );
  });

  test('pull-to-refresh invalidates the video moments feed', () async {
    final _CountingVideoSource source = _CountingVideoSource();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        preferencesStoreProvider.overrideWithValue(InMemoryPreferencesStore()),
        articleRepositoryProvider.overrideWithValue(FakeArticleRepository()),
        slNewsVideoSourceProvider.overrideWithValue(source),
      ],
    );
    addTearDown(container.dispose);

    container.read(videoMomentsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(source.calls, 1);

    await container.read(refreshFeedsProvider)();
    container.read(videoMomentsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(source.calls, 2);
  });
}
