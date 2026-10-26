package com.sarvarbek.ember.features.reader

import org.junit.Assert.assertEquals
import org.junit.Test

class HeadingGapsTest {
    @Test fun bodyHasNoMarginsEitherWay() {
        assertEquals(0f to 0f, headingGaps(BlockKind.Body, isFirst = true))
        assertEquals(0f to 0f, headingGaps(BlockKind.Body, isFirst = false))
    }

    @Test fun titleOpensWithTheWidestTopGap() {
        assertEquals(0.9f to 0.4f, headingGaps(BlockKind.Title, isFirst = true))
    }

    @Test fun subtitleSitsCloserAboveThanBelow() {
        assertEquals(0.25f to 0.5f, headingGaps(BlockKind.Subtitle, isFirst = true))
    }

    /** A continuation slice drops only its top gap; the bottom gap still separates it from what follows. */
    @Test fun continuationDropsTopGapButKeepsBottom() {
        for (kind in listOf(BlockKind.Title, BlockKind.Subtitle)) {
            val (_, firstBottom) = headingGaps(kind, isFirst = true)
            assertEquals(0f to firstBottom, headingGaps(kind, isFirst = false))
        }
    }
}
