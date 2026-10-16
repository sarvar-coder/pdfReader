import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ember/theme/app_colors.dart';

/// One headline number + label, e.g. "38 min" / "Read today".
class StatItem {
  const StatItem(this.value, this.label);

  final String value;
  final String label;
}

/// A 2×2 grid of stat cards.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.stats});

  final List<StatItem> stats;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      // Zero, not the default: under the shell's extendBody the inherited
      // padding holds the nav bar's height and opens a gap below the grid.
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.7,
      children: [for (final stat in stats) _StatCard(stat: stat)],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final StatItem stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
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
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stat.value,
            style: GoogleFonts.fraunces(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            stat.label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
