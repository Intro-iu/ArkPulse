import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class SciFiColors {
  // Bright industrial background (Light dark gray)
  static const Color background = Color(0xFF1E2022);

  // Surfaces for modular panels
  static const Color surface = Color(0xFF2B2D31);
  static const Color surfaceLight = Color(0xFF383A40);

  // Primary accent: Neon Lime / Bright Yellow-Green
  static const Color primaryYel = Color(0xFFC0FA4D);
  static const Color primaryYelGlow = Color(0x33C0FA4D);

  // Text colors
  static const Color textMain = Color(0xFFF0F0F0);
  static const Color textDim = Color(0xFF8A8E9A);

  // Borders and framing
  static const Color gridLines = Color(0xFF404045);

  // Error colors
  static const Color errorRed = Color(0xFFFF5252);
}

class AppTheme {
  static ThemeData get industrialSciFi {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: SciFiColors.background,
      splashFactory: InkSparkle.splashFactory,
      hoverColor: SciFiColors.primaryYelGlow.withValues(alpha: 0.12),
      highlightColor: SciFiColors.primaryYelGlow.withValues(alpha: 0.08),
      colorScheme: const ColorScheme.dark(
        primary: SciFiColors.primaryYel,
        secondary: SciFiColors.primaryYelGlow,
        surface: SciFiColors.surface,
        error: SciFiColors.errorRed,
        onPrimary: SciFiColors.background,
        onSurface: SciFiColors.textMain,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: SciFiColors.surface,
        elevation: 0,
        centerTitle: false,
      ),
      iconTheme: const IconThemeData(color: SciFiColors.primaryYel),
      dividerTheme: const DividerThemeData(
        color: SciFiColors.gridLines,
        thickness: 1.0,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged) ||
              states.contains(WidgetState.hovered)) {
            return SciFiColors.primaryYel.withValues(alpha: 0.9);
          }
          return SciFiColors.textDim.withValues(alpha: 0.55);
        }),
        trackColor: WidgetStatePropertyAll(
          SciFiColors.surfaceLight.withValues(alpha: 0.45),
        ),
        thickness: const WidgetStatePropertyAll(8),
        radius: Radius.zero,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.mouse,
    PointerDeviceKind.touch,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return Scrollbar(
      controller: details.controller,
      thumbVisibility: true,
      interactive: true,
      child: child,
    );
  }
}
