import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/page_dots.dart';

/// A snap-to-card horizontal carousel with page dots underneath.
///
/// This is the "Top stories" behaviour the reference repeats for its service
/// sections: a `PageView` (not a scrolling list) so each card snaps into place,
/// with the next one peeking at the edge and dots reporting the position. The
/// For You page uses it for the lead stories, sports and stocks so the three
/// behave identically.
class PagedCarousel extends StatefulWidget {
  const PagedCarousel({
    super.key,
    required this.itemCount,
    required this.height,
    required this.itemBuilder,
    this.viewportFraction = 0.94,
    this.showDots = true,
  });

  final int itemCount;
  final double height;
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// 0.94 leaves a sliver of the neighbouring card visible, as in the reference.
  final double viewportFraction;

  final bool showDots;

  @override
  State<PagedCarousel> createState() => _PagedCarouselState();
}

class _PagedCarouselState extends State<PagedCarousel> {
  late final PageController _controller = PageController(
    viewportFraction: widget.viewportFraction,
  );
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.itemCount,
            onPageChanged: (int page) => setState(() => _page = page),
            itemBuilder: (BuildContext context, int index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: widget.itemBuilder(context, index),
            ),
          ),
        ),
        if (widget.showDots && widget.itemCount > 1)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: PageDots(count: widget.itemCount, index: _page),
          ),
      ],
    );
  }
}
