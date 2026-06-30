import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ember/theme/app_colors.dart';

/// A quarter heatmap: a 13-column grid of cells with five intensity levels.
/// Filled with random levels for now (no real session data yet).
class Heatmap extends StatelessWidget {
  Heatmap({super.key, this.cellCount = 91});

  final int cellCount;

  /// Level 0 → 4 colors (0 = empty), matching the mockup's legend.
  static const List<Color> _levelColors = [
    AppColors.card2,
    Color(0xFFF3DCBF),
    Color(0xFFEEB988),
    Color(0xFFE08A45),
    Color(0xFFC75A22),
  ];

  // Fixed seed so the random fill is stable across rebuilds.
  final Random _rng = Random(7);

  int _level() {
    final r = _rng.nextDouble();
    if (r > 0.82) return 4;
    if (r > 0.6) return 3;
    if (r > 0.4) return 2;
    if (r > 0.22) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11281E12),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This quarter',
            style: GoogleFonts.fraunces(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cellCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 13,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, _) => DecoratedBox(
              decoration: BoxDecoration(
                color: _levelColors[_level()],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _Legend(),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final label = GoogleFonts.inter(fontSize: 11, color: AppColors.inkFaint);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('Less', style: label),
        const SizedBox(width: 6),
        for (final color in Heatmap._levelColors) ...[
          _LegendCell(color: color),
          const SizedBox(width: 6),
        ],
        Text('More', style: label),
      ],
    );
  }
}

class _LegendCell extends StatelessWidget {
  const _LegendCell({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
