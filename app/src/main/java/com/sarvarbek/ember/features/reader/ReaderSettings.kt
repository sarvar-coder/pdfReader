package com.sarvarbek.ember.features.reader

import android.content.SharedPreferences
import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import androidx.core.content.edit
import com.sarvarbek.ember.ui.theme.AppColors
import com.sarvarbek.ember.ui.theme.Fraunces
import com.sarvarbek.ember.ui.theme.Inter
import com.sarvarbek.ember.ui.theme.Spectral

/** The three reader color themes; each carries its background and ink color. */
enum class ReaderTheme(val label: String, val bg: Color, val ink: Color) {
    Paper("Paper", AppColors.readerPaperBg, AppColors.readerPaperInk),
    Sepia("Sepia", AppColors.readerSepiaBg, AppColors.readerSepiaInk),
    Night("Night", AppColors.readerNightBg, AppColors.readerNightInk),
}

/** The three reading typefaces offered in the settings sheet. */
enum class ReaderTypeface(val label: String, val family: FontFamily) {
    Spectral("Spectral", com.sarvarbek.ember.ui.theme.Spectral),
    Fraunces("Fraunces", com.sarvarbek.ember.ui.theme.Fraunces),
    Inter("Inter", com.sarvarbek.ember.ui.theme.Inter),
}

const val MIN_FONT_SIZE = 14f
const val MAX_FONT_SIZE = 26f
const val MIN_LINE_SPACING = 1.4f
const val MAX_LINE_SPACING = 2.2f

/** Live, user-adjustable reading settings. Update with copy(). */
@Immutable
data class ReaderSettings(
    val theme: ReaderTheme = ReaderTheme.Paper,
    val fontSize: Float = 18f,
    val typeface: ReaderTypeface = ReaderTypeface.Spectral,
    val lineSpacing: Float = 1.7f,
) {
    /**
     * The nominal height of one body line (sp). Good enough for slack and spacing; anything that
     * has to land *on* a line boundary measures instead.
     */
    val lineHeight: Float get() = fontSize * lineSpacing

    /** The body text style for the current settings, in the theme's ink color. */
    fun bodyStyle() = TextStyle(
        fontFamily = typeface.family,
        fontSize = fontSize.sp,
        lineHeight = lineSpacing.em,
        color = theme.ink,
    )

    fun save(prefs: SharedPreferences) = prefs.edit {
        putString(KEY_THEME, theme.name)
        putFloat(KEY_FONT, fontSize)
        putString(KEY_FACE, typeface.name)
        putFloat(KEY_SPACING, lineSpacing)
    }

    companion object {
        private const val KEY_THEME = "rs_theme"
        private const val KEY_FONT = "rs_font"
        private const val KEY_FACE = "rs_face"
        private const val KEY_SPACING = "rs_spacing"

        fun load(prefs: SharedPreferences): ReaderSettings {
            val d = ReaderSettings()
            return ReaderSettings(
                theme = ReaderTheme.entries.find { it.name == prefs.getString(KEY_THEME, null) } ?: d.theme,
                fontSize = prefs.getFloat(KEY_FONT, d.fontSize).coerceIn(MIN_FONT_SIZE, MAX_FONT_SIZE),
                typeface = ReaderTypeface.entries.find { it.name == prefs.getString(KEY_FACE, null) } ?: d.typeface,
                lineSpacing = prefs.getFloat(KEY_SPACING, d.lineSpacing).coerceIn(MIN_LINE_SPACING, MAX_LINE_SPACING),
            )
        }
    }
}
