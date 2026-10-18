import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/motion.dart';

/// Fraction of the article that has been read.
///
/// Split out from the widget so the arithmetic (and its degenerate cases: no
/// scroll extent, over-scroll bounce, a controller that is not attached yet) is
/// testable without a scroll view.
double readingProgressFor(ScrollController controller) {
  if (!controller.hasClients) return 0;
  final double max = controller.position.maxScrollExtent;
  if (max <= 0) return 0;
  return (controller.offset / max).clamp(0.0, 1.0);
}

/// Hairline progress indicator pinned under the reader's app bar.
///
/// It stays invisible until the reader scrolls, so the article's first screen
/// keeps the reference's clean header, and it shrinks away again at 100 %.
class ReadingProgressBar extends StatelessWidget {
  const ReadingProgressBar({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final double value = progress.clamp(0.0, 1.0);
    final int percent = (value * 100).round();
    return Semantics(
      container: true,
      label: 'Reading progress',
      value: '$percent%',
      child: ExcludeSemantics(
        child: AnimatedOpacity(
          opacity: value > 0 ? 1 : 0,
          duration: motionDuration(context, AppMotion.fast),
          curve: AppMotion.standard,
          child: SizedBox(
            height: 2,
            child: LinearProgressIndicator(
              value: value,
              minHeight: 2,
              backgroundColor: Colors.transparent,
              color: context.colors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
