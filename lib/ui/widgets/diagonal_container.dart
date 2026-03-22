import 'package:flutter/material.dart';
import 'package:arkpulse/theme/app_theme.dart';

/// A container with diagonal clipped corners (chamfered) mimicking machined sci-fi panels.
class DiagonalContainer extends StatelessWidget {
  final Widget child;
  final double cutSize;
  final Color backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry padding;
  final bool hasTopLeftCut;
  final bool hasBottomRightCut;

  const DiagonalContainer({
    super.key,
    required this.child,
    this.cutSize = 12.0,
    this.backgroundColor = SciFiColors.surface,
    this.borderColor,
    this.borderWidth = 1.0,
    this.padding = const EdgeInsets.all(16.0),
    this.hasTopLeftCut = true,
    this.hasBottomRightCut = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SciFiBorderPainter(
        cutSize: cutSize,
        borderColor: borderColor ?? SciFiColors.gridLines,
        backgroundColor: backgroundColor,
        borderWidth: borderWidth,
        hasTopLeftCut: hasTopLeftCut,
        hasBottomRightCut: hasBottomRightCut,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _SciFiBorderPainter extends CustomPainter {
  final double cutSize;
  final Color borderColor;
  final Color backgroundColor;
  final double borderWidth;
  final bool hasTopLeftCut;
  final bool hasBottomRightCut;

  _SciFiBorderPainter({
    required this.cutSize,
    required this.borderColor,
    required this.backgroundColor,
    required this.borderWidth,
    required this.hasTopLeftCut,
    required this.hasBottomRightCut,
  });

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path();
    var w = size.width;
    var h = size.height;

    // Top-left
    if (hasTopLeftCut) {
      path.moveTo(cutSize, 0);
    } else {
      path.moveTo(0, 0);
    }

    // Top-right
    path.lineTo(w, 0);

    // Bottom-right
    if (hasBottomRightCut) {
      path.lineTo(w, h - cutSize);
      path.lineTo(w - cutSize, h);
    } else {
      path.lineTo(w, h);
    }

    // Bottom-left
    path.lineTo(0, h);

    // Back to Top-left
    if (hasTopLeftCut) {
      path.lineTo(0, cutSize);
      path.lineTo(cutSize, 0);
    } else {
      path.lineTo(0, 0);
    }

    // Fill
    final paintFill = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paintFill);

    // Stroke
    if (borderWidth > 0) {
      final paintStroke = Paint()
        ..color = borderColor
        ..strokeWidth = borderWidth
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, paintStroke);
    }
  }

  @override
  bool shouldRepaint(covariant _SciFiBorderPainter oldDelegate) {
    return oldDelegate.cutSize != cutSize ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor;
  }
}
