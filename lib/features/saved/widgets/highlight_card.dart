import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ember/features/library/dummy_data.dart';
import 'package:ember/theme/app_colors.dart';

/// A saved highlight: a colored left stripe, the quote in Spectral, and a source
/// line (page · chapter, and how long ago). Tapping it opens the Reader.
class HighlightCard extends StatelessWidget {
  const HighlightCard({super.key, required this.highlight, this.onTap});

  final DummyHighlight highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colored stripe down the left edge.
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: highlight.color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    highlight.quote,
                    style: GoogleFonts.spectral(
                      fontSize: 15,
                      height: 1.55,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Page ${highlight.page} · ${highlight.chapter}',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: AppColors.inkFaint,
                        ),
                      ),
                      Text(
                        highlight.age,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: AppColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
