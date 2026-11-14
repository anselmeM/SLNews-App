part of 'sync_repository.dart';

/// The reader's synchronised state: three collections plus the server clock.
///
/// A tombstone stays in the collection — `bookmarks` holding a deleted row is
/// meaningful, so [activeBookmarks] is what a UI renders while the full list is
/// what gets pushed and pulled.
@immutable
class SyncState {
  /// Wraps the three collections (unmodifiable copies are taken).
  SyncState({
    List<SyncBookmark> bookmarks = const <SyncBookmark>[],
    List<SyncReaction> reactions = const <SyncReaction>[],
    List<SyncFollow> follows = const <SyncFollow>[],
    this.serverTime,
    this.hasMore = false,
  }) : bookmarks = List<SyncBookmark>.unmodifiable(bookmarks),
       reactions = List<SyncReaction>.unmodifiable(reactions),
       follows = List<SyncFollow>.unmodifiable(follows);

  /// Nothing synced and no server clock.
  const SyncState.empty()
    : bookmarks = const <SyncBookmark>[],
      reactions = const <SyncReaction>[],
      follows = const <SyncFollow>[],
      serverTime = null,
      hasMore = false;

  /// Saved stories, tombstones included.
  final List<SyncBookmark> bookmarks;

  /// Likes, tombstones included.
  final List<SyncReaction> reactions;

  /// Subscriptions, tombstones included.
  final List<SyncFollow> follows;

  /// Server clock at the moment the response was produced.
  ///
  /// Kept for skew diagnostics: it is the server's own `updatedAt` values, not
  /// this, that decide last-write-wins.
  final DateTime? serverTime;

  /// Whether the server truncated at least one collection.
  ///
  /// Only a `GET` sets this; it tells the caller to re-issue the pull with
  /// `since = latestUpdatedAt`.
  final bool hasMore;

  /// Bookmarks a UI should render (tombstones filtered out), newest first.
  List<SyncBookmark> get activeBookmarks => <SyncBookmark>[
    for (final SyncBookmark row in bookmarks)
      if (!row.deleted) row,
  ];

  /// Likes a UI should render.
  List<SyncReaction> get activeReactions => <SyncReaction>[
    for (final SyncReaction row in reactions)
      if (!row.deleted) row,
  ];

  /// Subscriptions a UI should render.
  List<SyncFollow> get activeFollows => <SyncFollow>[
    for (final SyncFollow row in follows)
      if (!row.deleted) row,
  ];

  /// Tombstones only, oldest first.
  List<SyncRow> get tombstones => <SyncRow>[
    for (final SyncRow row in _allRows)
      if (row.deleted) row,
  ];

  /// True when all three collections are empty.
  bool get isEmpty => bookmarks.isEmpty && reactions.isEmpty && follows.isEmpty;

  /// Bookmarks keyed by item id, tombstones included.
  Map<String, SyncBookmark> get bookmarksById => <String, SyncBookmark>{
    for (final SyncBookmark row in bookmarks) row.itemId: row,
  };

  /// Reactions keyed by item id, tombstones included.
  Map<String, SyncReaction> get reactionsById => <String, SyncReaction>{
    for (final SyncReaction row in reactions) row.itemId: row,
  };

  /// Follows keyed by target id, tombstones included.
  Map<String, SyncFollow> get followsById => <String, SyncFollow>{
    for (final SyncFollow row in follows) row.targetId: row,
  };

  /// Newest `updatedAt` across every row, tombstones included.
  ///
  /// This is the value a follow-up delta pull passes as `since` when the server
  /// reported `hasMore`.
  DateTime? get latestUpdatedAt {
    DateTime? latest;
    for (final SyncRow row in _allRows) {
      if (latest == null || row.updatedAt.isAfter(latest)) {
        latest = row.updatedAt;
      }
    }
    return latest;
  }

  /// Every row, in collection order.
  List<SyncRow> get rows => _allRows;

  /// Bookmarks with `updatedAt` strictly after [since].
  List<SyncBookmark> bookmarksSince(DateTime since) => <SyncBookmark>[
    for (final SyncBookmark row in bookmarks)
      if (row.updatedAt.isAfter(since)) row,
  ];

  /// Reactions with `updatedAt` strictly after [since].
  List<SyncReaction> reactionsSince(DateTime since) => <SyncReaction>[
    for (final SyncReaction row in reactions)
      if (row.updatedAt.isAfter(since)) row,
  ];

  /// Follows with `updatedAt` strictly after [since].
  List<SyncFollow> followsSince(DateTime since) => <SyncFollow>[
    for (final SyncFollow row in follows)
      if (row.updatedAt.isAfter(since)) row,
  ];

  /// Delta against [since], or `null` when nothing changed after it.
  ///
  /// `null` (rather than an empty state) is the signal the API contract needs:
  /// "no rows to push". The comparison is on instants, never on the rendered
  /// strings, so `...Z` and `...+00:00` sort identically.
  SyncState? deltaSince(DateTime since) {
    final List<SyncBookmark> changedBookmarks = bookmarksSince(since);
    final List<SyncReaction> changedReactions = reactionsSince(since);
    final List<SyncFollow> changedFollows = followsSince(since);
    if (changedBookmarks.isEmpty &&
        changedReactions.isEmpty &&
        changedFollows.isEmpty) {
      return null;
    }
    return SyncState(
      bookmarks: changedBookmarks,
      reactions: changedReactions,
      follows: changedFollows,
      serverTime: serverTime,
      hasMore: hasMore,
    );
  }

  /// Delta of arbitrary rows against [since]; empty when nothing is newer.
  static List<T> rowsWhere<T extends SyncRow>(
    Iterable<T> rows,
    DateTime since,
  ) => <T>[
    for (final T row in rows)
      if (row.updatedAt.isAfter(since)) row,
  ];

  /// Copy with the given collections replaced.
  SyncState copyWith({
    List<SyncBookmark>? bookmarks,
    List<SyncReaction>? reactions,
    List<SyncFollow>? follows,
    DateTime? serverTime,
    bool? hasMore,
  }) => SyncState(
    bookmarks: bookmarks ?? this.bookmarks,
    reactions: reactions ?? this.reactions,
    follows: follows ?? this.follows,
    serverTime: serverTime ?? this.serverTime,
    hasMore: hasMore ?? this.hasMore,
  );

  /// Drops the rows named by [rejections] from this state.
  ///
  /// Used to build the state returned by a push whose server response carried
  /// no `state` object: a rejected row did not apply, so it must not be
  /// reported as the converged value.
  SyncState withoutRows(Iterable<SyncRowRef> rejected) {
    final Set<String> bookmarkIds = <String>{};
    final Set<String> reactionIds = <String>{};
    final Set<String> followIds = <String>{};
    for (final SyncRowRef row in rejected) {
      switch (row.collection) {
        case SyncCollections.bookmarks:
          bookmarkIds.add(row.id);
        case SyncCollections.reactions:
          reactionIds.add(row.id);
        case SyncCollections.follows:
          followIds.add(row.id);
      }
    }
    if (bookmarkIds.isEmpty && reactionIds.isEmpty && followIds.isEmpty) {
      return this;
    }
    return SyncState(
      bookmarks: <SyncBookmark>[
        for (final SyncBookmark row in bookmarks)
          if (!bookmarkIds.contains(row.itemId)) row,
      ],
      reactions: <SyncReaction>[
        for (final SyncReaction row in reactions)
          if (!reactionIds.contains(row.itemId)) row,
      ],
      follows: <SyncFollow>[
        for (final SyncFollow row in follows)
          if (!followIds.contains(row.targetId)) row,
      ],
      serverTime: serverTime,
      hasMore: hasMore,
    );
  }

  /// Union of this state and [remote] under the merge-on-first-sign-in rule
  /// (newer `updatedAt` wins per identity key, ties keep this state's row).
  ///
  /// Delegates to the pure function in `merge.dart` so the rule has exactly one
  /// implementation.
  SyncState mergedWith(SyncState remote) => mergeSyncStates(this, remote);

  /// All rows in collection order.
  List<SyncRow> get _allRows => <SyncRow>[
    ...bookmarks,
    ...reactions,
    ...follows,
  ];

  @override
  String toString() =>
      'SyncState(bookmarks: ${bookmarks.length}, reactions: ${reactions.length}, '
      'follows: ${follows.length}, serverTime: ${syncTimestamp(serverTime)})';
}
