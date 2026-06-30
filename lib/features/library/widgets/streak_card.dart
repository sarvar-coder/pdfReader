import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ember/providers/stats_provider.dart';
import 'package:ember/widgets/ember_flame.dart';

/// Dark gradient card showing the reading streak: a flickering ember, the day
/// count, and a row of week dots (lit days + today outlined). Tapping it opens
/// the Stats screen.
class StreakCard extends ConsumerWidget {
  const StreakCard({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF2A211A), Color(0xFF241C15), Color(0xFF1D160F)],
            stops: [0, 0.6, 1],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reading streak',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.16 * 11,
                color: const Color(0xFFC8A98A),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const EmberFlame(size: 62),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${stats.streakDays}',
                      style: GoogleFonts.fraunces(
                        fontSize: 40,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFF4EBDD),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'days in a row',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFC8A98A),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                _WeekDots(days: stats.weekDots),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The seven-day strip: lit days use a warm gradient, "today" (the most recent
/// lit day) is outlined.
class _WeekDots extends StatelessWidget {
  const _WeekDots({required this.days});

  final List<bool> days;

  @override
  Widget build(BuildContext context) {
    final todayIndex = days.lastIndexOf(true);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const SizedBox(width: 7),
          Container(
            width: 9,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: days[i] ? null : const Color(0x1FFFFFFF),
              gradient: days[i]
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFF7A94E), Color(0xFFD8551D)],
                    )
                  : null,
              border: i == todayIndex
                  ? Border.all(color: const Color(0xFFF4EBDD), width: 2)
                  : null,
            ),
          ),
        ],
      ],
    );
  }
}

