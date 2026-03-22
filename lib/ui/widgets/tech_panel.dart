import 'package:flutter/material.dart';
import 'package:arkpulse/theme/app_theme.dart';

/// A sleek, strict 90-degree rectangular sci-fi panel.
/// Fast, straight vertical entrance animation. No diagonals, no rounded corners.
class TechPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Duration delay;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool isActive;
  final double? width;
  final double? height;

  const TechPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.delay = Duration.zero,
    this.backgroundColor,
    this.borderColor,
    this.isActive = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (delay == Duration.zero) {
      return _buildContainer();
    }

    // Fast straight vertical slide animation
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutQuad,
      builder: (context, value, _) {
        return Transform.translate(
          offset: Offset(0, 15 * (1 - value)),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: _buildContainer(),
          ),
        );
      },
    );
  }

  Widget _buildContainer() {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? SciFiColors.surface,
        border: Border.all(
          color:
              borderColor ??
              (isActive ? SciFiColors.primaryYel : SciFiColors.gridLines),
          width: 1.0,
        ),
      ),
      child: child,
    );
  }
}
