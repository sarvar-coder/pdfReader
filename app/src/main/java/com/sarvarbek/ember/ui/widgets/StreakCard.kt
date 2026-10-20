package com.sarvarbek.ember.ui.widgets

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import com.sarvarbek.ember.ui.theme.Fraunces
import com.sarvarbek.ember.ui.theme.Inter

private val cardShape = RoundedCornerShape(24.dp)
private val dotShape = RoundedCornerShape(6.dp)
private val cardBrush = Brush.linearGradient(
    0f to Color(0xFF2A211A),
    0.6f to Color(0xFF241C15),
    1f to Color(0xFF1D160F),
    start = Offset(Float.POSITIVE_INFINITY, 0f),
    end = Offset(0f, Float.POSITIVE_INFINITY),
)
private val litDot = Brush.verticalGradient(listOf(Color(0xFFF7A94E), Color(0xFFD8551D)))
private val unlitDot = Color(0x1FFFFFFF)
private val muted = Color(0xFFC8A98A)
private val bright = Color(0xFFF4EBDD)

/** Dark card with a flickering ember, the streak day count, and the last seven days as dots. */
@Composable
fun StreakCard(streakDays: Int, weekDots: List<Boolean>, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier
            .fillMaxWidth()
            .padding(top = 4.dp)
            .shadow(14.dp, cardShape)
            .clip(cardShape)
            .background(cardBrush)
            .clickable(onClick = onClick)
            .padding(start = 18.dp, top = 18.dp, end = 18.dp, bottom = 16.dp),
    ) {
        Text(
            "Reading streak",
            fontFamily = Inter,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 0.16.em,
            color = muted,
        )
        Spacer(Modifier.height(6.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            EmberFlame(size = 62.dp)
            Spacer(Modifier.width(16.dp))
            Column(Modifier.weight(1f)) {
                Text(
                    "$streakDays",
                    fontFamily = Fraunces,
                    fontSize = 40.sp,
                    lineHeight = 1.em,
                    fontWeight = FontWeight.SemiBold,
                    color = bright,
                )
                Spacer(Modifier.height(4.dp))
                Text("days in a row", fontFamily = Inter, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = muted)
            }
            WeekDots(weekDots)
        }
    }
}

/** Lit days get a warm gradient; the most recent lit day is outlined. */
@Composable
private fun WeekDots(days: List<Boolean>) {
    val today = days.lastIndexOf(true)
    Row(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
        days.forEachIndexed { i, lit ->
            Box(
                Modifier
                    .size(9.dp, 34.dp)
                    .clip(dotShape)
                    .then(if (lit) Modifier.background(litDot) else Modifier.background(unlitDot))
                    .then(if (i == today) Modifier.border(2.dp, bright, dotShape) else Modifier),
            )
        }
    }
}
