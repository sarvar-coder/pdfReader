package com.sarvarbek.ember.features.reader

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WordTextTest {
    @Test
    fun singleWordStripsSurroundingPunctuationOnly() {
        assertEquals("don't", singleWord("“don't,”"))
        assertEquals("well-known", singleWord(" (well-known). "))
        assertEquals("Hello", singleWord("${INDENT}Hello"))
        assertNull(singleWord("two words"))
        assertNull(singleWord("—"))
    }

    @Test
    fun contextSentenceIsTheSentenceAroundTheOffset() {
        val p = "${INDENT}He left. The city was loud at night! Was it? Yes."
        assertEquals("The city was loud at night!", contextSentence(p, p.indexOf("loud")))
        assertEquals("He left.", contextSentence(p, p.indexOf("left")))
        assertEquals("Yes.", contextSentence(p, p.length - 2))
        assertEquals("No end here", contextSentence("No end here", 3))
        assertEquals("Dr.Who is ok.", contextSentence("Dr.Who is ok.", 0)) // no space after "." → one sentence
    }

    @Test
    fun longSentenceIsWindowedAroundTheWord() {
        val p = (1..80).joinToString(" ") { "w$it" } + "."
        val s = contextSentence(p, p.indexOf("w40 "))
        assertTrue(s.length <= 202)
        assertTrue("w40" in s)
        assertTrue(s.startsWith("…") && s.endsWith("…"))
    }

    @Test
    fun markRangesDropOverlaps() {
        val r = markRanges("the cat sat on the mat", listOf("the" to 1, "cat sat" to 2, "e ca" to 3))
        assertEquals(listOf(Triple(0, 3, 1), Triple(4, 11, 2), Triple(15, 18, 1)), r)
    }
}
