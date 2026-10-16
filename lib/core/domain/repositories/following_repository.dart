import '../models/follow_models.dart';

/// The reader's subscriptions: sports teams, leagues, locations and topics.
abstract interface class FollowingRepository {
  /// Current subscriptions plus the suggestion catalogue, grouped for display.
  FollowingSnapshot load();

  /// Subscribes to [target] and returns the updated snapshot.
  Future<FollowingSnapshot> follow(FollowTarget target);

  /// Removes a subscription by id and returns the updated snapshot.
  Future<FollowingSnapshot> unfollow(String targetId);

  /// Convenience toggle used by the Follow chips.
  Future<FollowingSnapshot> toggle(FollowTarget target);

  bool isFollowed(String targetId);
}
