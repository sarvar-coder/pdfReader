package com.sarvarbek.ember.features.words

import org.junit.Assert.assertEquals
import org.junit.Test

class BoldWordTest {
    private fun bolded(context: String, word: String) =
        boldWord(context, word).let { s -> s.spanStyles.map { s.text.substring(it.start, it.end) } }

    @Test fun boldsWholeWordsIgnoringCase() =
        assertEquals(listOf("The", "the"), bolded("The cat sat on the theme.", "the"))

    @Test fun symbolsMatchLiterally() {
        assertEquals(listOf("a.b"), bolded("x a.b axb", "a.b"))
        assertEquals(listOf("C++"), bolded("I wrote C++ today.", "c++"))
    }
}
