import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'pressable_ink_well.dart';

/// Outlined "Follow" / filled "Following" pill used across the following
/// sections, the sports teams list and article publisher attribution.
class FollowChip extends StatelessWidget {
  const FollowChip({
    super.key,
    required this.isFollowing,
    required this.onPressed,
    this.followLabel = 'Follow',
    this.followingLabel = 'Following',
    this.dense = false,
  });

  final bool isFollowing;
  final VoidCallback? onPressed;
  final String followLabel;
  final String followingLabel;

  /// Smaller metrics for in-card usage.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final Color border = isFollowing
        ? context.colors.divider
        : context.colors.onSurface;
    final Color background = isFollowing
        ? context.colors.surfaceMuted
        : Colors.transparent;
    return Semantics(
      button: true,
      toggled: isFollowing,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.pillRadius,
          side: BorderSide(color: border),
        ),
        child: PressableInkWell(
          onTap: onPressed,
          borderRadius: AppRadius.pillRadius,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: dense ? AppSpacing.md : AppSpacing.xl,
              vertical: dense ? AppSpacing.xs + 2 : AppSpacing.sm,
            ),
            child: Text(
              isFollowing ? followingLabel : followLabel,
              style: context.typography.button.copyWith(
                fontSize: dense ? 13 : 15,
                color: isFollowing
                    ? context.colors.onSurfaceVariant
                    : context.colors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
