import '../../domain/sync/merge.dart';
import '../../domain/sync/sync_repository.dart';

import 'package:slnews_mobile/core/utils/app_log.dart';

/// The transport seam the repository composes.
///
/// Declared in the data layer (not in the domain) because it is an HTTP-shaped
/// concern: `RemoteSyncSource` is the only production implementation, and a test
/// fake lets the queue-and-retry behaviour be exercised without a socket.
abstract interface class SyncApiSource {
  /// Whether this source has somewhere to send requests.
  bool get isConfigured;

  /// Reads the server state, or the delta newer than [since].
  Future<SyncState> pull({DateTime? since});

  /// Sends [local] and reports what applied.
  Future<SyncResult> push(SyncState local);
}

/// [SyncRepository] over a [SyncApiSource], with queue-and-retry.
///
/// Two things this adds on top of the source:
///
/// * **Queue-and-retry.** A push that did not reach the server is remembered and
///   merged into the next `push` (and attempted again by the next `pull`), so an
///   edit made while offline, or during an outage, is not silently lost. The
///   queue is **in memory only** for v1: the local Hive state is still the
///   source of truth and the caller rebuilds each batch from it, so a relaunch
///   re-sends whatever is still in local state. Persisting the queue would only
///   matter if the local store could drop rows before they ever synced.
/// * **Convergence.** A successful push returns the server's own rows
///   ([SyncResult.state]), so the caller never has to push-then-pull.
///
/// A build with no sync endpoint reports [isConfigured] `false`; both methods
/// then return in place without issuing a request, which is exactly how the app
/// behaves today.
class DefaultSyncRepository implements SyncRepository {
  /// Creates a repository over `source`; the field is private so the source is
  /// only reachable through this repository's own methods.
  DefaultSyncRepository({required this._source});

  final SyncApiSource _source;

  SyncState _pending = const SyncState.empty();

  /// The failed push waiting to be retried, empty when nothing is queued.
  SyncState get pending => _pending;

  /// How many rows are waiting to be retried (0 when nothing is queued).
  int get pendingRowCount =>
      _pending.bookmarks.length +
      _pending.reactions.length +
      _pending.follows.length;

  /// `true` while a failed push is waiting for the next attempt.
  bool get hasPendingPush => !_pending.isEmpty;

  @override
  bool get isConfigured => _source.isConfigured;

  /// No-op: this repository holds no persisted state of its own.
  ///
  /// Kept so a caller can treat every repository in this layer the same way.
  @override
  Future<void> initialize() async {}

  /// Sends anything queued from a failed push, then reads [since].
  ///
  /// The retry is best-effort: if it fails again the queue survives and the pull
  /// still runs, because a pull can both succeed and give the caller the server
  /// rows it needs to converge locally.
  @override
  Future<SyncState> pull({DateTime? since}) async {
    if (!isConfigured) {
      // Unconfigured builds must not touch the network at all.
      return const SyncState.empty();
    }

    if (hasPendingPush) {
      final SyncResult retried = await _attempt(_pending);
      if (retried.ok) {
        _clearPending();
      } else {
        AppLog.debug(
          'DefaultSyncRepository: queued push still failing '
          '(${retried.failure?.kind ?? 'unknown'})',
        );
      }
    }

    return _source.pull(since: since);
  }

  /// Pushes [local] merged with anything left over from a failed push.
  ///
  /// The merge is per row and last-write-wins, so a retry can never overwrite a
  /// newer local edit with the stale row that failed earlier.
  @override
  Future<SyncResult> push(SyncState local) async {
    if (!isConfigured) {
      return SyncResult.failed(
        SyncFailure.unavailable('sync is not configured for this build'),
        local: local,
      );
    }

    final SyncState attempt = hasPendingPush
        ? mergeSyncStates(local, _pending)
        : local;
    final SyncResult result = await _attempt(attempt);
    if (result.ok) {
      _clearPending();
    } else {
      _pending = attempt;
      AppLog.debug(
        'DefaultSyncRepository: queueing $pendingRowCount row(s) after '
        '${result.failure?.kind ?? 'unknown'} failure',
      );
    }
    return result;
  }

  /// One request through the source, with a local backstop so a fault that
  /// escapes the source still becomes a typed result rather than an exception
  /// on a UI path.
  Future<SyncResult> _attempt(SyncState state) async {
    try {
      return await _source.push(state);
    } catch (error) {
      AppLog.debug('DefaultSyncRepository: push threw ($error)');
      return SyncResult.failed(SyncFailure.unavailable('$error'), local: state);
    }
  }

  /// Drops the queue after a push the server accepted.
  void _clearPending() {
    if (!hasPendingPush) return;
    _pending = const SyncState.empty();
    AppLog.debug('DefaultSyncRepository: queued push applied, queue cleared');
  }
}
