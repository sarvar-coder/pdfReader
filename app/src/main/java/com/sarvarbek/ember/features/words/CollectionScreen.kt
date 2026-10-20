package com.sarvarbek.ember.features.words

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.sarvarbek.ember.AppContainer
import com.sarvarbek.ember.data.COLLECTION_LIMIT
import com.sarvarbek.ember.data.db.EmberDatabase
import com.sarvarbek.ember.data.db.Word
import com.sarvarbek.ember.ui.theme.AppColors
import com.sarvarbek.ember.ui.theme.Fraunces
import com.sarvarbek.ember.ui.theme.Inter
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/** A saved Word with the title of the Book it came from (null once that Book is removed). */
data class WordRow(val word: Word, val source: String?)

class CollectionViewModel(private val db: EmberDatabase, collectionId: Long) : ViewModel() {
    val words = db.words().wordsIn(collectionId)
        .map { words ->
            val titles = words.map { it.bookId }.distinct().associateWith { db.books().get(it)?.title }
            words.map { WordRow(it, titles[it.bookId]) }
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    fun delete(word: Word) = viewModelScope.launch { db.words().deleteWord(word) }
}

/** [context] with every whole-word, case-insensitive occurrence of [word] in bold. */
fun boldWord(context: String, word: String): AnnotatedString = buildAnnotatedString {
    append(context)
    if (word.isBlank()) return@buildAnnotatedString
    Regex("\\b${Regex.escape(word)}\\b", RegexOption.IGNORE_CASE).findAll(context).forEach {
        addStyle(SpanStyle(fontWeight = FontWeight.Bold, color = AppColors.ink), it.range.first, it.range.last + 1)
    }
}

/** One Collection's Words, oldest first, each deletable. */
@Composable
fun CollectionScreen(container: AppContainer, collectionId: Long, name: String, onBack: () -> Unit) {
    val vm = viewModel { CollectionViewModel(container.db, collectionId) }
    val rows by vm.words.collectAsStateWithLifecycle()

    Column(Modifier.fillMaxSize().background(AppColors.paper).statusBarsPadding()) {
        Row(Modifier.fillMaxWidth().padding(4.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "Back", tint = AppColors.ink)
            }
            Text(
                name,
                Modifier.weight(1f),
                fontFamily = Fraunces,
                fontSize = 20.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.ink,
            )
            rows?.let {
                Text(
                    "${it.size}/$COLLECTION_LIMIT",
                    Modifier.padding(end = 16.dp),
                    fontFamily = Inter,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.emberDeep,
                )
            }
        }
        HorizontalDivider(color = AppColors.line)
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(
                start = 18.dp,
                top = 18.dp,
                end = 18.dp,
                bottom = 18.dp + WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding(),
            ),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            items(rows.orEmpty(), key = { it.word.id }) { row -> WordCard(row) { vm.delete(row.word) } }
        }
    }
}

@Composable
private fun WordCard(row: WordRow, onDelete: () -> Unit) {
    Surface(color = AppColors.card, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Row(Modifier.padding(start = 16.dp, top = 12.dp, bottom = 14.dp)) {
            Column(Modifier.weight(1f).padding(top = 2.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    row.word.text,
                    fontFamily = Fraunces,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.ink,
                )
                if (row.word.context.isNotBlank()) {
                    Text(
                        boldWord(row.word.context, row.word.text),
                        fontFamily = Fraunces,
                        fontStyle = FontStyle.Italic,
                        fontSize = 14.5.sp,
                        lineHeight = 1.45.em,
                        color = AppColors.inkSoft,
                    )
                }
                row.source?.let {
                    Text(it, fontFamily = Inter, fontSize = 12.sp, color = AppColors.inkFaint)
                }
            }
            IconButton(onClick = onDelete) {
                Icon(Icons.Rounded.Delete, contentDescription = "Delete ${row.word.text}", tint = AppColors.inkFaint)
            }
        }
    }
}
