import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds the SLNews [ThemeData] for light and dark mode.
///
/// The Material defaults are deliberately flattened — no elevation tint, no
/// ripples on cards, hairline dividers — so the UI stays close to the
/// Samsung News reference.
abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light);

  static ThemeData dark() => _build(AppColors.dark);

  static ThemeData _build(AppColors colors) {
    final AppTypography typography = AppTypography(
      primaryText: colors.onSurface,
      secondaryText: colors.onSurfaceVariant,
      tertiaryText: colors.onSurfaceFaint,
    );

    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: colors.primary,
          brightness: colors.brightness,
        ).copyWith(
          primary: colors.primary,
          onPrimary: colors.onPrimary,
          surface: colors.surface,
          onSurface: colors.onSurface,
          onSurfaceVariant: colors.onSurfaceVariant,
          outlineVariant: colors.divider,
          error: colors.live,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.canvas,
      canvasColor: colors.canvas,
      dividerColor: colors.divider,
      splashFactory: NoSplash.splashFactory,
      textTheme: typography.toTextTheme(),
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: AppTypography.fontFallback,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: typography.screenTitle,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      ),
      // Menus sit on the page surface, not on Material 3's tinted container:
      // the reference keeps the kebab menu the same white as the app bar, and the
      // M3 default (`surfaceContainer`) reads as grey beside it.
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        textStyle: typography.button,
      ),
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: colors.onSurface, size: 22),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedItemColor: colors.onSurface,
        unselectedItemColor: colors.onSurfaceFaint,
        selectedLabelStyle: typography.navLabel.copyWith(
          color: colors.onSurface,
        ),
        unselectedLabelStyle: typography.navLabel.copyWith(
          color: colors.onSurfaceFaint,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((
          Set<WidgetState> states,
        ) {
          final Color color = states.contains(WidgetState.selected)
              ? colors.onSurface
              : colors.onSurfaceFaint;
          return typography.navLabel.copyWith(color: color);
        }),
        iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          final Color color = states.contains(WidgetState.selected)
              ? colors.onSurface
              : colors.onSurfaceFaint;
          return IconThemeData(color: color, size: 24);
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.surfaceInverse,
          foregroundColor: colors.onSurfaceInverse,
          textStyle: typography.button,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.pillRadius,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.onSurface,
          textStyle: typography.button,
          side: BorderSide(color: colors.onSurface),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.pillRadius,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.onSurface,
          textStyle: typography.button,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surface,
        selectedColor: colors.surfaceInverse,
        side: BorderSide(color: colors.divider),
        labelStyle: typography.chip,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillRadius),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.primary),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceInverse,
        contentTextStyle: typography.meta.copyWith(
          color: colors.onSurfaceInverse,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
