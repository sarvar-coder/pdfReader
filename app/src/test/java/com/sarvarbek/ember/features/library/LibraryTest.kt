package com.sarvarbek.ember.features.library

import org.junit.Assert.assertEquals
import org.junit.Test

class LibraryTest {
    @Test
    fun titleFromFileNameStripsExtensionAndUnderscores() {
        assertEquals("Maybe You Should", titleFromFileName("Maybe_You_Should.PDF"))
        assertEquals("Essays That Will Change", titleFromFileName("31_10_2020_084952101_Essays_That_Will_Change.pdf"))
        assertEquals("Untitled", titleFromFileName(".pdf"))
    }

    @Test
    fun greetingFollowsTimeOfDay() {
        assertEquals("Good morning, reader", greeting(5))
        assertEquals("Good afternoon, reader", greeting(12))
        assertEquals("Good evening, reader", greeting(18))
        assertEquals("Good evening, reader", greeting(2))
    }
}
