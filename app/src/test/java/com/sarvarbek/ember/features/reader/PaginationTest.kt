package com.sarvarbek.ember.features.reader

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PaginationTest {
    /** Fake layout: a line every 10 chars, each 10 px tall. */
    private fun measure(b: Block): Measured {
        val ends = (10 until b.text.length step 10).toList() + b.text.length
        return Measured(ends.toIntArray(), FloatArray(ends.size) { 10f })
    }

    @Test
    fun bodySplitsAtLineBoundariesAndHeadingsStayWhole() {
        val body = INDENT + "abcdefghi ".repeat(9) // 92 chars → 10 lines
        val blocks = listOf(Block(BlockKind.Title, "TITLE", page = 0), Block(BlockKind.Body, body, page = 3))
        val pages = paginate(blocks, height = 50f, fontPx = 10f, measure = ::measure)

        // Title: 9 + 4 margin + 10 line = 23 px, so 2 body lines fit under it, then 5, then 3.
        assertEquals(listOf(2, 1, 1), pages.map { it.frags.size })
        assertEquals(BlockKind.Title, pages[0].frags[0].kind)
        assertEquals(listOf(0, 3, 3), pages.map { it.pdfPage })
        val slices = pages.flatMap { it.frags }.drop(1)
        assertEquals(listOf(true, false, false), slices.map { it.isFirst })
        // Every slice maps back onto the block text; continuations carry no leading space.
        for (f in slices) {
            assertEquals(f.text, body.substring(f.start, f.start + f.text.length))
            if (!f.isFirst) assertTrue(!f.text.first().isWhitespace())
        }
        assertEquals(body.filterNot { it == ' ' }, slices.joinToString("") { it.text }.filterNot { it == ' ' })
    }

    @Test
    fun aLineTallerThanThePageStillGetsAPage() {
        val pages = paginate(listOf(Block(BlockKind.Body, "x".repeat(5))), height = 1f, fontPx = 10f, measure = ::measure)
        assertEquals(1, pages.size)
        assertEquals("xxxxx", pages.single().frags.single().text)
    }

    @Test
    fun fractionAnchorsToTheCharAndSurvivesRepagination() {
        val body = INDENT + "abcdefghi ".repeat(9)
        val blocks = listOf(Block(BlockKind.Title, "TITLE"), Block(BlockKind.Body, body))
        val total = totalChars(blocks)
        val small = paginate(blocks, height = 50f, fontPx = 10f, measure = ::measure)
        assertEquals(listOf(0, 5 + 20, 5 + 70), small.map { it.charStart })

        // Reading page 2 of the small layout, then repaginating taller: land on the page holding that char.
        val f = fractionOf(small[1], total)
        assertEquals(1, pageForFraction(f, small, total))
        val tall = paginate(blocks, height = 80f, fontPx = 10f, measure = ::measure)
        val i = pageForFraction(f, tall, total)
        assertTrue(tall[i].charStart <= small[1].charStart)
        assertTrue(tall.getOrNull(i + 1)?.let { it.charStart > small[1].charStart } ?: true)
        assertEquals(0, pageForFraction(0.0, tall, total))
    }
}
