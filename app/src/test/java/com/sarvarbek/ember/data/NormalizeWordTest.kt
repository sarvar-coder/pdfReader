package com.sarvarbek.ember.data

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Locale

class NormalizeWordTest {
    @Test fun lowerCases() {
        assertEquals("hello", normalizeWord("HeLLo"))
        assertEquals("école", normalizeWord("ÉCOLE"))
    }

    /** lowercase() is locale-independent: no dotless ı on a Turkish phone. */
    @Test fun lowerCasesWithoutLocale() {
        val saved = Locale.getDefault()
        Locale.setDefault(Locale.forLanguageTag("tr-TR"))
        try {
            assertEquals("title", normalizeWord("TITLE"))
        } finally {
            Locale.setDefault(saved)
        }
    }

    @Test fun trimsWhitespace() = assertEquals("word", normalizeWord(" \t word\n "))

    @Test fun trimsEveryEdgePunctuationMark() {
        for (mark in ".,;:!?\"'()[]{}<>“”‘’«»—–…") {
            assertEquals("leading $mark", "word", normalizeWord("${mark}word"))
            assertEquals("trailing $mark", "word", normalizeWord("word$mark"))
        }
    }

    @Test fun trimsInterleavedWhitespaceAndPunctuation() {
        assertEquals("hello", normalizeWord(" (“Hello!”) "))
        assertEquals("the", normalizeWord("  “The,”  "))
        assertEquals("end", normalizeWord("«end…» —"))
    }

    @Test fun keepsInnerPunctuation() {
        assertEquals("don't", normalizeWord("don't."))
        assertEquals("don’t", normalizeWord("‘don’t’"))
        assertEquals("well-known", normalizeWord("Well-known,"))
        assertEquals("e.g", normalizeWord("e.g."))
        assertEquals("c++", normalizeWord("C++"))
    }

    @Test fun keepsDigits() = assertEquals("1984", normalizeWord("1984."))

    @Test fun nothingWordLikeIsEmpty() {
        assertEquals("", normalizeWord(""))
        assertEquals("", normalizeWord("   "))
        assertEquals("", normalizeWord("..."))
        assertEquals("", normalizeWord(" —, "))
    }

    @Test fun isIdempotent() {
        for (text in listOf(" (“Hello!”) ", "don't.", "ÉCOLE", "…")) {
            assertEquals(text, normalizeWord(text), normalizeWord(normalizeWord(text)))
        }
    }
}
