import 'package:flutter/material.dart';

import '../../../core/widgets/header_actions.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/models/app_settings.dart';
import '../../../core/domain/models/follow_models.dart';
import '../../../core/domain/models/notification_item.dart';
import '../../../core/domain/models/notification_preferences.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_glyphs.dart';
import '../../../core/widgets/follow_chip.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/sl_page_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/account_card.dart';
import 'viewmodels/following_view_model.dart';
import 'widgets/follow_row.dart';
import 'widgets/follow_section.dart';

part 'following_sections.dart';

/// Tab 4 — Following (`/following`).
///
/// Follows the reference screen's shape: the history entry, then one card group
/// per subscription kind (Sports, Locations, Topics, Sources) with a tappable
/// section header that opens the matching catalogue, plus the two suggestion
/// groups ("Most popular with users", "Based on what you follow") whose rows
/// carry Follow chips.
///
/// Followed rows are deliberately chip-less, as in the reference: the row names
/// the subscription and tapping it opens that team, league, topic section or
/// location; subscribing and unsubscribing happen in the catalogue screens.
class FollowingPage extends ConsumerWidget {
  const FollowingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FollowingSnapshot snapshot = ref.watch(followingControllerProvider);
    final AsyncValue<List<NotificationItem>> notifications = ref.watch(
      notificationsControllerProvider,
    );
    final AppSettings settings = ref.watch(settingsControllerProvider);

    final FollowingViewModel viewModel = FollowingViewModel(
      snapshot: snapshot,
      // Categories the reader switched off in Settings are hidden here too, so
      // the badge cannot advertise alerts the history page will not show.
      notifications: visibleNotifications(
        notifications.value ?? const <NotificationItem>[],
        settings,
      ),
      hasError: snapshot is AsyncError<FollowingSnapshot>,
      isLoading: notifications.isLoading,
    );

    return SlPageScaffold(
      title: 'Following',
      actions: const <Widget>[HeaderActions()],
      onRefresh: () async {
        await ref.read(refreshFeedsProvider)();
        await ref.read(notificationsControllerProvider.notifier).reload();
      },
      slivers: <Widget>[
        // Account first: the reference app keeps one obvious identity surface,
        // and signing in is what makes saved stories and alerts portable.
        const SliverToBoxAdapter(child: AccountCard()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: _NotificationHistoryEntry(
              unreadCount: viewModel.unreadNotifications,
            ),
          ),
        ),
        ..._groupSlivers(context, ref, viewModel),
      ],
    );
  }
}

/// Full-width card row linking to the notification history.
class _NotificationHistoryEntry extends StatelessWidget {
  const _NotificationHistoryEntry({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(AppRoutes.notificationHistory),
        child: Padding(
          padding: AppSpacing.row,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Notification history',
                  style: context.typography.groupTitle,
                ),
              ),
              if (unreadCount > 0) ...<Widget>[
                Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.primary,
                    borderRadius: AppRadius.pillRadius,
                  ),
                  child: Text(
                    '$unreadCount',
                    textAlign: TextAlign.center,
                    style: context.typography.overline.copyWith(
                      color: context.colors.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Icon(
                Icons.chevron_right,
                size: 22,
                color: context.colors.onSurfaceFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading placeholder mirroring the grouped-rows geometry.
///
/// The subscription catalogue hydrates synchronously, so this covers the
/// first-frame window while the alert history (the pending async call) resolves.
class _FollowingSkeleton extends StatelessWidget {
  const _FollowingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SkeletonBox(width: 110, height: 22),
        const SizedBox(height: AppSpacing.md),
        for (int index = 0; index < 3; index++) ...<Widget>[
          if (index > 0) const SizedBox(height: AppSpacing.md),
          const SkeletonBox(height: 44, borderRadius: AppRadius.cardRadius),
        ],
        const SizedBox(height: AppSpacing.xl),
        const SkeletonBox(width: 130, height: 22),
        const SizedBox(height: AppSpacing.md),
        const SkeletonBox(height: 44, borderRadius: AppRadius.cardRadius),
      ],
    );
  }
}
