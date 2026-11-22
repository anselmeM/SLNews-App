part of 'sync_controller.dart';

sealed class SyncStatus {
  const SyncStatus({
    this.lastSyncedAt,
    this.applied = SyncApplied.none,
    this.rejected = 0,
  });

  /// Server clock at the last successful run, when known.
  final DateTime? lastSyncedAt;

  /// Rows the server applied in the last push.
  final SyncApplied applied;

  /// Rows the server refused as stale in the last push (not an error).
  final int rejected;

  /// True while a run is in flight.
  bool get isBusy => false;

  /// One-line description for the account card.
  String get label;

  /// Carries the last known metadata into an in-flight status.
  SyncStatus asSyncing() => SyncSyncing(
    lastSyncedAt: lastSyncedAt,
    applied: applied,
    rejected: rejected,
  );

  static String _relative(DateTime? at) {
    if (at == null) return 'just now';
    final Duration delta = DateTime.now().toUtc().difference(at.toUtc());
    if (delta.inMinutes < 1) return 'just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    return '${delta.inDays}d ago';
  }
}

/// This build has no sync endpoint (`SLNEWS_SYNC_URL` empty).
final class SyncDisabled extends SyncStatus {
  const SyncDisabled({super.lastSyncedAt, super.applied, super.rejected});

  @override
  String get label => 'Sync unavailable in this build';
}

/// Configured and signed out, or idle between runs.
final class SyncIdle extends SyncStatus {
  const SyncIdle({super.lastSyncedAt, super.applied, super.rejected});

  @override
  String get label => 'Signed in — not synced yet';
}

final class SyncSyncing extends SyncStatus {
  const SyncSyncing({super.lastSyncedAt, super.applied, super.rejected});

  @override
  bool get isBusy => true;

  @override
  String get label => 'Syncing…';
}

final class SyncSynced extends SyncStatus {
  const SyncSynced({super.lastSyncedAt, super.applied, super.rejected});

  @override
  String get label => 'Synced ${SyncStatus._relative(lastSyncedAt)}';
}

/// The last run failed; [failure] is the typed reason.
final class SyncFailed extends SyncStatus {
  const SyncFailed({
    required this.failure,
    super.lastSyncedAt,
    super.applied,
    super.rejected,
  });

  final SyncFailure failure;

  @override
  String get label => 'Sync failed — ${failure.kind}';
}

/// Change-time ledger backing last-write-wins.
