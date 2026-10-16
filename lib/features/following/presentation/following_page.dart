import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/models/follow_models.dart';
import '../../../core/domain/models/notification_item.dart';
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

/// Tab 4 — Following (`/following`).
///
/// Reproduces the reference screen: a full-width "Notification history" entry
/// with an unread badge, then the reader's subscriptions grouped into Sports,
/// Locations, "Most popular with users" and Topics. Every group is a white card
/// whose rows end in a `FollowChip` wired to the single
/// `followingControllerProvider`, so following a suggestion in one group is
/// reflected in its own group immediately.
class FollowingPage extends ConsumerWidget {
  const FollowingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FollowingSnapshot snapshot = ref.watch(followingControllerProvider);
    final AsyncValue<List<NotificationItem>> notifications = ref.watch(
      notificationsControllerProvider,
    );

    final FollowingViewModel viewModel = FollowingViewModel(
      snapshot: snapshot,
      notifications: notifications.value ?? const <NotificationItem>[],
      hasError: snapshot is AsyncError<FollowingSnapshot>,
      isLoading: notifications.isLoading,
    );

    return SlPageScaffold(
      title: 'Following',
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

  /// Builds the four subscription groups plus their empty/error states.
  ///
  /// `followingControllerProvider` is a synchronous `NotifierProvider`, so its
  /// value is available on the first frame and there is no loading branch. A
  /// repository failure is reported by the controller as an `AsyncError`, which
  /// the error card's retry button recovers from via `ref.invalidate`.
  List<Widget> _groupSlivers(
    BuildContext context,
    WidgetRef ref,
    FollowingViewModel viewModel,
  ) {
    if (viewModel.hasError) {
      return <Widget>[
        SliverPadding(
          padding: AppSpacing.page,
          sliver: SliverToBoxAdapter(
            child: ErrorStateView(
              message: "We couldn't load what you follow.",
              onRetry: () => ref.invalidate(followingControllerProvider),
            ),
          ),
        ),
      ];
    }

    if (viewModel.isLoading && !viewModel.hasError) {
      return const <Widget>[
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            0,
          ),
          sliver: SliverToBoxAdapter(child: _FollowingSkeleton()),
        ),
      ];
    }

    if (!viewModel.hasAnyGroup) {
      return const <Widget>[
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: EmptyStateView(
              title: 'Nothing followed yet',
              message:
                  'Follow teams, places and topics to build your own feed.',
              icon: Icons.add_circle_outline,
            ),
          ),
        ),
      ];
    }

    final List<Widget> slivers = <Widget>[
      _sliverSection(
        header: SectionHeader(
          title: FollowKind.team.sectionLabel,
          onTap: () => context.go(AppRoutes.sports),
        ),
        child: FollowSection(
          targets: viewModel.sports,
          rowBuilder: (BuildContext context, FollowTarget target) =>
              _followedRow(
                context,
                ref,
                target,
                leadingIcon: AppGlyphs.follow(target.kind),
              ),
        ),
      ),
      _sliverSection(
        header: const SectionHeader(title: 'Locations'),
        child: FollowSection(
          targets: viewModel.locations,
          rowBuilder: (BuildContext context, FollowTarget target) =>
              _followedRow(
                context,
                ref,
                target,
                leadingIcon: AppGlyphs.follow(FollowKind.location),
                invertCircle: true,
              ),
        ),
      ),
    ];

    if (viewModel.popularLocations.isNotEmpty) {
      slivers.add(
        _sliverSection(
          header: const FollowGroupLabel(label: 'Most popular with users'),
          child: FollowSection(
            targets: viewModel.popularLocations,
            rowBuilder: (BuildContext context, FollowTarget target) =>
                _suggestedRow(context, ref, target),
          ),
        ),
      );
    }

    slivers.add(
      _sliverSection(
        header: SectionHeader(
          title: 'Topics',
          onTap: () => context.go(AppRoutes.news),
        ),
        child: FollowSection(
          targets: viewModel.topics,
          rowBuilder: (BuildContext context, FollowTarget target) =>
              _topicRow(context, ref, target),
        ),
      ),
    );

    return slivers;
  }

  Widget _sliverSection({required Widget header, required Widget child}) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[header, child],
        ),
      ),
    );
  }

  /// Row for the Sports and Locations groups: crest (or glyph circle), label and
  /// a `FollowChip` that unfollows on tap.
  Widget _followedRow(
    BuildContext context,
    WidgetRef ref,
    FollowTarget target, {
    required IconData leadingIcon,
    bool invertCircle = false,
  }) {
    final bool hasImage =
        target.imageUrl != null && target.imageUrl!.trim().isNotEmpty;
    final bool inverted = invertCircle && !hasImage;
    return FollowRow(
      label: target.label,
      subtitle: target.subtitle,
      imageUrl: target.imageUrl,
      leadingIcon: hasImage ? null : leadingIcon,
      backgroundColor: inverted ? context.colors.surfaceInverse : null,
      foregroundColor: inverted ? context.colors.onSurfaceInverse : null,
      trailing: _semanticChip(
        label: 'Unfollow ${target.label}',
        child: FollowChip(
          isFollowing: true,
          onPressed: () => _toggle(context, ref, target),
        ),
      ),
    );
  }

  /// Row for "Most popular with users": outlined chip that follows the
  /// suggestion, which also removes it from this list on the next frame.
  Widget _suggestedRow(
    BuildContext context,
    WidgetRef ref,
    FollowTarget target,
  ) {
    return FollowRow(
      label: target.label,
      subtitle: target.subtitle,
      imageUrl: target.imageUrl,
      leadingIcon: AppGlyphs.follow(target.kind),
      trailing: _semanticChip(
        label: 'Follow ${target.label}',
        child: FollowChip(
          isFollowing: false,
          onPressed: () => _toggle(context, ref, target),
        ),
      ),
    );
  }

  /// Topics group: the whole row toggles follow (chevron affordance) and the
  /// trailing dense chip mirrors the state.
  Widget _topicRow(BuildContext context, WidgetRef ref, FollowTarget target) {
    final bool isFollowing = ref
        .watch(followingControllerProvider)
        .isFollowed(target.id);
    return FollowRow(
      label: target.label,
      subtitle: target.subtitle,
      imageUrl: target.imageUrl,
      leadingIcon: AppGlyphs.follow(FollowKind.topic),
      backgroundColor: context.colors.surfaceInverse,
      foregroundColor: context.colors.onSurfaceInverse,
      onTap: () => _toggle(context, ref, target),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _semanticChip(
            label: '${isFollowing ? 'Unfollow' : 'Follow'} ${target.label}',
            child: FollowChip(
              isFollowing: isFollowing,
              dense: true,
              onPressed: () => _toggle(context, ref, target),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(
            Icons.chevron_right,
            size: 22,
            color: context.colors.onSurfaceFaint,
          ),
        ],
      ),
    );
  }

  /// The frozen `FollowChip` takes no semantic label, so the row names the
  /// action for screen readers here.
  Widget _semanticChip({required String label, required Widget child}) {
    return Semantics(button: true, label: label, child: child);
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    FollowTarget target,
  ) async {
    await ref.read(followingControllerProvider.notifier).toggle(target);
    if (!context.mounted) return;
    final bool isFollowing = ref
        .read(followingControllerProvider)
        .isFollowed(target.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${isFollowing ? 'Following' : 'Unfollowed'} ${target.label}',
          ),
          duration: const Duration(seconds: 2),
        ),
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
