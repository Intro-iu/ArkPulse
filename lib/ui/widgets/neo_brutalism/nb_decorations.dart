import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Neo-Brutalist structural layout prints (Stripes, Halftones, and Cross Matrices)
class NbDecorations {
  static Widget dotMatrix({
    Color? color,
    double spacing = 12.0,
    double size = 1.5,
  }) {
    return CustomPaint(
      painter: _DotMatrixPainter(
        color: color ?? SciFiColors.gridLines,
        spacing: spacing,
        size: size,
      ),
      child: Container(),
    );
  }

  static Widget crossMatrix({
    Color? color,
    double spacing = 40.0,
    double size = 4.0,
  }) {
    return CustomPaint(
      painter: _CrossMatrixPainter(
        color: color ?? SciFiColors.gridLines,
        spacing: spacing,
        size: size,
      ),
      child: Container(),
    );
  }

  static Widget hazardStripes({
    Color? color,
    double strokeWidth = 8.0,
    double spacing = 16.0,
  }) {
    return CustomPaint(
      painter: _CautionStripePainter(
        color: color ?? SciFiColors.gridLines.withValues(alpha: 0.3),
        strokeWidth: strokeWidth,
        spacing: spacing,
      ),
      child: Container(),
    );
  }
}

class _DotMatrixPainter extends CustomPainter {
  final Color color;
  final double spacing;
  final double size;

  _DotMatrixPainter({
    required this.color,
    required this.spacing,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (double x = 0; x < canvasSize.width; x += spacing) {
      for (double y = 0; y < canvasSize.height; y += spacing) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset(x, y), width: size, height: size),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotMatrixPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.spacing != spacing ||
        oldDelegate.size != size;
  }
}

class _CrossMatrixPainter extends CustomPainter {
  final Color color;
  final double spacing;
  final double size;

  _CrossMatrixPainter({
    required this.color,
    required this.spacing,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    for (double x = 0; x < canvasSize.width; x += spacing) {
      for (double y = 0; y < canvasSize.height; y += spacing) {
        // Vertical line
        canvas.drawLine(Offset(x, y - size), Offset(x, y + size), paint);
        // Horizontal line
        canvas.drawLine(Offset(x - size, y), Offset(x + size, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CrossMatrixPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.spacing != spacing ||
        oldDelegate.size != size;
  }
}

class _CautionStripePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double spacing;

  _CautionStripePainter({
    required this.color,
    required this.strokeWidth,
    required this.spacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // Draw diagonal stripes (45 degrees) moving from bottom-left offset to top-right
    double start = -size.height;
    double end = size.width;
    for (double x = start; x < end; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CautionStripePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.spacing != spacing;
  }
}
