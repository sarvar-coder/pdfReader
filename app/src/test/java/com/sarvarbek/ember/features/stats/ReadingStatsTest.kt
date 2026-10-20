package com.sarvarbek.ember.features.stats

import com.sarvarbek.ember.data.HEATMAP_DAYS
import com.sarvarbek.ember.data.ReadingStats
import com.sarvarbek.ember.data.db.Book
import com.sarvarbek.ember.data.db.ReadingSession
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneOffset

class ReadingStatsTest {
    private val today = LocalDate.of(2026, 10, 20)
    private var n = 0

    /** A session [daysAgo] days before [today], at noon UTC. */
    private fun s(daysAgo: Long, minutes: Int = 15, pages: Int = 0) = ReadingSession(
        id = "s${n++}",
        bookId = "b",
        startedAt = today.minusDays(daysAgo).atTime(12, 0).toInstant(ZoneOffset.UTC).toEpochMilli(),
        minutes = minutes,
        pagesRead = pages,
    )

    private fun book(current: Int, total: Int) = Book("b$current/$total", "t", "", current, total, 0, 0)

    private fun stats(sessions: List<ReadingSession>, books: List<Book> = emptyList()) =
        ReadingStats.fromData(sessions, books, today, ZoneOffset.UTC)

    @Test
    fun streakCountsBackFromToday() {
        assertEquals(3, stats(listOf(s(0), s(1), s(2), s(4))).streakDays)
    }

    @Test
    fun streakGraceWhenTodayUnreadButYesterdayRead() {
        assertEquals(2, stats(listOf(s(1), s(2))).streakDays)
        assertEquals(0, stats(listOf(s(2), s(3))).streakDays)
    }

    @Test
    fun zeroMinuteSessionDoesNotKeepStreak() {
        assertEquals(0, stats(listOf(s(0, minutes = 0))).streakDays)
    }

    @Test
    fun longestStreakAcrossHistory() {
        val st = stats(listOf(s(0), s(10), s(11), s(12), s(12), s(13), s(20)))
        assertEquals(1, st.streakDays)
        assertEquals(4, st.longestStreak)
    }

    @Test
    fun weekDotsOldestToNewest() {
        assertEquals(listOf(true, false, false, false, false, true, true), stats(listOf(s(0), s(1), s(6))).weekDots)
    }

    @Test
    fun minutesTodaySumsTodaysSessions() {
        assertEquals(30, stats(listOf(s(0, 12), s(0, 18), s(1, 50))).minutesToday)
    }

    @Test
    fun pagesThisWeekCoversLastSevenDays() {
        assertEquals(7, stats(listOf(s(0, pages = 3), s(6, pages = 4), s(7, pages = 100))).pagesThisWeek)
    }

    @Test
    fun booksFinishedNeedsKnownPageCount() {
        assertEquals(2, stats(emptyList(), listOf(book(10, 10), book(12, 10), book(5, 10), book(0, 0))).booksFinished)
    }

    @Test
    fun heatmapLevelsBucketMinutes() {
        val levels = stats(listOf(s(0, 45), s(1, 25), s(2, 15), s(3, 5), s(90, 40), s(91, 99))).heatmapLevels
        assertEquals(HEATMAP_DAYS, levels.size)
        assertEquals(listOf(0, 1, 2, 3, 4), levels.takeLast(5))
        assertEquals(4, levels.first())
    }

    @Test
    fun hoursThisMonthRounds() {
        assertEquals(2, stats(listOf(s(0, 60), s(1, 30), s(30, 600))).hoursThisMonth)
    }
}
