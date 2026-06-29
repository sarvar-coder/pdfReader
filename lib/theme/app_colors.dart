import 'package:flutter/material.dart';

/// The "Ember" palette, taken straight from the design mockup.
abstract final class AppColors {
  // Surfaces
  static const paper = Color(0xFFF1E9DB); // app background
  static const card = Color(0xFFFBF7EF); // raised cards
  static const card2 = Color(0xFFF4ECDD); // secondary surfaces

  // Text
  static const ink = Color(0xFF2A241E); // primary text
  static const inkSoft = Color(0xFF7A6F61); // secondary text
  static const inkFaint = Color(0xFFA89C8A); // tertiary text

  // Lines & accents
  static const line = Color(0xFFE4D9C6); // hairlines / borders
  static const ember = Color(0xFFDD7536); // primary accent
  static const emberDeep = Color(0xFFBE4F1E); // accent pressed / links
  static const emberSoft = Color(0xFFF6E2CF); // accent backgrounds
  static const gold = Color(0xFFD6A24B); // default highlight
  static const leaf = Color(0xFF7E8A5A); // "done" / success

  // Reader themes (background / ink)
  static const readerPaperBg = Color(0xFFF6F1E7);
  static const readerPaperInk = Color(0xFF2B2620);
  static const readerSepiaBg = Color(0xFFE8D5AE);
  static const readerSepiaInk = Color(0xFF4A3B28);
  static const readerNightBg = Color(0xFF16130F);
  static const readerNightInk = Color(0xFFD8CFC2);

  // Highlight swatches
  static const hlYellow = Color(0xFFF2D24B);
  static const hlGreen = Color(0xFF7FC56B);
  static const hlBlue = Color(0xFF6BB4F0);
  static const hlPink = Color(0xFFF08AA6);
}
