package com.sarvarbek.ember.ui.theme

import androidx.compose.ui.graphics.Color

/** The "Ember" palette, taken straight from the design mockup. */
object AppColors {
    // Surfaces
    val paper = Color(0xFFF1E9DB) // app background
    val card = Color(0xFFFBF7EF) // raised cards
    val card2 = Color(0xFFF4ECDD) // secondary surfaces

    // Text
    val ink = Color(0xFF2A241E) // primary text
    val inkSoft = Color(0xFF7A6F61) // secondary text
    val inkFaint = Color(0xFFA89C8A) // tertiary text

    // Lines & accents
    val line = Color(0xFFE4D9C6) // hairlines / borders
    val ember = Color(0xFFDD7536) // primary accent
    val emberDeep = Color(0xFFBE4F1E) // accent pressed / links
    val emberSoft = Color(0xFFF6E2CF) // accent backgrounds
    val gold = Color(0xFFD6A24B) // default highlight
    val leaf = Color(0xFF7E8A5A) // "done" / success

    // Reader themes (background / ink)
    val readerPaperBg = Color(0xFFF6F1E7)
    val readerPaperInk = Color(0xFF2B2620)
    val readerSepiaBg = Color(0xFFE8D5AE)
    val readerSepiaInk = Color(0xFF4A3B28)
    val readerNightBg = Color(0xFF16130F)
    val readerNightInk = Color(0xFFD8CFC2)

    // Highlight swatches
    val hlYellow = Color(0xFFF2D24B)
    val hlGreen = Color(0xFF7FC56B)
    val hlBlue = Color(0xFF6BB4F0)
    val hlPink = Color(0xFFF08AA6)
}
