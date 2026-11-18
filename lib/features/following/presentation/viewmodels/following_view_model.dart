import '../../../../core/domain/models/follow_models.dart';
import '../../../../core/domain/models/notification_item.dart';

/// Pure-Dart derivation behind the Following tab.
///
/// The repository hands over a flat [FollowingSnapshot]; everything the screen
/// shows — section membership, suggestion filtering, ordering and the unread
/// badge — is computed here so it can be unit-tested without a widget tree or a
/// `ProviderScope`.
class FollowingViewModel {
  const FollowingViewModel({
    required this.snapshot,
    this.notifications = const <NotificationItem>[],
    this.hasError = false,
    this.isLoading = false,
  });

  final FollowingSnapshot snapshot;

  /// Alerts backing the "Notification history" row; only used for its unread
  /// count on this screen.
  final List<NotificationItem> notifications;

  /// True when the following notifier itself failed to build (a repository
  /// failure); the page then shows the retryable error state instead of the
  /// groups.
  final bool hasError;

  /// True while the alert history is still resolving. The subscriptions hydrate
  /// synchronously, so this is the page's only genuine first-frame loading
  /// state and it is what the skeleton rows stand in for.
  final bool isLoading;

  /// Teams and leagues the reader follows, alphabetically sorted.
  List<FollowTarget> get sports =>
      _group(<FollowKind>{FollowKind.team, FollowKind.league});

  /// Followed topics, alphabetically sorted.
  ///
  /// Publishers are their own group ("Sources"); before that section existed a
  /// followed publisher fell back into Topics so it rendered somewhere.
  List<FollowTarget> get topics => _group(<FollowKind>{FollowKind.topic});

  /// "Based on what you follow" — topic suggestions that are not followed yet.
  ///
  /// The repository ranks them (popular first, then alphabetical) and caps the
  /// list; re-sorting here would throw that ranking away.
  List<FollowTarget> get suggestedTopics {
    final Set<String> followedIds = snapshot.followedIds.toSet();
    final List<FollowTarget> candidates = snapshot.suggested
        .where(
          (FollowTarget target) =>
              target.kind == FollowKind.topic &&
              !followedIds.contains(target.id),
        )
        .toList(growable: false);
    return _dedupe(candidates);
  }

  /// Followed publishers, kept separate for completeness of the derivation.
  List<FollowTarget> get publishers =>
      _group(<FollowKind>{FollowKind.publisher});

  /// Unread alerts; drives the badge on the "Notification history" row.
  int get unreadNotifications =>
      notifications.where((NotificationItem item) => !item.isRead).length;

  bool get hasUnreadNotifications => unreadNotifications > 0;

  /// True once at least one section has something to render. A snapshot whose
  /// per-kind catalogues are all empty is the "empty catalogue" state.
  bool get hasAnyGroup =>
      sports.isNotEmpty ||
      topics.isNotEmpty ||
      publishers.isNotEmpty ||
      suggestedTopics.isNotEmpty;

  /// Entities of the given [kinds], merging the per-kind catalogues with the
  /// flat `followed` list, de-duplicated by id and sorted alphabetically.
  List<FollowTarget> _group(Set<FollowKind> kinds) {
    // The per-kind lists are the subscription *catalogue*, not the follow set:
    // rendering them wholesale made every available topic look followed. Only
    // ids in `followed` may appear in a followed group; the catalogue entries
    // are used to repair labels for those ids.
    final Set<String> followedIds = snapshot.followedIds.toSet();
    final List<FollowTarget> merged = <FollowTarget>[
      ...snapshot.followed.where(
        (FollowTarget target) => kinds.contains(target.kind),
      ),
      ...snapshot.sports.where(
        (FollowTarget target) =>
            kinds.contains(target.kind) && followedIds.contains(target.id),
      ),
      ...snapshot.locations.where(
        (FollowTarget target) =>
            kinds.contains(target.kind) && followedIds.contains(target.id),
      ),
      ...snapshot.topics.where(
        (FollowTarget target) =>
            kinds.contains(target.kind) && followedIds.contains(target.id),
      ),
      ...snapshot.publishers.where(
        (FollowTarget target) =>
            kinds.contains(target.kind) && followedIds.contains(target.id),
      ),
    ];
    return _sort(_dedupe(merged));
  }

  static List<FollowTarget> _sort(List<FollowTarget> targets) {
    final List<FollowTarget> sorted = List<FollowTarget>.of(targets);
    sorted.sort(
      (FollowTarget a, FollowTarget b) =>
          a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    return sorted;
  }

  /// Keeps the first occurrence of each id, preserving list order.
  static List<FollowTarget> _dedupe(List<FollowTarget> targets) {
    final Set<String> seen = <String>{};
    final List<FollowTarget> unique = <FollowTarget>[];
    for (final FollowTarget target in targets) {
      if (seen.add(target.id)) unique.add(target);
    }
    return unique;
  }
}
