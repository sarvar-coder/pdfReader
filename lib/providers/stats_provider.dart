import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ember/features/library/dummy_data.dart';

/// Aggregate reading stats shown on the Library streak card and Stats screen.
class ReadingStats {
  const ReadingStats({
    required this.streakDays,
    required this.longestStreak,
    required this.weekDots,
    required this.minutesToday,
    required this.pagesThisWeek,
    required this.booksFinished,
    required this.hoursThisMonth,
  });

  final int streakDays;
  final int longestStreak;

  /// Last seven days, oldest → newest; `true` means the day was read.
  final List<bool> weekDots;
  final int minutesToday;
  final int pagesThisWeek;
  final int booksFinished;
  final int hoursThisMonth;
}

/// For now these mirror [DummyData]. They become real (derived from the
/// `ReadingSession` box) in Phase 5; routing the screens through this provider
/// means that swap won't touch the UI.
final statsProvider = Provider<ReadingStats>((ref) {
  return const ReadingStats(
    streakDays: DummyData.streakDays,
    longestStreak: DummyData.longestStreak,
    weekDots: DummyData.weekDots,
    minutesToday: DummyData.minutesToday,
    pagesThisWeek: DummyData.pagesThisWeek,
    booksFinished: DummyData.booksFinished,
    hoursThisMonth: DummyData.hoursThisMonth,
  );
});
