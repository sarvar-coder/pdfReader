package com.sarvarbek.ember.ui.widgets

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import com.sarvarbek.ember.ui.theme.AppColors
import com.sarvarbek.ember.ui.theme.Fraunces
import com.sarvarbek.ember.ui.theme.Inter

/** A centered icon + title + subtitle for a list with no content yet. */
@Composable
fun EmptyState(icon: ImageVector, title: String, subtitle: String, modifier: Modifier = Modifier) {
    Column(
        modifier.padding(start = 24.dp, top = 40.dp, end = 24.dp, bottom = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Box(
            Modifier.size(64.dp).background(AppColors.emberSoft, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = AppColors.emberDeep, modifier = Modifier.size(28.dp))
        }
        Text(
            title,
            modifier = Modifier.padding(top = 10.dp),
            textAlign = TextAlign.Center,
            fontFamily = Fraunces,
            fontSize = 18.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.ink,
        )
        Text(
            subtitle,
            textAlign = TextAlign.Center,
            fontFamily = Inter,
            fontSize = 13.5.sp,
            lineHeight = 1.4.em,
            color = AppColors.inkSoft,
        )
    }
}
