import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slnews_mobile/core/theme/app_colors.dart';

/// WCAG relative luminance for an opaque colour.
double _luminance(Color color) {
  final int argb = color.toARGB32();
  double channel(int value) {
    final double c = value / 255;
    return c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  final double r = channel((argb >> 16) & 0xFF);
  final double g = channel((argb >> 8) & 0xFF);
  final double b = channel(argb & 0xFF);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrast(Color fg, Color bg) {
  final double a = _luminance(fg);
  final double b = _luminance(bg);
  final double hi = math.max(a, b);
  final double lo = math.min(a, b);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final MapEntry<String, AppColors> entry in <String, AppColors>{
    'light': AppColors.light,
    'dark': AppColors.dark,
  }.entries) {
    final String mode = entry.key;
    final AppColors colors = entry.value;

    test('$mode: body text meets 4.5:1 on canvas and surface', () {
      for (final Color background in <Color>[colors.canvas, colors.surface]) {
        expect(
          _contrast(colors.onSurface, background),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('$mode: secondary text meets 4.5:1 on surface', () {
      expect(
        _contrast(colors.onSurfaceVariant, colors.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('$mode: faint text is at least 3:1 on canvas', () {
      expect(
        _contrast(colors.onSurfaceFaint, colors.canvas),
        greaterThanOrEqualTo(3.0),
      );
    });
  }
}
