import 'package:flutter/widgets.dart';

/// Spacing, radius and elevation tokens.
///
/// The reference UI is a 4pt grid with generous 16pt page gutters, 16pt card
/// radii and a 12pt gap between feed cards.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Horizontal page gutter.
  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: lg);

  /// Standard card inner padding.
  static const EdgeInsets card = EdgeInsets.all(lg);

  /// Padding for list rows inside a card group.
  static const EdgeInsets row = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: 14,
  );
}

/// Corner radii.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;

  /// Fully rounded (pills, chips, avatars).
  static const double pill = 999;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius imageRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(pill),
  );
}

/// Motion tokens: short, decelerating, never bouncy.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration medium = Duration(milliseconds: 240);
  static const Curve standard = Curves.easeOutCubic;
}
