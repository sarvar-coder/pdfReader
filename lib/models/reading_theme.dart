import 'package:flutter/material.dart';

/// Visual theme applied inside the reader (page background + text color).
/// Independent of the app's overall light/dark chrome.
enum ReadingTheme {
  light(
    label: 'Light',
    background: Color(0xFFFFFFFF),
    text: Color(0xFF111111),
  ),
  sepia(
    label: 'Sepia',
    background: Color(0xFFF4ECD8),
    text: Color(0xFF5B4636),
  ),
  dark(
    label: 'Dark',
    background: Color(0xFF121212),
    text: Color(0xFFD8D8D8),
  );

  const ReadingTheme({
    required this.label,
    required this.background,
    required this.text,
  });

  final String label;
  final Color background;
  final Color text;

  /// A readable highlight color for this theme.
  Color get highlight => this == ReadingTheme.dark
      ? const Color(0xFF5C5326) // muted gold on dark
      : const Color(0xFFFFE082); // soft yellow on light/sepia
}
