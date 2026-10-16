import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The inline like affordance used by every feed card and by the reader bar.
///
/// Filled blue thumb when liked, thin outline otherwise, with a short pop so
/// the state change is visible without a snackbar.
class LikeButton extends StatelessWidget {
  const LikeButton({
    super.key,
    required this.isLiked,
    this.onPressed,
    this.size = 20,
    this.semanticLabel,
  });

  final bool isLiked;
  final VoidCallback? onPressed;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Color active = context.colors.primary;
    final Color idle = context.colors.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: isLiked,
      label: semanticLabel ?? (isLiked ? 'Unlike' : 'Like'),
      child: InkResponse(
        onTap: onPressed,
        radius: size + AppSpacing.sm,
        child: AnimatedScale(
          scale: isLiked ? 1.08 : 1,
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Icon(
              isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
              size: size,
              color: isLiked ? active : idle,
            ),
          ),
        ),
      ),
    );
  }
}
