package com.sarvarbek.ember.ui.widgets

import androidx.compose.animation.core.EaseInOut
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

private val flame = arrayOf(
    0f to Color(0xFFFFD28A),
    0.38f to Color(0xFFF59331),
    0.7f to Color(0xFFD8551D),
    1f to Color(0xFF9C3B14),
)
private val halo = Color(0xFFFF8A3D)

/** A glowing ember circle that gently flickers (scale + halo), looping every ~3.4 s. */
@Composable
fun EmberFlame(modifier: Modifier = Modifier, size: Dp = 62.dp) {
    // ponytail: ignores the OS "remove animations" setting; Compose already zeroes animator
    // duration scale there, which freezes this at its start value.
    val t by rememberInfiniteTransition(label = "ember").animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(3400, easing = EaseInOut), RepeatMode.Reverse),
        label = "flicker",
    )
    Canvas(
        modifier
            .size(size)
            .graphicsLayer { scaleX = 0.97f + t * 0.09f; scaleY = scaleX },
    ) {
        val r = this.size.minDimension / 2
        // Halo: a soft radial fade past the edge stands in for the Flutter box shadow.
        drawCircle(
            Brush.radialGradient(
                listOf(halo.copy(alpha = (0.7f + t * 0.3f) * 0.55f), Color.Transparent),
                center = center,
                radius = r * 1.5f,
            ),
            radius = r * 1.5f,
        )
        drawCircle(
            Brush.radialGradient(*flame, center = Offset(center.x, center.y + r * 0.2f), radius = r * 1.5f),
            radius = r,
        )
    }
}
