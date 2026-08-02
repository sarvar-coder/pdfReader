import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A book cover. When [coverPath] points at a rendered thumbnail on disk it
/// shows that real first-page image; otherwise (or if the file fails to load)
/// it falls back to a generated 2-color gradient with the centered title.
/// Shared by the continue card and the shelf grid.
///
/// The caller controls sizing (e.g. wrap in `AspectRatio(2/3)` or a `SizedBox`).
class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.title,
    required this.gradient,
    this.coverPath,
    this.titleSize = 12,
  });

  final String title;
  final List<Color> gradient;

  /// Path to a rendered cover PNG, or null to draw the gradient fallback.
  final String? coverPath;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    if (coverPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        // White ground so a non-2:3 page letterboxes as clean page margin.
        child: ColoredBox(
          color: Colors.white,
          child: Image.file(
            File(coverPath!),
            // Contain: show the whole cover, don't crop to fill.
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => _gradientCover(),
          ),
        ),
      );
    }
    return _gradientCover();
  }

  Widget _gradientCover() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0xB3281E12),
              blurRadius: 14,
              offset: Offset(0, 6),
              spreadRadius: -8,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Spine line down the left edge.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 6,
              child: const ColoredBox(color: Color(0x2E000000)),
            ),
            // Centered title.
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Center(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.fraunces(
                      fontSize: titleSize,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          color: Color(0x66000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
