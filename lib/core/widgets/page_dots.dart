import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Page indicator under a paged carousel: one dot per page, the active one wider.
///
/// The reference uses the same dots under the lead carousel and under the
/// service sections, so this lives in the design system rather than inside a
/// single carousel.
class PageDots extends StatelessWidget {
  const PageDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Page ${index + 1} of $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (int dot = 0; dot < count; dot++)
            AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.standard,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: dot == index ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: dot == index
                    ? context.colors.onSurface
                    : context.colors.onSurfaceFaint,
                borderRadius: AppRadius.pillRadius,
              ),
            ),
        ],
      ),
    );
  }
}
