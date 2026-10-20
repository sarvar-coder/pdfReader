package com.sarvarbek.ember.features.reader

import org.junit.Assert.assertEquals
import org.junit.Test

/** Block classification: pure string logic. */
class ReflowTest {
    @Test
    fun allCapsLineBecomesTitle() {
        val blocks = toBlocks("CHAPTER ONE\n\nHe woke before the alarm.")
        assertEquals(BlockKind.Title, blocks.first().kind)
        assertEquals("CHAPTER ONE", blocks.first().text)
    }

    @Test
    fun wrappedBodyLinesRejoinIntoOneIndentedParagraph() {
        val blocks = toBlocks("The quick brown fox jumps over\nthe lazy dog and keeps running.")
        assertEquals(1, blocks.size)
        assertEquals(BlockKind.Body, blocks.single().kind)
        assertEquals("${INDENT}The quick brown fox jumps over the lazy dog and keeps running.", blocks.single().text)
    }

    @Test
    fun sentenceOpeningWithSectionKeywordStaysBody() {
        assertEquals(BlockKind.Body, toBlocks("Part of the reason he left the city was the noise.").single().kind)
    }

    @Test
    fun indentIsTwoEmSpaces() {
        assertEquals(listOf(0x2003, 0x2003), INDENT.map { it.code })
    }

    @Test
    fun displayTitleSplitAcrossSizesFoldsIntoOneTitle() {
        val blocks = toBlocks(
            listOf(
                "7", "WHAT the", "FEELINGS", "you most", "SUPPRESS", "are trying to", "TELL YOU",
                "Emotional intelligence is not how infrequently you feel anything.",
            ).joinToString("\n\n"),
        )
        assertEquals(listOf(BlockKind.Title, BlockKind.Title, BlockKind.Body), blocks.map { it.kind })
        assertEquals("7", blocks[0].text)
        assertEquals("WHAT the FEELINGS you most SUPPRESS are trying to TELL YOU", blocks[1].text)
    }

    @Test
    fun consecutiveHeadingsWithNoFragmentStayApart() {
        val blocks = toBlocks("CHAPTER ONE\n\nThe Beginning\n\nHe woke before the alarm.")
        assertEquals(listOf("CHAPTER ONE", "The Beginning", "He woke before the alarm."), blocks.map { it.text.trim() })
    }
}
