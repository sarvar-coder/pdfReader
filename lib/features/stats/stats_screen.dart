import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ember/features/library/dummy_data.dart';
import 'package:ember/features/stats/widgets/heatmap.dart';
import 'package:ember/features/stats/widgets/stat_grid.dart';
import 'package:ember/theme/app_colors.dart';
import 'package:ember/widgets/ember_flame.dart';

/// The Stats screen: a big animated ember + streak number, a 2×2 stat grid, and
/// a quarter heatmap. Built against [DummyData] for now.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              'Keep the flame',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.18 * 11,
                color: AppColors.inkFaint,
              ),
            ),
          ),
          const _StreakHero(),
          const SizedBox(height: 22),
          StatGrid(
            stats: const [
              StatItem('${DummyData.minutesToday} min', 'Read today'),
              StatItem('${DummyData.pagesThisWeek}', 'Pages this week'),
              StatItem('${DummyData.booksFinished}', 'Books finished'),
              StatItem('${DummyData.hoursThisMonth} hrs', 'This month'),
            ],
          ),
          const SizedBox(height: 22),
          Heatmap(),
        ],
      ),
    );
  }
}

/// Big ember + streak number + "day streak · longest yet was N".
class _StreakHero extends StatelessWidget {
  const _StreakHero();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
      child: Column(
        children: [
          const EmberFlame(size: 96),
          const SizedBox(height: 18),
          Text(
            '${DummyData.streakDays}',
            style: GoogleFonts.fraunces(
              fontSize: 54,
              height: 1,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'day streak · longest yet was ${DummyData.longestStreak}',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
