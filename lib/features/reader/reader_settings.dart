import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ember/theme/app_colors.dart';

/// The three reader color themes; each carries its background and ink color.
enum ReaderTheme {
  paper('Paper', AppColors.readerPaperBg, AppColors.readerPaperInk),
  sepia('Sepia', AppColors.readerSepiaBg, AppColors.readerSepiaInk),
  night('Night', AppColors.readerNightBg, AppColors.readerNightInk);

  const ReaderTheme(this.label, this.bg, this.ink);

  final String label;
  final Color bg;
  final Color ink;
}

/// The three reading typefaces offered in the settings sheet.
enum ReaderTypeface {
  spectral('Spectral'),
  fraunces('Fraunces'),
  inter('Inter');

  const ReaderTypeface(this.label);

  final String label;

  /// Builds the typeface's [TextStyle] at the given size/height/color.
  TextStyle textStyle({
    required double fontSize,
    required double height,
    required Color color,
  }) {
    switch (this) {
      case ReaderTypeface.spectral:
        return GoogleFonts.spectral(
            fontSize: fontSize, height: height, color: color);
      case ReaderTypeface.fraunces:
        return GoogleFonts.fraunces(
            fontSize: fontSize, height: height, color: color);
      case ReaderTypeface.inter:
        return GoogleFonts.inter(
            fontSize: fontSize, height: height, color: color);
    }
  }
}

/// Allowed font-size range (pt) and line-spacing range, from PLAN.md.
const double kMinFontSize = 14;
const double kMaxFontSize = 26;
const double kMinLineSpacing = 1.4;
const double kMaxLineSpacing = 2.2;

/// Live, user-adjustable reading settings. Immutable; updated via [copyWith].
@immutable
class ReaderSettings {
  const ReaderSettings({
    this.theme = ReaderTheme.paper,
    this.fontSize = 18,
    this.typeface = ReaderTypeface.spectral,
    this.lineSpacing = 1.7,
  });

  final ReaderTheme theme;
  final double fontSize;
  final ReaderTypeface typeface;
  final double lineSpacing;

  ReaderSettings copyWith({
    ReaderTheme? theme,
    double? fontSize,
    ReaderTypeface? typeface,
    double? lineSpacing,
  }) {
    return ReaderSettings(
      theme: theme ?? this.theme,
      fontSize: fontSize ?? this.fontSize,
      typeface: typeface ?? this.typeface,
      lineSpacing: lineSpacing ?? this.lineSpacing,
    );
  }

  /// The nominal height of one body line. Good enough for slack and spacing;
  /// the engine can round a real line box up by a fraction of a pixel, so
  /// anything that has to land *on* a line boundary measures instead.
  double get lineHeight => fontSize * lineSpacing;

  /// The body text style for the current settings, in the theme's ink color.
  TextStyle bodyStyle() => typeface.textStyle(
        fontSize: fontSize,
        height: lineSpacing,
        color: theme.ink,
      );
}
