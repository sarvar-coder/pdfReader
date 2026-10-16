import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ember/theme/app_colors.dart';

/// A quarter heatmap: a 13-column grid of cells, one per day, painted by their
/// 0–4 intensity [levels] (derived from recorded reading minutes).
class Heatmap extends StatelessWidget {
  const Heatmap({super.key, required this.levels});

  /// One 0–4 level per day, oldest first; length sets the number of cells.
  final List<int> levels;

  /// Level 0 → 4 colors (0 = empty), matching the mockup's legend.
  static const List<Color> _levelColors = [
    AppColors.card2,
    Color(0xFFF3DCBF),
    Color(0xFFEEB988),
    Color(0xFFE08A45),
    Color(0xFFC75A22),
  ];

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
            padding: EdgeInsets.zero, // see StatGrid
            physics: const NeverScrollableScrollPhysics(),
            itemCount: levels.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 13,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, i) => DecoratedBox(
              decoration: BoxDecoration(
                color: _levelColors[levels[i].clamp(0, 4)],
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
