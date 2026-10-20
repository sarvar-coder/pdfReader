package com.sarvarbek.ember.ui.widgets

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sarvarbek.ember.ui.theme.AppColors

/**
 * Space a scrolling tab screen leaves at its bottom (plus navigation-bar insets) so its last item
 * clears the floating bar.
 */
val FloatingNavBarClearance = 66.dp + 14.dp + 14.dp

private val shape = RoundedCornerShape(22.dp)

/** The rounded, floating, frosted-looking tab bar. */
@Composable
fun FloatingNavBar(
    items: List<Pair<String, ImageVector>>,
    selected: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    // ponytail: translucent fill, not a real backdrop blur (Compose has none before API 31
    // RenderEffect); add Haze or RenderEffect if the flat look bothers.
    Surface(
        modifier = modifier
            .navigationBarsPadding()
            .padding(start = 14.dp, end = 14.dp, bottom = 14.dp)
            .fillMaxWidth()
            .height(66.dp)
            .border(1.dp, AppColors.line, shape),
        shape = shape,
        color = AppColors.card.copy(alpha = 0.92f),
        shadowElevation = 10.dp,
    ) {
        Row(horizontalArrangement = Arrangement.SpaceAround) {
            items.forEachIndexed { i, (label, icon) ->
                val color = if (i == selected) AppColors.emberDeep else AppColors.inkFaint
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight()
                        .selectable(selected = i == selected, role = Role.Tab) { onSelect(i) },
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(23.dp))
                    Spacer(Modifier.height(4.dp))
                    Text(label, color = color, fontSize = 10.5.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}
