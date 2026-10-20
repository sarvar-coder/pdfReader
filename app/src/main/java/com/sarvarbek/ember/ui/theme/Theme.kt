package com.sarvarbek.ember.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.text.TextStyle

private val colors = lightColorScheme(
    primary = AppColors.ember,
    onPrimary = AppColors.card,
    primaryContainer = AppColors.emberSoft,
    onPrimaryContainer = AppColors.emberDeep,
    secondary = AppColors.gold,
    tertiary = AppColors.leaf,
    background = AppColors.paper,
    onBackground = AppColors.ink,
    surface = AppColors.card,
    onSurface = AppColors.ink,
    surfaceVariant = AppColors.card2,
    onSurfaceVariant = AppColors.inkSoft,
    outline = AppColors.line,
    outlineVariant = AppColors.line,
)

private val typography = Typography().run {
    fun TextStyle.inter() = copy(fontFamily = Inter)
    fun TextStyle.fraunces() = copy(fontFamily = Fraunces)
    copy(
        displayLarge = displayLarge.fraunces(),
        displayMedium = displayMedium.fraunces(),
        displaySmall = displaySmall.fraunces(),
        headlineLarge = headlineLarge.fraunces(),
        headlineMedium = headlineMedium.fraunces(),
        headlineSmall = headlineSmall.fraunces(),
        titleLarge = titleLarge.fraunces(),
        titleMedium = titleMedium.inter(),
        titleSmall = titleSmall.inter(),
        bodyLarge = bodyLarge.inter(),
        bodyMedium = bodyMedium.inter(),
        bodySmall = bodySmall.inter(),
        labelLarge = labelLarge.inter(),
        labelMedium = labelMedium.inter(),
        labelSmall = labelSmall.inter(),
    )
}

/** Light-only. Reader themes live in ReaderSettings. */
@Composable
fun EmberTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = colors, typography = typography, content = content)
}
