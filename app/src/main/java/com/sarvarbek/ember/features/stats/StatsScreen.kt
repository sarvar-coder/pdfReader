package com.sarvarbek.ember.features.stats

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.sarvarbek.ember.AppContainer
import com.sarvarbek.ember.data.ReadingStats
import com.sarvarbek.ember.data.readingStatsFlow
import com.sarvarbek.ember.ui.theme.AppColors
import com.sarvarbek.ember.ui.theme.Fraunces
import com.sarvarbek.ember.ui.theme.Inter
import com.sarvarbek.ember.ui.widgets.EmberFlame
import com.sarvarbek.ember.ui.widgets.FloatingNavBarClearance

/** Heatmap level 0 (empty) to 4, matching the mockup's legend. */
private val levelColors = listOf(
    AppColors.card2,
    Color(0xFFF3DCBF),
    Color(0xFFEEB988),
    Color(0xFFE08A45),
    Color(0xFFC75A22),
)

/** Streak hero, a 2x2 stat grid, and the quarter heatmap. */
@Composable
fun StatsScreen(container: AppContainer) {
    val stats by remember { readingStatsFlow(container.db) }.collectAsStateWithLifecycle(null)
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + FloatingNavBarClearance
    val s = stats ?: return
    Column(
        Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(start = 18.dp, top = 6.dp, end = 18.dp, bottom = bottom + 16.dp),
    ) {
        Text(
            "Keep the flame",
            Modifier.padding(start = 4.dp, top = 6.dp),
            fontFamily = Inter,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 0.18.em,
            color = AppColors.inkFaint,
        )
        StreakHero(s)
        Spacer(Modifier.height(22.dp))
        StatGrid(
            listOf(
                "${s.minutesToday} min" to "Read today",
                "${s.pagesThisWeek}" to "Pages this week",
                "${s.booksFinished}" to "Books finished",
                "${s.hoursThisMonth} hrs" to "This month",
            ),
        )
        Spacer(Modifier.height(22.dp))
        Heatmap(s.heatmapLevels)
    }
}

@Composable
private fun StreakHero(s: ReadingStats) {
    Column(
        Modifier.fillMaxWidth().padding(top = 14.dp, bottom = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        EmberFlame(size = 96.dp)
        Spacer(Modifier.height(18.dp))
        Text(
            "${s.streakDays}",
            fontFamily = Fraunces,
            fontSize = 54.sp,
            lineHeight = 1.em,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.ink,
        )
        Spacer(Modifier.height(4.dp))
        Text(
            "day streak · longest yet was ${s.longestStreak}",
            fontFamily = Inter,
            fontSize = 13.sp,
            color = AppColors.inkSoft,
        )
    }
}

/** A raised card: fill, hairline border and a soft shadow. */
private fun Modifier.card(shape: Shape) =
    shadow(4.dp, shape, ambientColor = Color(0x11281E12), spotColor = Color(0x11281E12))
        .background(AppColors.card, shape)
        .border(1.dp, AppColors.line, shape)

private val statShape = RoundedCornerShape(18.dp)

/** Value/label pairs laid out two per row. */
@Composable
private fun StatGrid(stats: List<Pair<String, String>>) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        stats.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                row.forEach { (value, label) ->
                    Column(
                        Modifier.weight(1f).aspectRatio(1.7f).card(statShape).padding(16.dp),
                        verticalArrangement = Arrangement.Center,
                    ) {
                        Text(value, fontFamily = Fraunces, fontSize = 26.sp, fontWeight = FontWeight.SemiBold, color = AppColors.ink)
                        Spacer(Modifier.height(3.dp))
                        Text(label, fontFamily = Inter, fontSize = 12.sp, color = AppColors.inkSoft)
                    }
                }
            }
        }
    }
}

private val heatShape = RoundedCornerShape(20.dp)
private val cellShape = RoundedCornerShape(4.dp)
private val legendShape = RoundedCornerShape(3.dp)

/** 13 columns of day cells, oldest first, filled row by row. */
@Composable
private fun Heatmap(levels: List<Int>) {
    Column(Modifier.fillMaxWidth().card(heatShape).padding(18.dp)) {
        Text("This quarter", fontFamily = Fraunces, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = AppColors.ink)
        Spacer(Modifier.height(14.dp))
        Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
            levels.chunked(13).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                    row.forEach { Cell(levelColors[it.coerceIn(0, 4)], cellShape, Modifier.weight(1f).aspectRatio(1f)) }
                    repeat(13 - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
        Spacer(Modifier.height(12.dp))
        Legend()
    }
}

@Composable
private fun ColumnScope.Legend() {
    Row(
        Modifier.align(Alignment.End),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text("Less", fontFamily = Inter, fontSize = 11.sp, color = AppColors.inkFaint)
        levelColors.forEach { Cell(it, legendShape, Modifier.size(11.dp)) }
        Text("More", fontFamily = Inter, fontSize = 11.sp, color = AppColors.inkFaint)
    }
}

@Composable
private fun Cell(color: Color, shape: Shape, modifier: Modifier) = Box(modifier.background(color, shape))
