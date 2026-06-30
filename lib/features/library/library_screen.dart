import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ember/features/library/dummy_data.dart';
import 'package:ember/features/library/widgets/continue_card.dart';
import 'package:ember/features/library/widgets/shelf_grid.dart';
import 'package:ember/features/library/widgets/streak_card.dart';
import 'package:ember/theme/app_colors.dart';

/// The Library screen: greeting header, streak card, continue-reading card,
/// and the shelf grid. Built against [DummyData] for now.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, this.onOpenReader, this.onOpenStats});

  /// Opens the Reader (continue card / shelf book tap).
  final VoidCallback? onOpenReader;

  /// Opens the Stats screen (streak card tap).
  final VoidCallback? onOpenStats;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 96),
        children: [
          const _Header(),
          StreakCard(onTap: onOpenStats),
          const _SectionHeader(title: 'Continue reading'),
          ContinueCard(
            book: DummyData.continueReading,
            onTap: onOpenReader,
          ),
          const _SectionHeader(title: 'On the shelf', action: 'Sort'),
          ShelfGrid(
            books: DummyData.shelf,
            onOpenBook: (_) => onOpenReader?.call(),
            onAddPdf: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pick a PDF from Files / Drive')),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good evening, reader',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.18 * 11,
              color: AppColors.inkFaint,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your shelf',
            style: GoogleFonts.fraunces(
              fontSize: 30,
              height: 1.05,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '3 books in progress · 41 on the shelf',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final String? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 26, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.fraunces(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          if (action != null)
            Text(
              action!,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.emberDeep,
              ),
            ),
        ],
      ),
    );
  }
}
