import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// A flat, high-contrast industrial button.
/// Flat design, NO shadows, NO glaring fills.
class NbButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? hoverColor;
  final Color? borderColor;
  final bool isPulsing;
  final EdgeInsetsGeometry padding;
  final Offset shadowOffset; // Kept for API compatibility, ignored.

  const NbButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.hoverColor,
    this.borderColor,
    this.isPulsing = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
    this.shadowOffset = Offset.zero,
  });

  @override
  State<NbButton> createState() => _NbButtonState();
}

class _NbButtonState extends State<NbButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.onPressed == null;

    final baseBg = widget.backgroundColor ?? SciFiColors.surface;
    final hoverBg =
        widget.hoverColor ??
        (baseBg == Colors.transparent
            ? SciFiColors.primaryYelGlow.withValues(alpha: 0.1)
            : Color.lerp(baseBg, Colors.white, 0.06)!);

    Widget coreButton = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: isDisabled
            ? SciFiColors.surfaceLight
            : (_isHovered ? hoverBg : baseBg),
        border: Border.all(
          color:
              widget.borderColor ??
              (isDisabled
                  ? SciFiColors.gridLines
                  : (_isHovered
                        ? SciFiColors.primaryYel
                        : SciFiColors.gridLines.withValues(alpha: 0.5))),
          width: 1.0,
        ),
      ),
      child: widget.child,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: coreButton,
      ),
    );
  }
}
