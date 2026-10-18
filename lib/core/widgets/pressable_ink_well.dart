import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../utils/motion.dart';

/// An `InkWell` that also dips under the finger.
///
/// The theme disables the splash (`NoSplash.splashFactory`), so without this a
/// tap on a card produced no feedback at all. The scale runs on a raw
/// [Listener] rather than a gesture recogniser, which keeps the tap itself with
/// the InkWell: this cannot win or lose the gesture arena against it.
class PressableInkWell extends StatefulWidget {
  const PressableInkWell({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.customBorder,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;

  /// How far the surface dips. Cards use 0.97; small chips use less.
  final double scale;

  @override
  State<PressableInkWell> createState() => _PressableInkWellState();
}

class _PressableInkWellState extends State<PressableInkWell> {
  bool _pressed = false;

  bool get _interactive => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (!_interactive || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: motionDuration(context, AppMotion.fast),
        curve: AppMotion.standard,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          borderRadius: widget.borderRadius,
          customBorder: widget.customBorder,
          child: widget.child,
        ),
      ),
    );
  }
}
