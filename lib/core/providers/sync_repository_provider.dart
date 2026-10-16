import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sync/default_sync_repository.dart';
import '../data/sync/remote_sync_source.dart';
import '../data/sync/sync_api_config.dart';
import '../domain/sync/sync_repository.dart';
import 'app_providers.dart';

/// Where the mobile sync API lives for this build.
///
/// Overridden by `AppBootstrap` so a test (or a staging build) can point sync at
/// an arbitrary origin without touching compile-time configuration.
final Provider<SyncApiConfig> syncApiConfigProvider = Provider<SyncApiConfig>(
  (Ref ref) => SyncApiConfig.fromEnvironment(),
  name: 'syncApiConfig',
);

/// Reader-state sync over `GET`/`POST /api/mobile/v1/sync`.
///
/// Always constructible: when the build has no endpoint the source reports
/// `isConfigured == false` and neither `pull` nor `push` performs I/O, so the app
/// behaves exactly like the local-only build it was before sync existed.
final Provider<SyncRepository> syncRepositoryProvider =
    Provider<SyncRepository>(
      (Ref ref) => DefaultSyncRepository(
        source: RemoteSyncSource(
          config: ref.watch(syncApiConfigProvider),
          api: ref.watch(apiClientProvider),
        ),
      ),
      name: 'syncRepository',
    );
