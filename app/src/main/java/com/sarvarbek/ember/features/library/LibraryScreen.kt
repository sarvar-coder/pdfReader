package com.sarvarbek.ember.features.library

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
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
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyGridScope
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.sarvarbek.ember.AppContainer
import com.sarvarbek.ember.data.db.Book
import com.sarvarbek.ember.ui.theme.AppColors
import com.sarvarbek.ember.ui.theme.Fraunces
import com.sarvarbek.ember.ui.theme.Inter
import com.sarvarbek.ember.ui.widgets.BookCover
import com.sarvarbek.ember.ui.widgets.EmptyState
import com.sarvarbek.ember.ui.widgets.FloatingNavBarClearance
import com.sarvarbek.ember.ui.widgets.StreakCard
import java.time.LocalTime

internal fun greeting(hour: Int) = when (hour) {
    in 5..11 -> "Good morning, reader"
    in 12..17 -> "Good afternoon, reader"
    else -> "Good evening, reader"
}

/** Greeting header, streak card, and the 3-column shelf with an "Add a PDF" tile. */
@Composable
fun LibraryScreen(container: AppContainer, onOpenBook: (String) -> Unit, onOpenStats: () -> Unit) {
    val vm = viewModel { LibraryViewModel(container) }
    val shelf by vm.shelf.collectAsStateWithLifecycle()
    val stats by vm.stats.collectAsStateWithLifecycle()
    val importing by vm.importing.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    LaunchedEffect(vm) { vm.messages.collect { snackbar.showSnackbar(it) } }

    val resolver = LocalContext.current.applicationContext.contentResolver
    val pick = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        uri?.let { vm.importUri(resolver, it) }
    }
    val addPdf = { pick.launch(arrayOf("application/pdf")) }
    var removing by remember { mutableStateOf<Book?>(null) }

    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + FloatingNavBarClearance
    Box(Modifier.fillMaxSize()) {
        val books = shelf ?: return@Box
        LazyVerticalGrid(
            columns = GridCells.Fixed(3),
            modifier = Modifier.fillMaxSize().statusBarsPadding(),
            contentPadding = PaddingValues(start = 18.dp, top = 6.dp, end = 18.dp, bottom = bottom + 16.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            fullWidth("header") {
                Header(books.count { it.book.inProgress }, books.size, importing > 0)
            }
            if (books.isEmpty()) {
                fullWidth("empty") {
                    EmptyState(
                        Icons.Rounded.Add,
                        "Your shelf is empty",
                        "Import a PDF to start reading. Your highlights, bookmarks and streak will grow from here.",
                    )
                }
            } else {
                fullWidth("streak") {
                    stats?.let { StreakCard(it.streakDays, it.weekDots, onOpenStats) }
                }
                fullWidth("section") {
                    Text(
                        "On the shelf",
                        Modifier.padding(start = 4.dp, top = 12.dp),
                        fontFamily = Fraunces,
                        fontSize = 19.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = AppColors.ink,
                    )
                }
                items(books, key = { it.book.id }) { item ->
                    ShelfTile(item, onClick = { onOpenBook(item.book.id) }, onLongClick = { removing = item.book })
                }
            }
            item(key = "add") { AddTile(addPdf) }
        }
        SnackbarHost(snackbar, Modifier.align(Alignment.BottomCenter).padding(bottom = bottom))
    }

    removing?.let { book ->
        AlertDialog(
            onDismissRequest = { removing = null },
            title = { Text("Remove book?") },
            text = { Text("“${book.title}” and its saved file, highlights, bookmarks and reading sessions will be deleted.") },
            confirmButton = {
                TextButton(onClick = { vm.remove(book); removing = null }) { Text("Remove") }
            },
            dismissButton = { TextButton(onClick = { removing = null }) { Text("Cancel") } },
        )
    }
}

private fun LazyGridScope.fullWidth(key: String, content: @Composable () -> Unit) =
    item(key = key, span = { GridItemSpan(maxLineSpan) }) { content() }

@Composable
private fun Header(inProgress: Int, total: Int, importing: Boolean) {
    // ponytail: picked when the header composes, doesn't tick past a boundary while on screen.
    val greeting = remember { greeting(LocalTime.now().hour) }
    Column(Modifier.padding(start = 4.dp, top = 6.dp, end = 4.dp)) {
        Text(
            greeting,
            fontFamily = Inter,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 0.18.em,
            color = AppColors.inkFaint,
        )
        Spacer(Modifier.height(6.dp))
        Text(
            "Your shelf",
            fontFamily = Fraunces,
            fontSize = 30.sp,
            lineHeight = 1.05.em,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.ink,
        )
        Spacer(Modifier.height(4.dp))
        Text("$inProgress in progress · $total on the shelf", fontFamily = Inter, fontSize = 13.5.sp, color = AppColors.inkSoft)
        if (importing) {
            LinearProgressIndicator(
                Modifier.fillMaxWidth().padding(top = 10.dp),
                color = AppColors.ember,
                trackColor = AppColors.emberSoft,
            )
        }
    }
}

@Composable
private fun ShelfTile(item: ShelfBook, onClick: () -> Unit, onLongClick: () -> Unit) {
    val book = item.book
    Column(Modifier.combinedClickable(onClick = onClick, onLongClick = onLongClick)) {
        BookCover(
            title = book.title,
            gradient = remember(book.gradientStart, book.gradientEnd) { listOf(Color(book.gradientStart), Color(book.gradientEnd)) },
            modifier = Modifier.fillMaxWidth().aspectRatio(2f / 3f),
            coverFile = item.cover,
            coverStamp = item.coverStamp,
        )
        Spacer(Modifier.height(7.dp))
        Text(
            book.title,
            maxLines = 2,
            minLines = 2,
            overflow = TextOverflow.Ellipsis,
            fontFamily = Inter,
            fontSize = 12.sp,
            lineHeight = 1.15.em,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.ink,
        )
        Text(
            book.author,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            fontFamily = Inter,
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium,
            color = AppColors.inkFaint,
        )
    }
}

private val addShape = RoundedCornerShape(10.dp)

@Composable
private fun AddTile(onClick: () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .aspectRatio(2f / 3f)
            .drawBehind {
                drawRoundRect(
                    AppColors.inkFaint,
                    cornerRadius = CornerRadius(10.dp.toPx()),
                    style = Stroke(1.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 4.dp.toPx()))),
                )
            }
            .clip(addShape)
            .clickable(onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Box(Modifier.size(30.dp).background(AppColors.emberSoft, CircleShape), contentAlignment = Alignment.Center) {
            Text("+", fontSize = 20.sp, lineHeight = 1.em, color = AppColors.emberDeep)
        }
        Spacer(Modifier.height(8.dp))
        Text("Add a PDF", fontFamily = Inter, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = AppColors.inkSoft)
    }
}
