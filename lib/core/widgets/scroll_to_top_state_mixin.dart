import 'package:flutter/material.dart';

/// Shared scroll-to-top lifecycle for full-page scroll views.
///
/// Three screens previously copied the same controller/listener/dispose block
/// and drifted on the threshold/progress rules. A widget opts in with
/// [showScrollToTopButton] and may override [readingProgress] to add a progress
/// bar without duplicating the listener.
mixin ScrollToTopStateMixin<T extends StatefulWidget> on State<T> {
  final ScrollController scrollController = ScrollController();
  bool showScrollToTopButton = false;
  double scrollProgress = 0;

  /// Offset after which the floating button appears.
  double get scrollToTopThreshold;

  /// Whether [readingProgress] should be recomputed on every scroll event.
  bool get tracksReadingProgress => false;

  /// Current reading progress in the range 0..1 for pages that show it.
  double readingProgress(ScrollController controller) => 0;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    scrollController.removeListener(_handleScroll);
    scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final bool visible =
        scrollController.hasClients &&
        scrollController.offset > scrollToTopThreshold;

    if (!tracksReadingProgress) {
      if (visible != showScrollToTopButton) {
        setState(() => showScrollToTopButton = visible);
      }
      return;
    }

    final double progress = readingProgress(scrollController);
    // Only rebuild when the hairline actually moves by a visible amount.
    final bool progressChanged = (progress - scrollProgress).abs() > 0.005;
    if (visible != showScrollToTopButton || progressChanged) {
      setState(() {
        showScrollToTopButton = visible;
        scrollProgress = progress;
      });
    }
  }

  Future<void> scrollToTop() async {
    if (!scrollController.hasClients) return;
    await scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }
}
