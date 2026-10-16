import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/domain/models/notification_item.dart';
import 'package:slnews_mobile/core/domain/repositories/notification_repository.dart';
import 'package:slnews_mobile/core/providers/app_providers.dart';
import 'package:slnews_mobile/core/providers/controllers.dart';
import 'package:slnews_mobile/core/theme/app_theme.dart';
import 'package:slnews_mobile/features/following/presentation/widgets/notification_history_row.dart';

import 'support/fakes.dart';

/// Widget tests for the notification history screen
/// (`/following/notifications`).
void main() {
  late FollowingTestFixture fixture;
  late ProviderContainer container;

  /// Builds a container with the given notification repository, replacing (and
  /// disposing) the one from [setUp].
  ProviderContainer containerWith(NotificationRepository repository) {
    container.dispose();
    container = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(repository),
        followingRepositoryProvider.overrideWithValue(fixture.following),
      ],
    );
    return container;
  }

  setUp(() {
    fixture = FollowingTestFixture();
    container = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWithValue(fixture.notifications),
        // The test router's initial location is the nested history route, but
        // `FollowingPage` still mounts as the parent branch page.
        followingRepositoryProvider.overrideWithValue(fixture.following),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          // The history screen is a nested route: reach it through the tab
          // branch so the router has a real stack to pop back to.
          routerConfig: buildFollowingTestRouter(initialLocation: '/following/notifications'),
        ),
      ),
    );
    // The nested route builds one frame behind the widget insertion and the
    // alert history resolves on a microtask, so settle both.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('renders the seeded alerts with date headers and unread state',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpPage(tester);

    expect(find.text('Notification history'), findsOneWidget);
    expect(find.text('Mark all read'), findsOneWidget);
    expect(find.text('Breaking: Sierra Leone budget passed'), findsOneWidget);
    expect(find.text('Lakers win again'), findsOneWidget);
    expect(find.text('Freetown weather alert'), findsOneWidget);

    // Two alerts are unread, one is already read.
    expect(container.read(notificationsControllerProvider.notifier).unreadCount, 2);

    // Two alerts arrived today, one yesterday: two inline date headers.
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
  });

  testWidgets('tapping a row marks it read and clears its unread dot',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpPage(tester);

    expect(fixture.notifications.unreadCount, 2);

    await tester.tap(find.text('Lakers win again'));
    await tester.pump();
    await tester.pump();

    // The fake recorded the read and recomputed its unread count.
    expect(fixture.notifications.markReadLog, contains('n2'));
    expect(fixture.notifications.unreadCount, 1);
    expect(container.read(notificationsControllerProvider.notifier).unreadCount, 1);

    // The row's unread dot is gone: one of the three seeded alerts is still
    // unread, so exactly one row renders as unread.
    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is NotificationHistoryRow && !widget.item.isRead,
      ),
      findsOneWidget,
    );
    expect(find.byType(NotificationHistoryRow), findsNWidgets(3));
  });

  testWidgets('an alert that links to a story pushes the reader route',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpPage(tester);

    await tester.tap(find.text('Breaking: Sierra Leone budget passed'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(fixture.notifications.markReadLog, contains('n1'));
    expect(find.text('article-stub:article-1'), findsOneWidget);
  });

  testWidgets('an empty history shows the empty state', (WidgetTester tester) async {
    containerWith(InMemoryNotificationRepository(<NotificationItem>[]));

    await pumpPage(tester);

    expect(find.text('No alerts yet'), findsOneWidget);
    expect(find.text('Breaking news alerts you receive will appear here.'), findsOneWidget);
  });

  testWidgets('a failing repository shows the error state', (WidgetTester tester) async {
    containerWith(_FailingNotificationRepository());

    await pumpPage(tester);

    expect(find.text("We couldn't load your alerts."), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}

/// Repository whose history always fails, to exercise the error branch.
class _FailingNotificationRepository implements NotificationRepository {
  @override
  Future<List<NotificationItem>> history({int limit = 30}) async {
    throw StateError('offline');
  }

  @override
  List<NotificationItem> get cachedHistory => const <NotificationItem>[];

  @override
  Future<void> record(NotificationItem item) async {}

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead() async {}

  @override
  int get unreadCount => 0;
}
