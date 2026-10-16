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
  const FollowTarget koidu = FollowTarget(
    id: 'city:koidu',
    kind: FollowKind.location,
    label: 'Koidu',
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
      expect(viewModel.locations, isEmpty);
      expect(viewModel.popularLocations, isEmpty);
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
      expect(viewModel.locations.map((FollowTarget t) => t.id), <String>[
        'city:freetown',
      ]);
      expect(viewModel.topics.map((FollowTarget t) => t.id), <String>[
        'topic:politics',
      ]);
      expect(viewModel.hasAnyGroup, isTrue);
    });

    test('merges the per-kind catalogues with the flat followed list', () {
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
        'Arsenal',
        'Los Angeles Lakers',
      ]);
      expect(viewModel.locations.single.label, 'Freetown');
      expect(viewModel.topics.single.label, 'Politics');
    });

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
      expect(viewModel.locations.map((FollowTarget t) => t.label), <String>[
        'Bo',
        'Freetown',
      ]);
    });

    test(
      'popular suggestions exclude followed locations and non-location kinds',
      () {
        const FollowingViewModel viewModel = FollowingViewModel(
          snapshot: FollowingSnapshot(
            followed: <FollowTarget>[freetown],
            suggested: <FollowTarget>[freetown, bo, koidu, lakers, politics],
          ),
        );

        expect(
          viewModel.popularLocations.map((FollowTarget t) => t.id),
          <String>['city:bo', 'city:koidu'],
        );
      },
    );

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
