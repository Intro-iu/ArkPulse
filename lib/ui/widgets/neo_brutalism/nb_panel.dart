import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'dart:ui' as dart_ui;

/// A flat, industrial structural panel.
/// Flat design, NO shadows.
class NbPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool hasShadow; // Kept for API compatibility, ignored.
  final bool isFrosted;
  final DecorationImage? bgImage;
  final Offset shadowOffset; // Kept for API compatibility, ignored.

  const NbPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24.0),
    this.width,
    this.height,
    this.backgroundColor,
    this.borderColor,
    this.hasShadow = false,
    this.isFrosted = false,
    this.bgImage,
    this.shadowOffset = Offset.zero,
  });

  @override
  Widget build(BuildContext context) {
    BoxDecoration contentDecoration = BoxDecoration(
      color:
          backgroundColor ??
          (isFrosted
              ? SciFiColors.surface.withValues(alpha: 0.8)
              : SciFiColors.surfaceLight),
      border: Border.all(
        color: borderColor ?? SciFiColors.gridLines.withValues(alpha: 0.5),
        width: 1.0,
      ),
      image: bgImage,
    );

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: contentDecoration,
      child: child,
    );

    if (isFrosted) {
      content = ClipRect(
        child: BackdropFilter(
          filter: dart_ui.ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: content,
        ),
      );
    }

    return content;
  }
}
