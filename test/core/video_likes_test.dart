import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/local/preferences_store.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/video_likes_provider.dart';

/// Video likes are deliberately outside the article like/sync path: a clip id
/// in `reactions` would pollute the reader's saved stories and account state.
void main() {
  late InMemoryPreferencesStore store;
  late ProviderContainer container;

  setUp(() {
    store = InMemoryPreferencesStore();
    container = ProviderContainer(
      overrides: <Override>[preferencesStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
  });

  test('starts empty when nothing is stored', () {
    expect(container.read(videoLikesProvider), isEmpty);
  });

  test('toggle likes and unlikes, persisting to its own key', () async {
    final VideoLikesController likes = container.read(
      videoLikesProvider.notifier,
    );

    await likes.toggle('video:first');
    expect(container.read(videoLikesProvider), <String>{'video:first'});
    expect(store.stringSet(videoLikesKey), <String>{'video:first'});

    await likes.toggle('video:second');
    expect(container.read(videoLikesProvider), hasLength(2));

    await likes.toggle('video:first');
    expect(container.read(videoLikesProvider), <String>{'video:second'});
    expect(store.stringSet(videoLikesKey), <String>{'video:second'});
  });

  test('reads an existing set on build', () {
    store = InMemoryPreferencesStore(<String, Object?>{
      videoLikesKey: <String>['video:saved'],
    });
    container = ProviderContainer(
      overrides: <Override>[preferencesStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    expect(container.read(videoLikesProvider), <String>{'video:saved'});
  });
}
