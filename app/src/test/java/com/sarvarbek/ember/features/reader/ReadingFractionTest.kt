package com.sarvarbek.ember.features.reader

import org.junit.Assert.assertEquals
import org.junit.Test

/** Edge cases of [fractionOf] and [pageForFraction]; the round trip through [paginate] lives in PaginationTest. */
class ReadingFractionTest {
    private fun page(charStart: Int) = Page(frags = emptyList(), pdfPage = 0, charStart = charStart)

    private val pages = listOf(page(0), page(40), page(80))

    @Test fun fractionIsCharStartOverTotal() {
        assertEquals(0.0, fractionOf(pages[0], 100), 0.0)
        assertEquals(0.4, fractionOf(pages[1], 100), 1e-9)
        assertEquals(0.8, fractionOf(pages[2], 100), 1e-9)
    }

    @Test fun emptyTextHasFractionZero() {
        assertEquals(0.0, fractionOf(page(5), 0), 0.0)
        assertEquals(0.0, fractionOf(page(5), -3), 0.0)
    }

    @Test fun fractionPicksThePageWhoseStartIsAtOrBeforeTheChar() {
        assertEquals(0, pageForFraction(0.39, pages, 100))
        assertEquals(1, pageForFraction(0.4, pages, 100))
        assertEquals(1, pageForFraction(0.79, pages, 100))
        assertEquals(2, pageForFraction(0.8, pages, 100))
        assertEquals(2, pageForFraction(1.0, pages, 100))
    }

    @Test fun charOffsetIsRoundedNotTruncated() {
        // 0.395 * 100 = 39.5 → char 40 → page 1.
        assertEquals(1, pageForFraction(0.395, pages, 100))
    }

    @Test fun outOfRangeFractionsClampToFirstAndLastPage() {
        assertEquals(0, pageForFraction(-0.5, pages, 100))
        assertEquals(2, pageForFraction(1.7, pages, 100))
    }

    @Test fun noPagesOrNoTextFallsBackToPageZero() {
        assertEquals(0, pageForFraction(0.5, emptyList(), 100))
        assertEquals(0, pageForFraction(0.9, pages, 0))
    }

    @Test fun roundTripReturnsTheSamePage() {
        for (i in pages.indices) assertEquals(i, pageForFraction(fractionOf(pages[i], 100), pages, 100))
    }
}
