package com.sarvarbek.ember.features.words

import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Create
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.sarvarbek.ember.AppContainer
import com.sarvarbek.ember.data.COLLECTION_LIMIT
import com.sarvarbek.ember.data.db.CollectionWithCount
import com.sarvarbek.ember.data.db.WordDao
import com.sarvarbek.ember.ui.theme.AppColors
import com.sarvarbek.ember.ui.theme.Fraunces
import com.sarvarbek.ember.ui.theme.Inter
import com.sarvarbek.ember.ui.widgets.EmptyState
import com.sarvarbek.ember.ui.widgets.FloatingNavBarClearance
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.stateIn
import java.text.DateFormat
import java.util.Date

class WordsViewModel(dao: WordDao) : ViewModel() {
    /** Null until the first read, so the empty state never flashes. */
    val collections = dao.collectionsWithCounts()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)
}

private val cardShape = RoundedCornerShape(18.dp)

/** The Words tab: every Collection, newest first. */
@Composable
fun WordsScreen(container: AppContainer, onOpenCollection: (Long, String) -> Unit) {
    val vm = viewModel { WordsViewModel(container.db.words()) }
    val collections by vm.collections.collectAsStateWithLifecycle()
    val list = collections ?: return
    val insets = WindowInsets.safeDrawing.asPaddingValues()

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(
            start = 18.dp,
            end = 18.dp,
            top = insets.calculateTopPadding() + 12.dp,
            bottom = insets.calculateBottomPadding() + FloatingNavBarClearance,
        ),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item(key = "header") { Header(words = list.sumOf { it.count }, collections = list.size) }
        if (list.isEmpty()) {
            item(key = "empty") {
                EmptyState(
                    Icons.Rounded.Create,
                    title = "No words yet",
                    subtitle = "Long-press any word while reading to save it here.",
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
        items(list, key = { it.id }) { c -> CollectionCard(c) { onOpenCollection(c.id, c.name) } }
    }
}

@Composable
private fun Header(words: Int, collections: Int) {
    Column(Modifier.padding(start = 4.dp, top = 6.dp, end = 4.dp, bottom = 2.dp)) {
        Text(
            "Your words",
            fontFamily = Fraunces,
            fontSize = 30.sp,
            lineHeight = 32.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.ink,
        )
        Spacer(Modifier.height(4.dp))
        Text(
            "$words ${if (words == 1) "word" else "words"} · " +
                "$collections ${if (collections == 1) "collection" else "collections"}",
            fontFamily = Inter,
            fontSize = 13.5.sp,
            color = AppColors.inkSoft,
        )
    }
}

@Composable
private fun CollectionCard(c: CollectionWithCount, onClick: () -> Unit) {
    val full = c.count >= COLLECTION_LIMIT
    Surface(
        color = if (full) AppColors.card2 else AppColors.card,
        shape = cardShape,
        modifier = Modifier
            .fillMaxWidth()
            .clip(cardShape)
            .border(1.dp, if (full) AppColors.leaf.copy(alpha = 0.5f) else AppColors.line, cardShape)
            .clickable(onClick = onClick),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    c.name,
                    Modifier.weight(1f),
                    fontFamily = Fraunces,
                    fontSize = 19.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.ink,
                )
                Text(
                    if (full) "Full · ${c.count}/$COLLECTION_LIMIT" else "${c.count}/$COLLECTION_LIMIT",
                    fontFamily = Inter,
                    fontSize = 12.5.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = if (full) AppColors.leaf else AppColors.emberDeep,
                )
            }
            LinearProgressIndicator(
                progress = { c.count / COLLECTION_LIMIT.toFloat() },
                modifier = Modifier.fillMaxWidth().height(4.dp),
                color = if (full) AppColors.leaf else AppColors.ember,
                trackColor = AppColors.line,
                strokeCap = StrokeCap.Round,
                gapSize = 0.dp,
                drawStopIndicator = {},
            )
            Text(
                "Started ${DateFormat.getDateInstance(DateFormat.MEDIUM).format(Date(c.createdAt))}",
                fontFamily = Inter,
                fontSize = 12.sp,
                color = AppColors.inkFaint,
            )
        }
    }
}
