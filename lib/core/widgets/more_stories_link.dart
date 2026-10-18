import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'pressable_ink_well.dart';

/// Right-aligned "More … stories ›" link that closes a group of stories.
///
/// The reference ends every group in a feed or section with one of these instead
/// of relying only on the header chevron, so the reader who reached the bottom of
/// the list still has the way forward next to their thumb.
class MoreStoriesLink extends StatelessWidget {
  const MoreStoriesLink({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: PressableInkWell(
          onTap: onPressed,
          borderRadius: AppRadius.pillRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs + 2,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: context.typography.meta.copyWith(
                    color: context.colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: context.colors.onSurface,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
