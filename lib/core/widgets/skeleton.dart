import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// An animated shimmering block used while a feed loads.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.sm)),
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final BoxShape shape;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color base = context.colors.skeleton;
    final Color highlight = context.colors.skeletonHighlight;
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.circle ? null : widget.borderRadius,
            color: Color.lerp(base, highlight, _controller.value),
          ),
        );
      },
    );
  }
}

/// Skeleton mirroring [ArticleTile]'s geometry.
class ArticleTileSkeleton extends StatelessWidget {
  const ArticleTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: context.colors.surface, borderRadius: AppRadius.cardRadius),
      padding: AppSpacing.card,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                SkeletonBox(width: 90, height: 14),
                SizedBox(height: AppSpacing.md),
                SkeletonBox(height: 18),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(height: 18),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(width: 160, height: 18),
                SizedBox(height: AppSpacing.xxl),
                SkeletonBox(width: 70, height: 12),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          const SkeletonBox(width: 120, height: 120, borderRadius: AppRadius.imageRadius),
        ],
      ),
    );
  }
}

/// Skeleton mirroring the For You hero card.
class HeroCardSkeleton extends StatelessWidget {
  const HeroCardSkeleton({super.key, this.height = 420});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(height: height, borderRadius: AppRadius.cardRadius);
  }
}
