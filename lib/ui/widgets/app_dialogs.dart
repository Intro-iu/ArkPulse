import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

class AppDialogShell extends StatelessWidget {
  final double width;
  final Widget child;

  const AppDialogShell({
    super.key,
    required this.child,
    this.width = 420,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: SciFiColors.surface,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: SciFiColors.gridLines),
        borderRadius: BorderRadius.zero,
      ),
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: child,
        ),
      ),
    );
  }
}

class AppDialogTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const AppDialogTitle({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: GoogleFonts.shareTechMono(
            color: SciFiColors.primaryYel,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.8,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: GoogleFonts.shareTechMono(
              color: SciFiColors.textDim,
              fontSize: 11,
              letterSpacing: 1.2,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

class AppDialogActions extends StatelessWidget {
  final String confirmLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final bool isLoading;

  const AppDialogActions({
    super.key,
    required this.confirmLabel,
    this.onCancel,
    this.onConfirm,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: isLoading ? null : onCancel,
          child: Text(
            'CANCEL',
            style: GoogleFonts.shareTechMono(
              color: SciFiColors.textDim,
            ),
          ),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: isLoading ? null : onConfirm,
          style: TextButton.styleFrom(
            backgroundColor: SciFiColors.primaryYelGlow,
            side: const BorderSide(color: SciFiColors.primaryYel),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: SciFiColors.primaryYel,
                  ),
                )
              : Text(
                  confirmLabel,
                  style: GoogleFonts.shareTechMono(
                    color: SciFiColors.primaryYel,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }
}

class AppConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;

  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDialogTitle(title: title),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.shareTechMono(
              color: SciFiColors.textDim,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          AppDialogActions(
            confirmLabel: confirmLabel,
            onCancel: () => Navigator.of(context).pop(false),
            onConfirm: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}
