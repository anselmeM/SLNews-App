import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/sync/sync_repository.dart';
import 'package:slnews_mobile/core/providers/sync_controller.dart';

void main() {
  test('sealed sync statuses expose only valid states', () {
    const SyncStatus disabled = SyncDisabled();
    const SyncStatus idle = SyncIdle();
    const SyncStatus syncing = SyncSyncing();
    final SyncStatus synced = SyncSynced(
      lastSyncedAt: DateTime.now().toUtc(),
      applied: const SyncApplied(bookmarks: 2),
      rejected: 1,
    );
    const SyncStatus failed = SyncFailed(failure: SyncUnavailable('offline'));

    expect(disabled, isA<SyncDisabled>());
    expect(disabled.isBusy, isFalse);
    expect(idle.isBusy, isFalse);
    expect(syncing.isBusy, isTrue);
    expect(synced.isBusy, isFalse);
    expect(failed.isBusy, isFalse);
    expect(synced.applied.bookmarks, 2);
    expect(synced.rejected, 1);
    expect(failed.label, contains('unavailable'));
  });

  test('asSyncing preserves last-run metadata', () {
    final DateTime at = DateTime.utc(2026, 11, 13);
    final SyncStatus status = SyncSynced(
      lastSyncedAt: at,
      applied: const SyncApplied(reactions: 3),
      rejected: 2,
    ).asSyncing();

    expect(status, isA<SyncSyncing>());
    expect(status.lastSyncedAt, at);
    expect(status.applied.reactions, 3);
    expect(status.rejected, 2);
  });
}
