import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// A tiny trend line for a quote's session.
///
/// The reference draws the last day's closes behind each board row; a plain
/// polyline is all that is needed for the 56px it gets, and it keeps the widget
/// dependency-free (no chart package).
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.points,
    required this.isUp,
    this.width = 56,
    this.height = 22,
    this.strokeWidth = 1.6,
  });

  final List<double> points;
  final bool isUp;
  final double width;
  final double height;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return SizedBox(width: width, height: height);
    final AppColors colors = context.colors;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(
          points: points,
          color: isUp ? colors.trendUp : colors.trendDown,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  final List<double> points;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    double min = points.first;
    double max = points.first;
    for (final double point in points) {
      if (point < min) min = point;
      if (point > max) max = point;
    }
    final double span = (max - min) == 0 ? 1 : max - min;
    final double stepX = size.width / (points.length - 1);

    final Path path = Path();
    for (int index = 0; index < points.length; index++) {
      final double x = stepX * index;
      // Invert Y: a higher close sits higher on the canvas.
      final double y =
          size.height - ((points[index] - min) / span) * size.height;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
