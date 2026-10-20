package com.sarvarbek.ember.data

import com.sarvarbek.ember.data.db.Book
import com.sarvarbek.ember.data.db.EmberDatabase
import com.sarvarbek.ember.data.db.ReadingSession
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import kotlin.math.roundToInt

/** Number of days in the quarter heatmap (13 columns x 7 rows). */
const val HEATMAP_DAYS = 91

/** Aggregate reading stats for the Library streak card and the Stats screen. */
data class ReadingStats(
    val streakDays: Int,
    val longestStreak: Int,
    /** Last seven days, oldest to newest; true = the day was read. */
    val weekDots: List<Boolean>,
    val minutesToday: Int,
    val pagesThisWeek: Int,
    val booksFinished: Int,
    val hoursThisMonth: Int,
    /** One 0-4 level per day for the last [HEATMAP_DAYS], oldest first. */
    val heatmapLevels: List<Int>,
) {
    companion object {
        fun fromData(
            sessions: List<ReadingSession>,
            books: List<Book>,
            today: LocalDate,
            zone: ZoneId = ZoneId.systemDefault(),
        ): ReadingStats {
            fun dayOf(s: ReadingSession) = Instant.ofEpochMilli(s.startedAt).atZone(zone).toLocalDate()

            val minutesByDay = HashMap<LocalDate, Int>()
            val pagesByDay = HashMap<LocalDate, Int>()
            for (s in sessions) {
                val d = dayOf(s)
                minutesByDay.merge(d, s.minutes, Int::plus)
                pagesByDay.merge(d, s.pagesRead, Int::plus)
            }
            fun readOn(d: LocalDate) = (minutesByDay[d] ?: 0) > 0

            // Current streak ends today, with a one-day grace if today isn't read yet but yesterday was.
            var cursor = if (!readOn(today) && readOn(today.minusDays(1))) today.minusDays(1) else today
            var streak = 0
            while (readOn(cursor)) {
                streak++
                cursor = cursor.minusDays(1)
            }

            // Longest run across all distinct session days.
            var longest = 0
            var run = 0
            var prev: LocalDate? = null
            for (d in sessions.map(::dayOf).distinct().sorted()) {
                run = if (prev != null && d == prev.plusDays(1)) run + 1 else 1
                longest = maxOf(longest, run)
                prev = d
            }

            val minutesThisMonth = sessions
                .filter { dayOf(it).let { d -> d.year == today.year && d.month == today.month } }
                .sumOf { it.minutes }

            return ReadingStats(
                streakDays = streak,
                longestStreak = maxOf(longest, streak),
                weekDots = (6L downTo 0L).map { readOn(today.minusDays(it)) },
                minutesToday = minutesByDay[today] ?: 0,
                pagesThisWeek = (0L..6L).sumOf { pagesByDay[today.minusDays(it)] ?: 0 },
                booksFinished = books.count { it.totalPages > 0 && it.currentPage >= it.totalPages },
                hoursThisMonth = (minutesThisMonth / 60.0).roundToInt(),
                heatmapLevels = (HEATMAP_DAYS - 1L downTo 0L).map { levelFor(minutesByDay[today.minusDays(it)] ?: 0) },
            )
        }

        private fun levelFor(minutes: Int) = when {
            minutes <= 0 -> 0
            minutes < 10 -> 1
            minutes < 20 -> 2
            minutes < 40 -> 3
            else -> 4
        }
    }
}

/** Today's date, re-checked every minute, so stats roll over at midnight. Restarts with the collector on resume. */
private val todayFlow = flow {
    while (true) {
        emit(LocalDate.now())
        delay(60_000)
    }
}.distinctUntilChanged()

/** Live [ReadingStats], recomputed off the main thread when sessions, books or the date change. */
fun readingStatsFlow(db: EmberDatabase): Flow<ReadingStats> =
    combine(db.sessions().all(), db.books().all(), todayFlow) { sessions, books, today ->
        ReadingStats.fromData(sessions, books, today)
    }.flowOn(Dispatchers.Default)
