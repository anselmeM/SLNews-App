import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/article_repository.dart';
import 'app_providers.dart';

/// Whether the feed on screen came from the network or from storage, and when it
/// was last refreshed.
///
/// Every tab shows the same banner from this, so "offline" no longer looks like a
/// broken page on News, Sports or Following while For You explains itself.
@immutable
class OfflineStatus {
  const OfflineStatus({required this.isOffline, this.lastSyncedAt});

  final bool isOffline;
  final DateTime? lastSyncedAt;
}

/// Reads the current status without subscribing.
///
/// The repository mutates its own flags rather than exposing a stream, so a
/// `watch` here would not rebuild on a connectivity change anyway; every page
/// rebuilds when its feed resolves, which is when the banner matters.
OfflineStatus readOfflineStatus(WidgetRef ref) {
  try {
    final ArticleRepository repository = ref.read(articleRepositoryProvider);
    return OfflineStatus(
      isOffline: repository.isOffline,
      lastSyncedAt: repository.lastSyncedAt,
    );
  } catch (_) {
    // A bare scope - a page pumped outside AppBootstrap, or a widget test without
    // the repository override - answers with a ProviderException, not the
    // UnimplementedError itself. The banner is not worth failing a page over.
    return const OfflineStatus(isOffline: false);
  }
}
