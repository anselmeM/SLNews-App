import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/models/notification_item.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import 'widgets/notification_history_row.dart';

/// Notification history (`/following/notifications`).
///
/// Alerts are rendered newest first under inline date headers ("Today",
/// "Yesterday", then a `shortDateLabel`). Tapping a row marks it read and, when
/// the alert carries an `articleId`, opens the reader.
class NotificationHistoryPage extends ConsumerWidget {
  const NotificationHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<NotificationItem>> notifications = ref.watch(
      notificationsControllerProvider,
    );

    return Scaffold(
      backgroundColor: context.colors.canvas,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: context.colors.canvas,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
              onPressed: () => context.pop(),
            ),
            title: Text('Notification history', style: context.typography.groupTitle),
            actions: <Widget>[
              TextButton(
                onPressed: () => ref.read(notificationsControllerProvider.notifier).markAllRead(),
                child: const Text('Mark all read'),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
          ..._body(context, ref, notifications),
        ],
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<NotificationItem>> notifications,
  ) {
    if (notifications.isLoading && !notifications.hasValue) {
      return const <Widget>[
        SliverPadding(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          sliver: SliverToBoxAdapter(child: _HistorySkeleton()),
        ),
      ];
    }

    if (notifications.hasError && !notifications.hasValue) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorStateView(
            message: "We couldn't load your alerts.",
            onRetry: () => ref.invalidate(notificationsControllerProvider),
          ),
        ),
      ];
    }

    final List<NotificationItem> items = notifications.value ?? const <NotificationItem>[];
    if (items.isEmpty) {
      return const <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyStateView(
            title: 'No alerts yet',
            message: 'Breaking news alerts you receive will appear here.',
            icon: Icons.notifications_none,
          ),
        ),
      ];
    }

    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        sliver: SliverList.list(children: _rows(context, ref, items)),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
    ];
  }

  /// A plain list with an inline date header whenever the day changes — no
  /// sticky-header machinery, which the reference screen does not need.
  List<Widget> _rows(BuildContext context, WidgetRef ref, List<NotificationItem> items) {
    final List<NotificationItem> sorted = List<NotificationItem>.of(items)
      ..sort((NotificationItem a, NotificationItem b) => b.receivedAt.compareTo(a.receivedAt));

    final List<Widget> rows = <Widget>[];
    String? currentHeader;
    for (int index = 0; index < sorted.length; index++) {
      final NotificationItem item = sorted[index];
      final String header = item.receivedAt.toLocal().shortDateLabel;
      if (header != currentHeader) {
        currentHeader = header;
        rows.add(_DateHeader(label: header, isFirst: index == 0));
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: AppRadius.cardRadius,
            ),
            child: ClipRRect(
              borderRadius: AppRadius.cardRadius,
              child: NotificationHistoryRow(
                item: item,
                onTap: (NotificationItem tapped) => _open(context, ref, tapped),
              ),
            ),
          ),
        ),
      );
    }
    return rows;
  }

  Future<void> _open(BuildContext context, WidgetRef ref, NotificationItem item) async {
    await ref.read(notificationsControllerProvider.notifier).markRead(item.id);
    if (!context.mounted) return;
    final String? articleId = item.articleId;
    if (articleId == null || articleId.isEmpty) return;
    await context.push(AppRoutes.articleFor(articleId));
  }
}

/// Inline date separator between alert groups.
class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.label, required this.isFirst});

  final String label;

  /// The first header sits directly under the app bar and needs less air.
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xs,
        isFirst ? AppSpacing.sm : AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Text(label, style: context.typography.overline),
    );
  }
}

/// Loading placeholder mirroring the alert-row geometry.
class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int index = 0; index < 4; index++) ...<Widget>[
          if (index > 0) const SizedBox(height: AppSpacing.md),
          const _SkeletonRow(),
        ],
      ],
    );
  }
}

/// A single skeleton card shaped like an alert row.
class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: const Padding(
        padding: AppSpacing.row,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SkeletonBox(height: 16),
            SizedBox(height: AppSpacing.md),
            SkeletonBox(height: 12),
            SizedBox(height: AppSpacing.sm),
            SkeletonBox(width: 80, height: 12),
          ],
        ),
      ),
    );
  }
}
