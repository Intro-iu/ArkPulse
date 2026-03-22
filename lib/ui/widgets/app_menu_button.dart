import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

class AppMenuEntry<T> {
  final T value;
  final String label;
  final IconData icon;

  const AppMenuEntry({
    required this.value,
    required this.label,
    required this.icon,
  });
}

class AppMenuButton<T> extends StatelessWidget {
  final bool highlighted;
  final List<AppMenuEntry<T>> items;
  final ValueChanged<T> onSelected;

  const AppMenuButton({
    super.key,
    required this.highlighted,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) async {
        final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
        final result = await showMenu<T>(
          context: context,
          position: RelativeRect.fromRect(
            Rect.fromLTWH(
              details.globalPosition.dx,
              details.globalPosition.dy,
              1,
              1,
            ),
            Offset.zero & overlay.size,
          ),
          color: SciFiColors.surfaceLight,
          shape: const RoundedRectangleBorder(
            side: BorderSide(color: SciFiColors.gridLines),
            borderRadius: BorderRadius.zero,
          ),
          items: items
              .map(
                (item) => PopupMenuItem<T>(
                  value: item.value,
                  height: 34,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        size: 15,
                        color: SciFiColors.primaryYel,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.label,
                        style: GoogleFonts.shareTechMono(
                          color: SciFiColors.textMain,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
        if (result != null) {
          onSelected(result);
        }
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          border: Border.all(
            color: highlighted ? SciFiColors.primaryYel : SciFiColors.gridLines,
          ),
        ),
        child: Icon(
          Icons.more_horiz,
          size: 18,
          color: highlighted ? SciFiColors.primaryYel : SciFiColors.textDim,
        ),
      ),
    );
  }
}
