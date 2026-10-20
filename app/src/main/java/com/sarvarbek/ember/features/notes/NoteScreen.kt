package com.sarvarbek.ember.features.notes

import android.util.Log
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Done
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.sarvarbek.ember.AppContainer
import com.sarvarbek.ember.ui.theme.AppColors
import com.sarvarbek.ember.ui.theme.Inter
import com.sarvarbek.ember.ui.theme.Spectral
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.nio.file.StandardCopyOption.ATOMIC_MOVE
import java.nio.file.StandardCopyOption.REPLACE_EXISTING

/** How long typing pauses before the notebook is written to disk. */
private const val SAVE_DEBOUNCE_MS = 800L

/** One writer for every notebook, so an older save can never land after a newer one. */
private val writes = Dispatchers.IO.limitedParallelism(1)

/**
 * A Book's notebook: one continuous text at StorageFiles.note(bookId). Saves 800 ms after typing
 * pauses, and on mode toggle, back, ON_STOP and when the screen goes away. Saves run on
 * [appScope] so they finish after the screen is gone, never before the file was read (a pre-load
 * empty field must not overwrite it), and never when nothing changed.
 */
class NoteViewModel(private val file: File, private val appScope: CoroutineScope) : ViewModel() {
    /** Null while the notebook is still being read off disk, and for good if it could not be read. */
    var text by mutableStateOf<String?>(null)
        private set

    /** The file exists but could not be read; editing stays off so nothing is saved over it. */
    var unreadable by mutableStateOf(false)
        private set

    /** The text as last written, so an unchanged notebook never rewrites. Set by the writer thread. */
    @Volatile private var saved = ""
    private var pending: Job? = null

    init {
        viewModelScope.launch {
            // On the writer, so a save still queued by a just-closed notebook lands before this read.
            withContext(writes) { runCatching { if (file.exists()) file.readText() else "" } }
                .onSuccess { saved = it; text = it }
                .onFailure { unreadable = true }
        }
    }

    fun edit(new: String) {
        if (text == null) return
        text = new
        pending?.cancel()
        pending = viewModelScope.launch {
            delay(SAVE_DEBOUNCE_MS)
            flush()
        }
    }

    fun flush() {
        pending?.cancel()
        val t = text ?: return
        if (t == saved) return
        appScope.launch(writes) {
            // Write-then-move, so a crash mid-write leaves the previous notebook intact. A failed write
            // leaves `saved` stale, so the next flush retries.
            try {
                val tmp = File(file.path + ".tmp")
                tmp.writeText(t)
                Files.move(tmp.toPath(), file.toPath(), REPLACE_EXISTING, ATOMIC_MOVE)
                saved = t
            } catch (e: IOException) {
                Log.w("NoteViewModel", "Couldn't save ${file.name}", e)
            }
        }
    }

    override fun onCleared() = flush()
}

// ponytail: fixed Paper/Spectral style; the reader's live settings live in features/reader, which
// notes may not import. Move ReaderSettings to ui/ or data/ if notes should follow the "Aa" sheet.
private val bodyStyle = TextStyle(
    fontFamily = Spectral,
    fontSize = 18.sp,
    lineHeight = 1.7.em,
    color = AppColors.readerPaperInk,
)

/** A Book's notebook, in writing mode (an editor) or reading mode (the text, read-only). */
@Composable
fun NoteScreen(container: AppContainer, bookId: String, title: String, onBack: () -> Unit) {
    val vm = viewModel { NoteViewModel(container.files.note(bookId), container.appScope) }
    var reading by rememberSaveable { mutableStateOf(false) }
    LifecycleEventEffect(Lifecycle.Event.ON_STOP) { vm.flush() }

    Column(Modifier.fillMaxSize().background(AppColors.readerPaperBg).statusBarsPadding()) {
        Row(Modifier.fillMaxWidth().padding(4.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = { vm.flush(); onBack() }) {
                Icon(Icons.AutoMirrored.Rounded.ArrowBack, "Back", tint = AppColors.readerPaperInk)
            }
            Text(
                "$title · Notes",
                Modifier.weight(1f),
                fontFamily = Inter,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.readerPaperInk,
                textAlign = TextAlign.Center,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            IconButton(onClick = { vm.flush(); reading = !reading }) {
                Icon(
                    if (reading) Icons.Rounded.Edit else Icons.Rounded.Done,
                    if (reading) "Write" else "Read",
                    tint = AppColors.emberDeep,
                )
            }
        }
        if (vm.unreadable) {
            Text(
                "Couldn't open this notebook.",
                Modifier.fillMaxWidth().padding(24.dp),
                style = bodyStyle.copy(color = AppColors.inkFaint, textAlign = TextAlign.Center),
            )
        }
        val text = vm.text ?: return@Column
        val body = Modifier.fillMaxSize().padding(horizontal = 24.dp, vertical = 12.dp)
        // ponytail: both modes scroll; Flutter pages them on a line grid. Ceiling: no page turns.
        // Upgrade: page by TextLayoutResult line tops, as the reader's pagination does.
        if (reading) {
            Text(
                text.ifBlank { "Nothing written yet." },
                Modifier.verticalScroll(rememberScrollState()).navigationBarsPadding().then(body),
                style = if (text.isBlank()) bodyStyle.copy(color = AppColors.inkFaint) else bodyStyle,
            )
        } else {
            BasicTextField(
                value = text,
                onValueChange = vm::edit,
                modifier = Modifier.navigationBarsPadding().imePadding().then(body),
                textStyle = bodyStyle,
                cursorBrush = SolidColor(AppColors.ember),
                decorationBox = { field ->
                    Box {
                        if (text.isEmpty()) {
                            Text("Write it in your own words…", style = bodyStyle.copy(color = AppColors.inkFaint))
                        }
                        field()
                    }
                },
            )
        }
    }
}
