import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// App-wide light theme for Ember.
///
/// Typefaces from the design: **Fraunces** for headings, **Inter** for UI text.
/// (Spectral is the reading typeface and is applied locally in the reader.)
ThemeData buildEmberTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);

  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.ember,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.ember,
    surface: AppColors.card,
    onSurface: AppColors.ink,
  );

  // Fraunces, used for every display/headline/title slot.
  TextStyle fraunces() => GoogleFonts.fraunces(
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        letterSpacing: -0.2,
      );

  // Inter as the base for body/label text.
  final inter = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
  );

  final textTheme = inter.copyWith(
    displayLarge: fraunces(),
    displayMedium: fraunces(),
    displaySmall: fraunces(),
    headlineLarge: fraunces(),
    headlineMedium: fraunces(),
    headlineSmall: fraunces(),
    titleLarge: fraunces(),
  );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.paper,
    canvasColor: AppColors.paper,
    textTheme: textTheme,
  );
}

/// Spectral reading style for body text in the reader. Size, height, and color
/// are passed in from the reader's live settings.
TextStyle readingTextStyle({
  required double fontSize,
  required double height,
  required Color color,
}) =>
    GoogleFonts.spectral(fontSize: fontSize, height: height, color: color);
