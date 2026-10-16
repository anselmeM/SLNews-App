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

  /// Followed cities, alphabetically sorted.
  List<FollowTarget> get locations => _group(<FollowKind>{FollowKind.location});

  /// "Most popular with users" — popularity suggestions that are locations and
  /// are not already followed (following one must remove it from this list).
  List<FollowTarget> get popularLocations {
    final Set<String> followedIds = snapshot.followedIds.toSet();
    final List<FollowTarget> candidates = snapshot.suggested
        .where(
          (FollowTarget target) =>
              target.kind == FollowKind.location &&
              !followedIds.contains(target.id),
        )
        .toList(growable: false);
    return _dedupe(_sort(candidates));
  }

  /// Followed topics, alphabetically sorted. Topics are the catch-all bucket, so
  /// a stray publisher entry falls back here rather than rendering nowhere.
  List<FollowTarget> get topics {
    final List<FollowTarget> grouped = _group(<FollowKind>{FollowKind.topic});
    final Set<String> ids = grouped
        .map((FollowTarget target) => target.id)
        .toSet();
    final List<FollowTarget> publishers = snapshot.followed
        .where(
          (FollowTarget target) =>
              target.kind == FollowKind.publisher && !ids.contains(target.id),
        )
        .toList(growable: false);
    return _sort(_dedupe(<FollowTarget>[...publishers, ...grouped]));
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
      locations.isNotEmpty ||
      topics.isNotEmpty ||
      popularLocations.isNotEmpty;

  /// Entities of the given [kinds], merging the per-kind catalogues with the
  /// flat `followed` list, de-duplicated by id and sorted alphabetically.
  List<FollowTarget> _group(Set<FollowKind> kinds) {
    // `followed` leads so a followed entity is present even if the per-kind
    // catalogue is stale or missing the id.
    final List<FollowTarget> merged = <FollowTarget>[
      ...snapshot.followed.where(
        (FollowTarget target) => kinds.contains(target.kind),
      ),
      ...snapshot.sports.where(
        (FollowTarget target) => kinds.contains(target.kind),
      ),
      ...snapshot.locations.where(
        (FollowTarget target) => kinds.contains(target.kind),
      ),
      ...snapshot.topics.where(
        (FollowTarget target) => kinds.contains(target.kind),
      ),
      ...snapshot.publishers.where(
        (FollowTarget target) => kinds.contains(target.kind),
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
