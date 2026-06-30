import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ember/features/stats/widgets/heatmap.dart';
import 'package:ember/features/stats/widgets/stat_grid.dart';
import 'package:ember/providers/stats_provider.dart';
import 'package:ember/theme/app_colors.dart';
import 'package:ember/widgets/ember_flame.dart';

/// The Stats screen: a big animated ember + streak number, a 2×2 stat grid, and
/// a quarter heatmap. Reads from [statsProvider].
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
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
          _StreakHero(
            streakDays: stats.streakDays,
            longestStreak: stats.longestStreak,
          ),
          const SizedBox(height: 22),
          StatGrid(
            stats: [
              StatItem('${stats.minutesToday} min', 'Read today'),
              StatItem('${stats.pagesThisWeek}', 'Pages this week'),
              StatItem('${stats.booksFinished}', 'Books finished'),
              StatItem('${stats.hoursThisMonth} hrs', 'This month'),
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
  const _StreakHero({required this.streakDays, required this.longestStreak});

  final int streakDays;
  final int longestStreak;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
      child: Column(
        children: [
          const EmberFlame(size: 96),
          const SizedBox(height: 18),
          Text(
            '$streakDays',
            style: GoogleFonts.fraunces(
              fontSize: 54,
              height: 1,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'day streak · longest yet was $longestStreak',
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
