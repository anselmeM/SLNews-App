import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/motion.dart';

/// The inline like affordance used by every feed card and by the reader bar.
///
/// Filled thumb when liked, thin outline otherwise. A tap is acknowledged in two
/// beats: the icon cross-fades to the new state, and the whole button gives a
/// short spring - enough to feel the change without a snackbar.
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
    final Duration switchDuration = motionDuration(context, AppMotion.fast);

    return Semantics(
      button: true,
      selected: isLiked,
      label: semanticLabel ?? (isLiked ? 'Unlike' : 'Like'),
      child: InkResponse(
        onTap: onPressed,
        radius: size + AppSpacing.sm,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 1, end: isLiked ? 1.16 : 1),
          duration: motionDuration(context, AppMotion.medium),
          curve: Curves.easeOutBack,
          builder: (BuildContext context, double scale, Widget? child) =>
              Transform.scale(scale: scale, child: child),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: AnimatedSwitcher(
              duration: switchDuration,
              switchInCurve: AppMotion.standard,
              switchOutCurve: AppMotion.standard,
              transitionBuilder: (Widget child, Animation<double> animation) =>
                  ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
              child: Icon(
                isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                key: ValueKey<bool>(isLiked),
                size: size,
                color: isLiked ? active : idle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
