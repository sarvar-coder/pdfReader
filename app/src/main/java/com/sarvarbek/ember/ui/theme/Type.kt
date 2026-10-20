package com.sarvarbek.ember.ui.theme

import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.googlefonts.Font
import androidx.compose.ui.text.googlefonts.GoogleFont
import com.sarvarbek.ember.R

private val provider = GoogleFont.Provider(
    providerAuthority = "com.google.android.gms.fonts",
    providerPackage = "com.google.android.gms",
    certificates = R.array.com_google_android_gms_fonts_certs,
)

private fun googleFamily(name: String) = GoogleFont(name).let { font ->
    FontFamily(
        Font(font, provider, FontWeight.Normal),
        Font(font, provider, FontWeight.Medium),
        Font(font, provider, FontWeight.SemiBold),
        Font(font, provider, FontWeight.Bold),
    )
}

/** Fetched at runtime from Google Fonts; no bundled font assets. */
val Fraunces = googleFamily("Fraunces")
val Inter = googleFamily("Inter")
val Spectral = googleFamily("Spectral")
