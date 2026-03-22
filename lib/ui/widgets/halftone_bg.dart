import 'package:flutter/material.dart';
import 'package:arkpulse/theme/app_theme.dart';

class HalftoneBg extends StatelessWidget {
  final Widget child;
  final double dotSize;
  final double spacing;
  final Color dotColor;

  const HalftoneBg({
    super.key,
    required this.child,
    this.dotSize = 1.0,
    this.spacing = 8.0,
    this.dotColor = SciFiColors.gridLines,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _HalftonePainter(
              dotSize: dotSize,
              spacing: spacing,
              dotColor: dotColor,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _HalftonePainter extends CustomPainter {
  final double dotSize;
  final double spacing;
  final Color dotColor;

  _HalftonePainter({
    required this.dotSize,
    required this.spacing,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    // Draw dots every [spacing] pixels
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        // Optional: reduce dot size towards the edge or keep uniform
        canvas.drawCircle(Offset(x, y), dotSize, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HalftonePainter oldDelegate) {
    return oldDelegate.dotSize != dotSize ||
        oldDelegate.spacing != spacing ||
        oldDelegate.dotColor != dotColor;
  }
}
