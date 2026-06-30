import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ember/models/book.dart';
import 'package:ember/models/reading_session.dart';
import 'package:ember/providers/library_provider.dart';
import 'package:ember/providers/sessions_provider.dart';

/// Number of days shown in the quarter heatmap (13 columns × 7 rows).
const int kHeatmapDays = 91;

/// Aggregate reading stats shown on the Library streak card and Stats screen,
/// derived from the recorded [ReadingSession]s and the library.
class ReadingStats {
  const ReadingStats({
    required this.streakDays,
    required this.longestStreak,
    required this.weekDots,
    required this.minutesToday,
    required this.pagesThisWeek,
    required this.booksFinished,
    required this.hoursThisMonth,
    required this.heatmapLevels,
  });

  final int streakDays;
  final int longestStreak;

  /// Last seven days, oldest → newest; `true` means the day was read.
  final List<bool> weekDots;
  final int minutesToday;
  final int pagesThisWeek;
  final int booksFinished;
  final int hoursThisMonth;

  /// One 0–4 intensity level per day for the last [kHeatmapDays], oldest first.
  final List<int> heatmapLevels;

  factory ReadingStats.fromData({
    required List<ReadingSession> sessions,
    required List<Book> books,
    required DateTime now,
  }) {
    int keyOf(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
    final today = DateTime(now.year, now.month, now.day);

    // Aggregate minutes / pages per calendar day.
    final minutesByDay = <int, int>{};
    final pagesByDay = <int, int>{};
    for (final s in sessions) {
      final day = DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day);
      final k = keyOf(day);
      minutesByDay[k] = (minutesByDay[k] ?? 0) + s.minutes;
      pagesByDay[k] = (pagesByDay[k] ?? 0) + s.pagesRead;
    }

    bool readOn(DateTime d) => (minutesByDay[keyOf(d)] ?? 0) > 0;

    // Current streak: consecutive days ending today (a one-day grace if today
    // hasn't been read yet but yesterday was).
    var cursor = today;
    if (!readOn(today) && readOn(today.subtract(const Duration(days: 1)))) {
      cursor = today.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (readOn(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // Longest streak across all distinct active days.
    final activeDays = <DateTime>[
      for (final s in sessions)
        DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day),
    ]..sort();
    var longest = 0;
    var run = 0;
    DateTime? prev;
    for (final d in activeDays) {
      if (prev != null && keyOf(d) == keyOf(prev)) continue; // same day
      if (prev != null &&
          keyOf(d) == keyOf(prev.add(const Duration(days: 1)))) {
        run++;
      } else {
        run = 1;
      }
      if (run > longest) longest = run;
      prev = d;
    }
    if (longest < streak) longest = streak;

    // Week dots: last 7 days, oldest → newest.
    final weekDots = <bool>[
      for (var i = 6; i >= 0; i--)
        readOn(today.subtract(Duration(days: i))),
    ];

    final minutesToday = minutesByDay[keyOf(today)] ?? 0;

    var pagesThisWeek = 0;
    for (var i = 0; i < 7; i++) {
      pagesThisWeek += pagesByDay[keyOf(today.subtract(Duration(days: i)))] ?? 0;
    }

    var minutesThisMonth = 0;
    for (final s in sessions) {
      if (s.startedAt.year == now.year && s.startedAt.month == now.month) {
        minutesThisMonth += s.minutes;
      }
    }

    final booksFinished = books
        .where((b) => b.totalPages > 0 && b.currentPage >= b.totalPages)
        .length;

    // Heatmap: oldest → newest over the window, bucketed by minutes.
    final heatmapLevels = <int>[
      for (var i = kHeatmapDays - 1; i >= 0; i--)
        _levelForMinutes(minutesByDay[keyOf(today.subtract(Duration(days: i)))] ?? 0),
    ];

    return ReadingStats(
      streakDays: streak,
      longestStreak: longest,
      weekDots: weekDots,
      minutesToday: minutesToday,
      pagesThisWeek: pagesThisWeek,
      booksFinished: booksFinished,
      hoursThisMonth: (minutesThisMonth / 60).round(),
      heatmapLevels: heatmapLevels,
    );
  }

  static int _levelForMinutes(int minutes) {
    if (minutes <= 0) return 0;
    if (minutes < 10) return 1;
    if (minutes < 20) return 2;
    if (minutes < 40) return 3;
    return 4;
  }
}

/// Reading stats derived from the recorded sessions and the library.
final statsProvider = Provider<ReadingStats>((ref) {
  final sessions = ref.watch(readingSessionsProvider);
  final books = ref.watch(libraryProvider);
  return ReadingStats.fromData(
    sessions: sessions,
    books: books,
    now: DateTime.now(),
  );
});
