import 'package:flutter/material.dart';

import 'package:ember/theme/app_colors.dart';

/// A fake book for Phase 1 screens. Anticipates the real `Book` model (Phase 2);
/// covers are drawn as a two-color gradient until real thumbnails arrive.
final class DummyBook {
  const DummyBook({
    required this.title,
    required this.author,
    required this.currentPage,
    required this.totalPages,
    required this.gradient,
    this.chapter,
  });

  final String title;
  final String author;
  final int currentPage;
  final int totalPages;

  /// Two colors painted top-left → bottom-right behind the cover title.
  final List<Color> gradient;

  /// Optional chapter label shown on the continue card / reader chrome.
  final String? chapter;

  /// Reading progress in the range 0.0–1.0.
  double get progress => currentPage / totalPages;
}

/// A fake highlight for the Saved screen. Anticipates the real `Highlight` model.
final class DummyHighlight {
  const DummyHighlight({
    required this.quote,
    required this.color,
    required this.page,
    required this.chapter,
    required this.age,
  });

  final String quote;

  /// Swatch color for the card's left stripe (one of the four highlight colors).
  final Color color;
  final int page;
  final String chapter;

  /// Human-friendly relative time, e.g. "2 days ago".
  final String age;
}

/// A fake bookmark for the Saved screen. Anticipates the real `Bookmark` model.
final class DummyBookmark {
  const DummyBookmark({
    required this.page,
    required this.chapter,
    required this.note,
  });

  final int page;
  final String chapter;
  final String note;
}

/// Hardcoded sample content so every Phase 1 screen renders before the data
/// layer (Phase 2) and PDF logic (Phase 3) exist. Values mirror the mockup
/// (`~/Downloads/reader_app_design.html`).
abstract final class DummyData {
  /// The book shown in the "Continue reading" card and the Reader screen.
  static const DummyBook continueReading = DummyBook(
    title: 'The Overstory',
    author: 'Richard Powers',
    currentPage: 184,
    totalPages: 502,
    chapter: 'Chapter 6 · Roots',
    gradient: [Color(0xFF3F5A3A), Color(0xFF7E8A5A)],
  );

  /// Books on the shelf grid (excludes the continue-reading book above).
  static const List<DummyBook> shelf = [
    DummyBook(
      title: 'Tomorrow, and Tomorrow, and Tomorrow',
      author: 'G. Zevin',
      currentPage: 0,
      totalPages: 416,
      gradient: [Color(0xFFBE4F1E), Color(0xFFDD7536)],
    ),
    DummyBook(
      title: 'Project Hail Mary',
      author: 'A. Weir',
      currentPage: 132,
      totalPages: 496,
      gradient: [Color(0xFF1F3A52), Color(0xFF6BB4F0)],
    ),
    DummyBook(
      title: 'Dune',
      author: 'F. Herbert',
      currentPage: 58,
      totalPages: 688,
      gradient: [Color(0xFF8A5A1E), Color(0xFFD6A24B)],
    ),
    DummyBook(
      title: 'Piranesi',
      author: 'S. Clarke',
      currentPage: 0,
      totalPages: 272,
      gradient: [Color(0xFF4A4A6A), Color(0xFFA89C8A)],
    ),
    DummyBook(
      title: 'Klara and the Sun',
      author: 'K. Ishiguro',
      currentPage: 201,
      totalPages: 320,
      gradient: [Color(0xFFB23E5A), Color(0xFFF08AA6)],
    ),
  ];

  /// Saved highlights.
  static const List<DummyHighlight> highlights = [
    DummyHighlight(
      quote:
          'The first trees were temples, and the oldest of them had been '
          'standing since before the idea of a year.',
      color: AppColors.hlYellow,
      page: 184,
      chapter: 'Chapter 6',
      age: '2 days ago',
    ),
    DummyHighlight(
      quote:
          'The slowness is not emptiness — it is a different kind of attention.',
      color: AppColors.hlGreen,
      page: 184,
      chapter: 'Chapter 6',
      age: '2 days ago',
    ),
    DummyHighlight(
      quote:
          'They had begun, quietly and without permission, to measure her.',
      color: AppColors.hlBlue,
      page: 184,
      chapter: 'Chapter 6',
      age: '5 days ago',
    ),
  ];

  /// Saved bookmarks.
  static const List<DummyBookmark> bookmarks = [
    DummyBookmark(
      page: 184,
      chapter: 'Chapter 6 — Roots',
      note: '…this was the afternoon her life split cleanly in two.',
    ),
    DummyBookmark(
      page: 96,
      chapter: 'Chapter 3 — Canopy',
      note: 'Returned to twice',
    ),
    DummyBookmark(
      page: 12,
      chapter: 'Prologue',
      note: 'Where it began',
    ),
  ];

  // ── Streak & stats ────────────────────────────────────────────────────────

  /// Current reading streak in days.
  static const int streakDays = 12;

  /// Longest streak ever reached.
  static const int longestStreak = 23;

  /// The last seven days, oldest → newest. `true` means the day was read.
  /// The most recent `true` is "today" (drawn outlined by the streak card).
  static const List<bool> weekDots = [
    true,
    true,
    true,
    true,
    true,
    false,
    false,
  ];

  /// Minutes read today.
  static const int minutesToday = 38;

  /// Pages read this week.
  static const int pagesThisWeek = 214;

  /// Total books finished.
  static const int booksFinished = 9;

  /// Hours read this month.
  static const int hoursThisMonth = 31;

  // ── Reader sample text ────────────────────────────────────────────────────

  /// A single sentence rendered with a highlight style in the Reader (step 1.4).
  static const String highlightedSentence =
      'The first trees were temples, and the oldest of them had been standing '
      'since before the idea of a year.';

  /// Placeholder reading text for the Reader screen, one entry per paragraph.
  /// One paragraph contains [highlightedSentence] so it can be wrapped in a
  /// highlight style.
  static const List<String> sampleParagraphs = [
    'There was a family that lived at the edge of a slow forest, where the light '
        'came down in long green columns and the air smelled of resin and rain. '
        'They did not know, then, how much the trees were watching them back.',
    'The first trees were temples, and the oldest of them had been standing '
        'since before the idea of a year. Their patience was a language no one had '
        'thought to learn, spoken in rings and shed leaves and the slow architecture '
        'of roots reaching toward water.',
    'She walked among them in the early morning, before the others woke, and felt '
        'the particular hush that large living things make when they are busy being '
        'alive. The slowness is not emptiness — it is a different kind of attention.',
    'Years later she would remember this walk and understand that it had changed '
        'her, though at the time it seemed only like an ordinary morning. They had '
        'begun, quietly and without permission, to measure her.',
  ];
}
