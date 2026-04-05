import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'neo_brutalism/nb_decorations.dart';

/// A Neo-Brutalism global background grid
/// Features deep industrial colors, cross matrices, halftone dot clusters, and hazard stripes.
class TechGridBg extends StatelessWidget {
  final Widget child;

  const TechGridBg({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: Container(color: SciFiColors.background)),
        // Base global cross matrix
        Positioned.fill(
          child: NbDecorations.crossMatrix(
            color: SciFiColors.gridLines.withValues(alpha: 0.4),
            spacing: 80.0,
            size: 3.0,
          ),
        ),
        // Accidental halftone cluster at top right
        Positioned(
          top: -20,
          right: -20,
          width: 400,
          height: 400,
          child: Opacity(
            opacity: 0.6,
            child: NbDecorations.dotMatrix(
              color: SciFiColors.gridLines.withValues(alpha: 0.3),
              spacing: 8.0,
              size: 2.0,
            ),
          ),
        ),
        // Neon accent dot matrix
        Positioned(
          bottom: 120,
          left: 40,
          width: 120,
          height: 120,
          child: Opacity(
            opacity: 0.8,
            child: NbDecorations.dotMatrix(
              color: SciFiColors.primaryYelGlow.withValues(alpha: 0.2),
              spacing: 12.0,
              size: 2.5,
            ),
          ),
        ),
        // Hazard stripes acting as a footer floor
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 48,
          child: NbDecorations.hazardStripes(
            color: SciFiColors.gridLines.withValues(alpha: 0.15),
            strokeWidth: 4.0,
            spacing: 12.0,
          ),
        ),
        // Foreground Content
        child,
      ],
    );
  }
}
