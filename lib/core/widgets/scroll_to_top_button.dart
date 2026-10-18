import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import 'fade_slide_in.dart';
import 'pressable_ink_well.dart';

/// Circular white "back to top" control from the reference reader/feed.
///
/// Shared by the tab pages (`SlPageScaffold`) and the article reader so the
/// affordance looks and behaves the same in both places.
class ScrollToTopButton extends StatelessWidget {
  const ScrollToTopButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  /// Distance scrolled before the button is worth showing.
  static const double threshold = 600;

  @override
  Widget build(BuildContext context) {
    // The button is inserted into the tree when the reader scrolls far enough;
    // this makes that arrival a rise instead of a pop.
    return FadeSlideIn(
      offset: 6,
      child: Semantics(
        button: true,
        label: 'Back to top',
        child: Material(
          color: context.colors.surface,
          shape: const CircleBorder(),
          elevation: 2,
          shadowColor: Colors.black26,
          child: PressableInkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.keyboard_arrow_up,
                size: 26,
                color: context.colors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
