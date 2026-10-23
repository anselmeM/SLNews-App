import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography scale for SLNews.
///
/// The reference Samsung News screens use a neutral geometric grotesque with
/// tight tracking on headlines and generous line-height on article bodies.
/// SLNews ships Inter as a variable font under the family name `SLNewsSans`;
/// weights are selected through the `wght` axis so a single asset covers the
/// whole scale.
@immutable
class AppTypography {
  const AppTypography({
    required this.primaryText,
    required this.secondaryText,
    required this.tertiaryText,
    this.inverseText = const Color(0xFFFFFFFF),
  });

  /// Font family declared in `pubspec.yaml`.
  static const String fontFamily = 'SLNewsSans';

  /// Fallbacks keep text legible if the bundled face fails to load.
  static const List<String> fontFallback = <String>[
    'Roboto',
    'Helvetica Neue',
    'Arial',
  ];

  final Color primaryText;
  final Color secondaryText;
  final Color tertiaryText;
  final Color inverseText;

  static AppTypography of(BuildContext context) {
    final AppColors colors = context.colors;
    return AppTypography(
      primaryText: colors.onSurface,
      secondaryText: colors.onSurfaceVariant,
      tertiaryText: colors.onSurfaceFaint,
    );
  }

  /// Screen title, e.g. "Top stories" (34 / 700).
  TextStyle get screenTitle => _sans(
    size: 32,
    weight: 700,
    height: 1.15,
    tracking: -0.8,
    color: primaryText,
  );

  /// Section header inside a screen, e.g. "Cars and Vehicles" (24 / 700).
  TextStyle get sectionTitle => _sans(
    size: 22,
    weight: 700,
    height: 1.2,
    tracking: -0.5,
    color: primaryText,
  );

  /// Sub-section header, e.g. "Sports", "Locations" (19 / 700).
  TextStyle get groupTitle => _sans(
    size: 18,
    weight: 700,
    height: 1.25,
    tracking: -0.3,
    color: primaryText,
  );

  /// Card headline (19 / 700).
  TextStyle get cardTitle => _sans(
    size: 18,
    weight: 700,
    height: 1.28,
    tracking: -0.3,
    color: primaryText,
  );

  /// Smaller card headline used by dense list items (17 / 700).
  TextStyle get cardTitleSmall => _sans(
    size: 17,
    weight: 700,
    height: 1.3,
    tracking: -0.2,
    color: primaryText,
  );

  /// Headline drawn over a hero image (28 / 700).
  TextStyle get heroTitle => _sans(
    size: 28,
    weight: 700,
    height: 1.2,
    tracking: -0.6,
    color: inverseText,
  );

  /// Article reader headline (30 / 700).
  TextStyle get articleTitle => _sans(
    size: 30,
    weight: 700,
    height: 1.25,
    tracking: -0.7,
    color: primaryText,
  );

  /// Reader lead paragraph (19 / 500).
  TextStyle get lead =>
      _sans(size: 19, weight: 500, height: 1.5, color: secondaryText);

  /// Article body copy (17 / 400).
  TextStyle get body =>
      _sans(size: 17, weight: 400, height: 1.62, color: primaryText);

  /// Long-form caption / image credit (13 / 400).
  TextStyle get caption =>
      _sans(size: 13, weight: 400, height: 1.5, color: secondaryText);

  /// Publisher name, timestamps (13.5 / 500).
  TextStyle get meta =>
      _sans(size: 13.5, weight: 500, height: 1.35, color: secondaryText);

  /// Uppercase publisher wordmark (13 / 700, spaced).
  TextStyle get publisherMark => _sans(
    size: 13,
    weight: 700,
    height: 1.2,
    tracking: 0.4,
    color: primaryText,
  );

  /// Category pill label (15 / 600).
  TextStyle get chip =>
      _sans(size: 15, weight: 600, height: 1.2, color: primaryText);

  /// Bottom navigation label (12 / 600).
  TextStyle get navLabel =>
      _sans(size: 12, weight: 600, height: 1.2, color: secondaryText);

  /// Button label (15 / 600).
  TextStyle get button =>
      _sans(size: 15, weight: 600, height: 1.2, color: primaryText);

  /// Scoreboard numerals and team codes (16 / 700, tabular).
  TextStyle get score => _sans(
    size: 16,
    weight: 700,
    height: 1.2,
    color: primaryText,
  ).copyWith(fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]);

  /// Small overline label, e.g. "LIVE", "AD" (11 / 700).
  TextStyle get overline => _sans(
    size: 11,
    weight: 700,
    height: 1.2,
    tracking: 0.8,
    color: tertiaryText,
  );

  /// Material [TextTheme] assembled from the tokens above.
  TextTheme toTextTheme() => TextTheme(
    displayLarge: screenTitle,
    displayMedium: screenTitle,
    displaySmall: sectionTitle,
    headlineLarge: screenTitle,
    headlineMedium: sectionTitle,
    headlineSmall: groupTitle,
    titleLarge: cardTitle,
    titleMedium: cardTitleSmall,
    titleSmall: meta,
    bodyLarge: body,
    bodyMedium: meta,
    bodySmall: caption,
    labelLarge: button,
    labelMedium: chip,
    labelSmall: navLabel,
  );

  static TextStyle _sans({
    required double size,
    required int weight,
    required Color color,
    double? height,
    double? tracking,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      fontSize: size,
      fontWeight: _weightOf(weight),
      fontVariations: <FontVariation>[FontVariation('wght', weight.toDouble())],
      height: height,
      letterSpacing: tracking,
      color: color,
    );
  }

  static FontWeight _weightOf(int weight) {
    final int index = (weight ~/ 100) - 1;
    return FontWeight.values[index.clamp(0, FontWeight.values.length - 1)];
  }
}

/// Convenience accessors so widgets read `context.colors` / `context.typography`.
extension AppThemeContext on BuildContext {
  AppColors get colors => AppColors.of(Theme.of(this).brightness);

  AppTypography get typography => AppTypography.of(this);
}
