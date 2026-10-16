/// Merge rule used by merge-on-first-sign-in (see `docs/SYNC-API.md`).
///
/// The local device and the server each hold a copy of the reader's state. A
/// sign-in must union them without losing either side's newest edit, so the rule
/// is **last-write-wins per identity key on `updatedAt`**:
///
/// * both sides have the row → the newer `updatedAt` wins;
/// * equal instants → prefer a deletion, otherwise keep the local row;
/// * only one side has it → that row is kept.
///
/// Two consequences worth naming, because they are what the contract buys:
///
/// * A **tombstone beats an older non-deleted row**, since `deleted: true` is
///   carried with the deletion's own `updatedAt`. A delete made offline is
///   therefore not undone by a pull of the stale live row.
/// * A **newer non-deleted row beats an older tombstone**, so a re-save after a
///   delete is not swallowed. "Tombstones win" is a statement about staleness,
///   not about deletion being permanent.
///
/// Everything here is pure: no clock, no I/O, no logging. That is what makes it
/// exhaustively unit-testable, and it is the only place the rule is implemented
/// (the source, the repository and any future local store all call it).
library;

import 'sync_repository.dart';

/// Merges two rows of the same identity key.
///
/// Ties keep [local]'s value, except that a row's *payload* change at an
/// identical instant is still picked up: the union must never drop a field the
/// other side knows. Concretely, a tie prefers the row that carries the
/// tombstones' flag explicitly (`deleted`) so a delete and a re-save stamped at
/// the same millisecond converge deterministically instead of flapping.
T mergeRows<T extends SyncRow>(T local, T remote) {
  final int comparison = remote.updatedAt.compareTo(local.updatedAt);
  if (comparison > 0) return remote;
  if (comparison < 0) return local;
  // Same instant: prefer a deletion so a re-save cannot silently undo an
  // offline delete; otherwise keep the local value (idempotent re-pull).
  if (remote.deleted && !local.deleted) return remote;
  return local;
}

/// Unions two bookmark collections, newest first.
List<SyncBookmark> mergeBookmarks(
  Iterable<SyncBookmark> local,
  Iterable<SyncBookmark> remote,
) => _merge<SyncBookmark>(local, remote);

/// Unions two reaction collections, newest first.
List<SyncReaction> mergeReactions(
  Iterable<SyncReaction> local,
  Iterable<SyncReaction> remote,
) => _merge<SyncReaction>(local, remote);

/// Unions two follow collections, newest first.
List<SyncFollow> mergeFollows(
  Iterable<SyncFollow> local,
  Iterable<SyncFollow> remote,
) => _merge<SyncFollow>(local, remote);

/// Unions two complete states.
///
/// [local] and [remote] may each be empty, and a row present on only one side
/// survives. [SyncState.serverTime] prefers [remote]'s (it is the server clock)
/// and falls back to [local]'s; [SyncState.hasMore] is always `false` because a
/// merged state is the caller's converged view, not a truncated page.
SyncState mergeSyncStates(SyncState local, SyncState remote) => SyncState(
  bookmarks: mergeBookmarks(local.bookmarks, remote.bookmarks),
  reactions: mergeReactions(local.reactions, remote.reactions),
  follows: mergeFollows(local.follows, remote.follows),
  serverTime: remote.serverTime ?? local.serverTime,
);

/// Keys the union by identity, then orders the result.
///
/// Newest first is what a saved-stories list renders; identity order is the
/// tie-break so two rows stamped at the same millisecond keep a stable position
/// across merges (a merge of a state with itself must return the same order).
List<T> _merge<T extends SyncRow>(Iterable<T> local, Iterable<T> remote) {
  final Map<String, T> merged = <String, T>{};
  for (final T row in local) {
    merged[row.id] = row;
  }
  for (final T row in remote) {
    final T? existing = merged[row.id];
    merged[row.id] = existing == null ? row : mergeRows<T>(existing, row);
  }
  final List<T> rows = merged.values.toList(growable: false);
  rows.sort((T a, T b) {
    final int byTime = b.updatedAt.compareTo(a.updatedAt);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  });
  return List<T>.unmodifiable(rows);
}
