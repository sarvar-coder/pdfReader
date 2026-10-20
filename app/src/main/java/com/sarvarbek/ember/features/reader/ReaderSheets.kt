package com.sarvarbek.ember.features.reader

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sarvarbek.ember.data.db.Bookmark
import com.sarvarbek.ember.data.db.Highlight
import com.sarvarbek.ember.pdf.Chapter
import com.sarvarbek.ember.ui.theme.AppColors
import com.sarvarbek.ember.ui.theme.Fraunces
import com.sarvarbek.ember.ui.theme.Inter

/** The "Aa" reading controls: theme, font size, typeface, line spacing. Edits apply live. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsSheet(settings: ReaderSettings, onChange: (ReaderSettings) -> Unit, onDismiss: () -> Unit) {
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = AppColors.card) {
        Column(Modifier.padding(start = 22.dp, end = 22.dp, bottom = 30.dp)) {
            Text("Reading", fontFamily = Fraunces, fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = AppColors.ink)
            Spacer(Modifier.height(14.dp))

            Label("THEME")
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                for (theme in ReaderTheme.entries) {
                    Chip(selected = settings.theme == theme, Modifier.weight(1f), onClick = { onChange(settings.copy(theme = theme)) }) {
                        Box(
                            Modifier.fillMaxWidth().height(22.dp).clip(RoundedCornerShape(7.dp)).background(theme.bg)
                                .border(1.dp, AppColors.line, RoundedCornerShape(7.dp)),
                        )
                        Spacer(Modifier.height(7.dp))
                        ChipLabel(theme.label, settings.theme == theme)
                    }
                }
            }
            Spacer(Modifier.height(18.dp))

            Label("FONT SIZE")
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(AppColors.card2).padding(8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                StepButton("A−", settings.fontSize > MIN_FONT_SIZE) { onChange(settings.copy(fontSize = settings.fontSize - 1)) }
                Text("${settings.fontSize.toInt()} pt", fontFamily = Inter, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = AppColors.ink)
                StepButton("A+", settings.fontSize < MAX_FONT_SIZE) { onChange(settings.copy(fontSize = settings.fontSize + 1)) }
            }
            Spacer(Modifier.height(18.dp))

            Label("TYPEFACE")
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (face in ReaderTypeface.entries) {
                    Chip(selected = settings.typeface == face, Modifier.weight(1f), onClick = { onChange(settings.copy(typeface = face)) }) {
                        // Preview the chip in its own typeface.
                        Text(
                            face.label,
                            fontFamily = face.family,
                            fontSize = 14.sp,
                            color = if (settings.typeface == face) AppColors.ink else AppColors.inkSoft,
                        )
                    }
                }
            }
            Spacer(Modifier.height(18.dp))

            Label("LINE SPACING")
            Slider(
                value = settings.lineSpacing,
                onValueChange = { onChange(settings.copy(lineSpacing = it)) },
                valueRange = MIN_LINE_SPACING..MAX_LINE_SPACING,
                colors = SliderDefaults.colors(
                    thumbColor = AppColors.ember,
                    activeTrackColor = AppColors.ember,
                    inactiveTrackColor = AppColors.line,
                ),
            )
        }
    }
}

@Composable
private fun Label(text: String) {
    Text(
        text,
        Modifier.padding(bottom = 8.dp),
        fontFamily = Inter,
        fontSize = 11.sp,
        fontWeight = FontWeight.SemiBold,
        letterSpacing = 1.3.sp,
        color = AppColors.inkFaint,
    )
}

@Composable
private fun Chip(selected: Boolean, modifier: Modifier, onClick: () -> Unit, content: @Composable () -> Unit) {
    Column(
        modifier
            .clip(RoundedCornerShape(14.dp))
            .border(2.dp, if (selected) AppColors.ember else AppColors.line, RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 11.dp, horizontal = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) { content() }
}

@Composable
private fun ChipLabel(text: String, selected: Boolean) {
    Text(text, fontFamily = Inter, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = if (selected) AppColors.ink else AppColors.inkSoft)
}

@Composable
private fun StepButton(label: String, enabled: Boolean, onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        enabled = enabled,
        shape = RoundedCornerShape(10.dp),
        color = AppColors.card,
        shadowElevation = 1.dp,
        modifier = Modifier.size(width = 42.dp, height = 38.dp),
    ) {
        Box(contentAlignment = Alignment.Center) {
            Text(
                label,
                fontFamily = Fraunces,
                fontSize = 17.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.ink.copy(alpha = if (enabled) 1f else 0.4f),
            )
        }
    }
}

/**
 * The open Book's chapters, highlights and bookmarks; tapping a row jumps to its PDF page ([onJump] takes a
 * 0-based PDF page index; highlight/bookmark pages are stored 1-based).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ContentsSheet(
    chapters: List<Chapter>,
    highlights: List<Highlight>,
    bookmarks: List<Bookmark>,
    onJump: (Int) -> Unit,
    onDismiss: () -> Unit,
) {
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = AppColors.card) {
        if (chapters.isEmpty() && highlights.isEmpty() && bookmarks.isEmpty()) {
            Text(
                "Nothing saved yet. Tap the bookmark icon, or long-press a word and pick a color, while reading.",
                Modifier.padding(start = 22.dp, end = 22.dp, top = 8.dp, bottom = 40.dp),
                fontFamily = Inter,
                fontSize = 13.5.sp,
                lineHeight = 19.sp,
                color = AppColors.inkSoft,
            )
            return@ModalBottomSheet
        }
        LazyColumn(Modifier.padding(horizontal = 22.dp), contentPadding = PaddingValues(bottom = 24.dp)) {
            section("Chapters", chapters, null) {
                ContentRow(it.title, null, "p.${it.pageIndex + 1}", { onJump(it.pageIndex) }) {
                    Icon(Icons.AutoMirrored.Filled.List, null, Modifier.size(20.dp), tint = AppColors.inkSoft)
                }
            }
            section("Highlights", highlights.sortedBy { it.page }, { it.id }) {
                ContentRow(it.quote, null, "p.${it.page}", { onJump(it.page - 1) }) {
                    Box(Modifier.size(14.dp).clip(CircleShape).background(Color(it.colorValue)))
                }
            }
            section("Bookmarks", bookmarks, { it.id }) {
                ContentRow(it.chapter.ifEmpty { "Page ${it.page}" }, it.note.ifEmpty { null }, "p.${it.page}", { onJump(it.page - 1) }) {
                    Icon(BookmarkIcon, null, Modifier.size(20.dp), tint = AppColors.ember)
                }
            }
        }
    }
}

private fun <T> LazyListScope.section(title: String, rows: List<T>, key: ((T) -> Any)?, row: @Composable (T) -> Unit) {
    if (rows.isEmpty()) return
    item(key = "h-$title") {
        Text(
            title,
            Modifier.padding(top = 6.dp, bottom = 4.dp),
            fontFamily = Fraunces,
            fontSize = 18.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.ink,
        )
    }
    items(rows, key = key) { row(it) }
}

@Composable
private fun ContentRow(title: String, subtitle: String?, trailing: String, onClick: () -> Unit, leading: @Composable () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.width(32.dp)) { leading() }
        Column(Modifier.weight(1f)) {
            Text(title, fontFamily = Inter, fontSize = 14.5.sp, fontWeight = FontWeight.SemiBold, color = AppColors.ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
            if (subtitle != null) {
                Text(subtitle, fontFamily = Inter, fontSize = 12.5.sp, color = AppColors.inkSoft, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        Text(trailing, Modifier.padding(start = 8.dp), fontFamily = Inter, fontSize = 12.sp, color = AppColors.inkFaint)
    }
}
