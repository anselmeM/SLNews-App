import 'package:flutter/material.dart';

import '../../../../core/domain/models/follow_models.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/follow_chip.dart';
import '../viewmodels/sports_view_model.dart';
import 'team_crest.dart';

/// Horizontally scrolling row of the reader's followed teams and leagues.
///
/// Each entry is a 48pt circular crest with its short code underneath, exactly
/// like the reference "LAL" chip. Navigation is injected through [onTap] and
/// [onEmptyTap] so the widget stays free of routing concerns.
class FollowedTeamsRow extends StatelessWidget {
  const FollowedTeamsRow({
    super.key,
    required this.targets,
    this.onTap,
    this.onEmptyTap,
  });

  /// Followed sports entities, in the order derived by [SportsViewModel].
  final List<FollowTarget> targets;

  /// Called with the tapped entity.
  final ValueChanged<FollowTarget>? onTap;

  /// Called from the empty-state prompt; the page routes to `/following`.
  final VoidCallback? onEmptyTap;

  @override
  Widget build(BuildContext context) {
    if (targets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: <Widget>[
            FollowChip(
              isFollowing: false,
              onPressed: onEmptyTap,
              followLabel: 'Follow a team',
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Follow a team to see its news and fixtures here.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.typography.caption,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: targets.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: AppSpacing.lg),        itemBuilder: (BuildContext context, int index) {
          final FollowTarget target = targets[index];
          final String label = SportsViewModel.shortLabel(target);
          return Semantics(
            button: true,
            label: '${target.label}, followed ${target.kind.name}',
            child: InkWell(
              onTap: onTap == null ? null : () => onTap!(target),
              borderRadius: AppRadius.cardRadius,
              child: SizedBox(
                width: 64,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    TeamCrest.forTarget(target, size: 48),
                    const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: context.typography.overline.copyWith(
                        color: context.colors.onSurface,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
