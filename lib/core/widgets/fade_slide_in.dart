import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../utils/motion.dart';

/// One-shot entrance: the child fades in while rising a few pixels into place.
///
/// Used for content that arrives as a block - section headers, rails, the reader
/// header and its action bar - so a screen assembles instead of snapping. The
/// animation runs once, on mount; scroll rebuilds do not replay it. When the
/// platform asks for reduced motion the child is simply shown.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 10,
    this.duration = AppMotion.medium,
  });

  final Widget child;

  /// Stagger for lists; keep the total under ~120ms so nothing feels slow.
  final Duration delay;

  /// Vertical rise in logical pixels, from below.
  final double offset;

  final Duration duration;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> {
  bool _visible = false;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = preferReducedMotion(context);
    if (_reduced) {
      _visible = true;
      return;
    }
    if (_visible) return;
    if (widget.delay == Duration.zero) {
      // One frame at the start value, then animate: without this the implicit
      // animation would have no "from" state and snap into place.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _visible = true);
      });
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Duration duration = motionDuration(context, widget.duration);
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: duration,
      curve: AppMotion.standard,
      child: AnimatedSlide(
        offset: _visible || _reduced
            ? Offset.zero
            : Offset(0, widget.offset / 100),
        duration: duration,
        curve: AppMotion.standard,
        child: widget.child,
      ),
    );
  }
}
