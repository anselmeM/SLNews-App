import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/data/seed/seed_data.dart';
import 'package:slnews_mobile/core/data/seed/seed_loader.dart';
import 'package:slnews_mobile/core/providers/app_bootstrap.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';

/// Minimal seed loader: the bootstrap test must not depend on bundled assets.
class _EmptySeedLoader implements SeedLoader {
  @override
  Future<SeedData> load() async => SeedData.empty;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bootstraps in memory with anonymous identity and a complete graph',
    () async {
      final AppBootstrap bootstrap = await AppBootstrap.create(
        allowPersistence: false,
        seedLoaderOverride: _EmptySeedLoader(),
      );
      addTearDown(bootstrap.container.dispose);

      expect(bootstrap.isPersistent, isFalse);
      expect(bootstrap.feedSources, isNotEmpty);
      expect(bootstrap.preferences.isAvailable, isTrue);
      expect(
        bootstrap.container.read(preferencesStoreProvider),
        same(bootstrap.preferences),
      );
      expect(
        bootstrap.container.read(articleRepositoryProvider),
        same(bootstrap.articleRepository),
      );
      expect(
        bootstrap.container.read(userStateProvider).personalizeFeed,
        isTrue,
      );
      expect(
        bootstrap.container.read(userStateProvider).analyticsEnabled,
        isFalse,
      );
      expect(
        bootstrap.container.read(followingRepositoryProvider),
        same(bootstrap.followingRepository),
      );
      expect(
        bootstrap.container.read(weatherRepositoryProvider),
        same(bootstrap.weatherRepository),
      );
      expect(
        bootstrap.container.read(adRepositoryProvider),
        same(bootstrap.adRepository),
      );
    },
  );

  test('creating a second in-memory bootstrap does not share state', () async {
    final AppBootstrap first = await AppBootstrap.create(
      allowPersistence: false,
      seedLoaderOverride: _EmptySeedLoader(),
    );
    addTearDown(first.container.dispose);
    final AppBootstrap second = await AppBootstrap.create(
      allowPersistence: false,
      seedLoaderOverride: _EmptySeedLoader(),
    );
    addTearDown(second.container.dispose);

    expect(first.preferences, isNot(same(second.preferences)));
    expect(first.container, isNot(same(second.container)));
  });
}
