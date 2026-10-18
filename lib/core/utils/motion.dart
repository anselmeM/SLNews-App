import 'package:flutter/widgets.dart';

/// Motion preferences resolved from the platform.
///
/// Animations that carry meaning still end in their final state, so honouring
/// "reduce motion" means shortening them to nothing rather than skipping the
/// state change.
bool preferReducedMotion(BuildContext context) {
  final MediaQueryData media =
      MediaQuery.maybeOf(context) ?? const MediaQueryData();
  return media.disableAnimations || media.accessibleNavigation;
}

/// [duration] when motion is welcome, [Duration.zero] when it is not.
Duration motionDuration(BuildContext context, Duration duration) =>
    preferReducedMotion(context) ? Duration.zero : duration;
