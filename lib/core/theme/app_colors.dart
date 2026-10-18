import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

/// Colour tokens for SLNews, sampled from the Samsung News reference screens.
///
/// The palette is intentionally neutral: a soft grey canvas, pure white cards
/// and near-black type, with a single saturated blue accent used for the
/// active tab, the like state and primary actions.
@immutable
class AppColors {
  const AppColors({
    required this.brightness,
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceInverse,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.onSurfaceFaint,
    required this.onSurfaceInverse,
    required this.divider,
    required this.primary,
    required this.onPrimary,
    required this.accentGradientStart,
    required this.accentGradientEnd,
    required this.skeleton,
    required this.skeletonHighlight,
    required this.overlayScrim,
    required this.live,
    required this.trendUp,
    required this.trendDown,
  });

  final Brightness brightness;

  /// Page background behind cards (`#F1F1F1` light / `#000000` dark).
  final Color canvas;

  /// Card and sheet background.
  final Color surface;

  /// Subtle fill for pills, thumbnail placeholders and score tiles.
  final Color surfaceMuted;

  /// High-contrast fill (used by the selected category pill).
  final Color surfaceInverse;

  /// Primary text colour.
  final Color onSurface;

  /// Secondary text: timestamps, "Powered by", captions.
  final Color onSurfaceVariant;

  /// Tertiary text: meta labels, ad legal copy.
  final Color onSurfaceFaint;

  /// Text drawn on top of [surfaceInverse].
  final Color onSurfaceInverse;

  /// Hairline separators.
  final Color divider;

  /// SLNews / Samsung-style blue accent.
  final Color primary;

  final Color onPrimary;

  /// Fill for the inline ad unit.
  final Color accentGradientStart;
  final Color accentGradientEnd;

  /// Offline placeholder blocks.
  final Color skeleton;
  final Color skeletonHighlight;

  /// Scrim painted over hero images so white headlines stay legible.
  final Color overlayScrim;

  /// "LIVE" / breaking marker.
  final Color live;

  /// Positive market move (green) and negative move (red).
  final Color trendUp;
  final Color trendDown;

  static const AppColors light = AppColors(
    brightness: Brightness.light,
    canvas: Color(0xFFF1F1F1),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF4F4F4),
    surfaceInverse: Color(0xFF111111),
    onSurface: Color(0xFF111111),
    onSurfaceVariant: Color(0xFF6B6B6B),
    onSurfaceFaint: Color(0xFF9A9A9A),
    onSurfaceInverse: Color(0xFFFFFFFF),
    divider: Color(0xFFE6E6E6),
    primary: Color(0xFF0381FE),
    onPrimary: Color(0xFFFFFFFF),
    accentGradientStart: Color(0xFF2E9BF5),
    accentGradientEnd: Color(0xFF0B6FD1),
    skeleton: Color(0xFFE7E7E7),
    skeletonHighlight: Color(0xFFF5F5F5),
    overlayScrim: Color(0x99000000),
    live: Color(0xFFE03B3B),
    trendUp: Color(0xFF17864B),
    trendDown: Color(0xFFC62828),
  );

  static const AppColors dark = AppColors(
    brightness: Brightness.dark,
    canvas: Color(0xFF000000),
    surface: Color(0xFF171717),
    surfaceMuted: Color(0xFF232323),
    surfaceInverse: Color(0xFFFFFFFF),
    onSurface: Color(0xFFF5F5F5),
    onSurfaceVariant: Color(0xFFA6A6A6),
    onSurfaceFaint: Color(0xFF7A7A7A),
    onSurfaceInverse: Color(0xFF111111),
    divider: Color(0xFF2C2C2C),
    primary: Color(0xFF4C9CFF),
    onPrimary: Color(0xFF06121F),
    accentGradientStart: Color(0xFF1E63B0),
    accentGradientEnd: Color(0xFF0B3F73),
    skeleton: Color(0xFF242424),
    skeletonHighlight: Color(0xFF303030),
    overlayScrim: Color(0xB3000000),
    live: Color(0xFFFF6B6B),
    trendUp: Color(0xFF4ADE80),
    trendDown: Color(0xFFF87171),
  );

  static AppColors of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
