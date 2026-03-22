import 'package:flutter/material.dart';
import 'package:arkpulse/theme/app_theme.dart';

/// A static futuristic HUD base grid without distracting looping animations.
/// Integrates small halftone clusters and sparse data markers.
class TechGridBg extends StatelessWidget {
  final Widget child;

  const TechGridBg({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _StaticHudGridPainter())),
        child,
      ],
    );
  }
}

class _StaticHudGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dark Base Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = SciFiColors.background,
    );

    var paintCross = Paint()
      ..color = SciFiColors.textDim.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;

    double gridSpacing = 80.0;
    double crossSize = 3.0;

    // 2. Draw Sparse Tracking Crosses
    for (double x = 0; x < size.width; x += gridSpacing) {
      for (double y = 0; y < size.height; y += gridSpacing) {
        canvas.drawLine(
          Offset(x, y - crossSize),
          Offset(x, y + crossSize),
          paintCross,
        );
        canvas.drawLine(
          Offset(x - crossSize, y),
          Offset(x + crossSize, y),
          paintCross,
        );
      }
    }

    // 3. Draw Halftone Clusters (Top Right, Bottom Left)
    _drawHalftoneBlock(
      canvas,
      Offset(size.width - 200, 60),
      10,
      5,
      SciFiColors.gridLines.withValues(alpha: 0.3),
    );
    _drawHalftoneBlock(
      canvas,
      Offset(60, size.height - 120),
      4,
      12,
      SciFiColors.primaryYelGlow.withValues(alpha: 0.1),
    );

    // 4. Draw HUD Border Framing (Thin geometric bounds)
    var framePaint = Paint()
      ..color = SciFiColors.gridLines.withValues(alpha: 0.4)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Top border bracket
    canvas.drawLine(
      const Offset(40, 40),
      Offset(size.width * 0.3, 40),
      framePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.3, 40),
      Offset(size.width * 0.3 + 20, 20),
      framePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.3 + 20, 20),
      Offset(size.width - 40, 20),
      framePaint,
    );
  }

  void _drawHalftoneBlock(
    Canvas canvas,
    Offset origin,
    int cols,
    int rows,
    Color color,
  ) {
    var paint = Paint()..color = color;
    double spacing = 6.0;
    for (int i = 0; i < cols; i++) {
      for (int j = 0; j < rows; j++) {
        // Skip some to make it look fragmented or structural
        if ((i + j) % 7 == 0) continue;
        canvas.drawCircle(
          Offset(origin.dx + (i * spacing), origin.dy + (j * spacing)),
          1.2,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
