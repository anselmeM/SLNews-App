import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/follow_models.dart';
import 'package:slnews_mobile/core/domain/models/notification_item.dart';
import 'package:slnews_mobile/features/following/presentation/viewmodels/following_view_model.dart';

/// Unit tests for the pure-Dart derivation behind the Following tab.
void main() {
  const FollowTarget lakers = FollowTarget(
    id: 'team:lal',
    kind: FollowKind.team,
    label: 'Los Angeles Lakers',
  );
  const FollowTarget arsenal = FollowTarget(
    id: 'team:ars',
    kind: FollowKind.league,
    label: 'Arsenal',
  );
  const FollowTarget freetown = FollowTarget(
    id: 'city:freetown',
    kind: FollowKind.location,
    label: 'Freetown',
  );
  const FollowTarget bo = FollowTarget(
    id: 'city:bo',
    kind: FollowKind.location,
    label: 'Bo',
    isPopular: true,
  );
  const FollowTarget politics = FollowTarget(
    id: 'topic:politics',
    kind: FollowKind.topic,
    label: 'Politics',
  );

  NotificationItem alert({required String id, bool isRead = false}) =>
      NotificationItem(
        id: id,
        title: 'Alert $id',
        body: 'Body',
        receivedAt: DateTime(2026, 10, 15, 12),
        kind: NotificationKind.breaking,
        isRead: isRead,
      );

  group('FollowingViewModel', () {
    test('an empty snapshot yields empty groups and no unread badge', () {
      const FollowingViewModel viewModel = FollowingViewModel(
        snapshot: FollowingSnapshot.empty(),
      );

      expect(viewModel.sports, isEmpty);
      expect(viewModel.topics, isEmpty);
      expect(viewModel.publishers, isEmpty);
      expect(viewModel.unreadNotifications, isZero);
      expect(viewModel.hasUnreadNotifications, isFalse);
      expect(viewModel.hasAnyGroup, isFalse);
    });

    test('groups followed entities by kind', () {
      const FollowingViewModel viewModel = FollowingViewModel(
        snapshot: FollowingSnapshot(
          followed: <FollowTarget>[politics, lakers, freetown],
          suggested: <FollowTarget>[],
        ),
      );

      expect(viewModel.sports.map((FollowTarget t) => t.id), <String>[
        'team:lal',
      ]);
      expect(viewModel.topics.map((FollowTarget t) => t.id), <String>[
        'topic:politics',
      ]);
      expect(viewModel.hasAnyGroup, isTrue);
    });

    test('catalogue entries that are not followed stay out of the groups', () {
      const FollowingViewModel viewModel = FollowingViewModel(
        snapshot: FollowingSnapshot(
          followed: <FollowTarget>[lakers],
          suggested: <FollowTarget>[],
          sports: <FollowTarget>[lakers, arsenal],
          locations: <FollowTarget>[freetown],
          topics: <FollowTarget>[politics],
        ),
      );

      expect(viewModel.sports.map((FollowTarget t) => t.label), <String>[
        'Los Angeles Lakers',
      ]);
      expect(viewModel.topics, isEmpty);
    });

    test(
      'a full catalogue with nothing followed renders no followed groups',
      () {
        const FollowingViewModel viewModel = FollowingViewModel(
          snapshot: FollowingSnapshot(
            followed: <FollowTarget>[],
            suggested: <FollowTarget>[],
            sports: <FollowTarget>[lakers, arsenal],
            locations: <FollowTarget>[freetown],
            topics: <FollowTarget>[politics],
          ),
        );

        expect(viewModel.sports, isEmpty);
        expect(viewModel.topics, isEmpty);
        expect(viewModel.hasAnyGroup, isFalse);
      },
    );

    test('keeps the first occurrence of a duplicated id', () {
      const FollowTarget duplicateLakers = FollowTarget(
        id: 'team:lal',
        kind: FollowKind.team,
        label: 'LAL',
      );
      const FollowingViewModel viewModel = FollowingViewModel(
        snapshot: FollowingSnapshot(
          followed: <FollowTarget>[lakers, duplicateLakers],
          suggested: <FollowTarget>[],
          sports: <FollowTarget>[duplicateLakers, lakers],
        ),
      );

      expect(viewModel.sports, hasLength(1));
      expect(viewModel.sports.single.label, 'Los Angeles Lakers');
    });

    test('sorts every group alphabetically, ignoring case', () {
      const FollowTarget zebras = FollowTarget(
        id: 'team:zeb',
        kind: FollowKind.team,
        label: 'zebras',
      );
      const FollowingViewModel viewModel = FollowingViewModel(
        snapshot: FollowingSnapshot(
          followed: <FollowTarget>[zebras, freetown, bo, arsenal, politics],
          suggested: <FollowTarget>[],
        ),
      );

      expect(viewModel.sports.map((FollowTarget t) => t.label), <String>[
        'Arsenal',
        'zebras',
      ]);
      expect(viewModel.topics.map((FollowTarget t) => t.label), <String>[
        'Politics',
      ]);
    });

    test('suggested topics keep the repository ranking and drop followed ones', () {
      const FollowTarget music = FollowTarget(
        id: 'topic:music',
        kind: FollowKind.topic,
        label: 'Music',
        isPopular: true,
      );
      const FollowTarget business = FollowTarget(
        id: 'topic:business',
        kind: FollowKind.topic,
        label: 'Business',
      );
      const FollowingViewModel viewModel = FollowingViewModel(
        snapshot: FollowingSnapshot(
          followed: <FollowTarget>[politics],
          // Popular first, then alphabetical: the view model must not re-sort.
          suggested: <FollowTarget>[music, politics, business],
        ),
      );

      expect(viewModel.suggestedTopics.map((FollowTarget t) => t.id), <String>[
        'topic:music',
        'topic:business',
      ]);
    });

    test('counts unread notifications only', () {
      final FollowingViewModel viewModel = FollowingViewModel(
        snapshot: const FollowingSnapshot.empty(),
        notifications: <NotificationItem>[
          alert(id: 'a'),
          alert(id: 'b'),
          alert(id: 'c', isRead: true),
        ],
      );

      expect(viewModel.unreadNotifications, 2);
      expect(viewModel.hasUnreadNotifications, isTrue);
    });

    test('an all-read history has no badge', () {
      final FollowingViewModel viewModel = FollowingViewModel(
        snapshot: const FollowingSnapshot.empty(),
        notifications: <NotificationItem>[alert(id: 'a', isRead: true)],
      );

      expect(viewModel.unreadNotifications, isZero);
      expect(viewModel.hasUnreadNotifications, isFalse);
    });
  });
}
