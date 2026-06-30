import 'package:flutter/material.dart';

import 'package:ember/theme/app_colors.dart';

/// A small dark floating bar with the four highlight swatches. Shown over a
/// text selection; tapping a swatch saves a highlight in that color.
class SelectionToolbar extends StatelessWidget {
  const SelectionToolbar({super.key, this.onPick, this.onDismiss});

  /// Called with the chosen color when a swatch is tapped.
  final ValueChanged<Color>? onPick;

  /// Called when the dismiss button is tapped.
  final VoidCallback? onDismiss;

  static const List<Color> _swatches = [
    AppColors.hlYellow,
    AppColors.hlGreen,
    AppColors.hlBlue,
    AppColors.hlPink,
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF241C15),
      borderRadius: BorderRadius.circular(14),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final color in _swatches) ...[
              _Swatch(color: color, onTap: () => onPick?.call(color)),
              const SizedBox(width: 8),
            ],
            IconButton(
              onPressed: onDismiss,
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              icon: const Icon(Icons.close, color: Color(0xFFF4EBDD)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, this.onTap});

  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x40FFFFFF), width: 2),
        ),
      ),
    );
  }
}
