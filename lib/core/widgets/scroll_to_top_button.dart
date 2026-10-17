import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

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
    return Semantics(
      button: true,
      label: 'Back to top',
      child: Material(
        color: context.colors.surface,
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: Colors.black26,
        child: InkWell(
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
    );
  }
}
