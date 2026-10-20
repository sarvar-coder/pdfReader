package com.sarvarbek.ember.features.library

import android.content.ContentResolver
import android.net.Uri
import android.provider.OpenableColumns
import androidx.compose.runtime.Immutable
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.sarvarbek.ember.AppContainer
import com.sarvarbek.ember.data.ReadingStats
import com.sarvarbek.ember.data.db.Book
import com.sarvarbek.ember.data.readingStatsFlow
import com.sarvarbek.ember.pdf.cleanTitle
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.File
import java.util.concurrent.ConcurrentHashMap

/** A shelf tile: the Book plus its rendered cover, if any. [coverStamp] changes when the cover file does. */
@Immutable
data class ShelfBook(val book: Book, val cover: File?, val coverStamp: Long)

val Book.inProgress get() = currentPage in 1 until totalPages

/** Cover fallback gradients (ARGB pairs), picked by title hash so each Book gets a distinct one. */
object CoverPalette {
    private val gradients = listOf(
        0xFF3F5A3A to 0xFF7E8A5A,
        0xFFBE4F1E to 0xFFDD7536,
        0xFF1F3A52 to 0xFF6BB4F0,
        0xFF8A5A1E to 0xFFD6A24B,
        0xFF4A4A6A to 0xFFA89C8A,
        0xFFB23E5A to 0xFFF08AA6,
    )

    fun forTitle(title: String) = gradients[Math.floorMod(title.hashCode(), gradients.size)]
}

/** A title from the original file name, for PDFs whose metadata names none: "Some_Book.pdf" -> "Some Book". */
internal fun titleFromFileName(name: String) = cleanTitle(name.substringBeforeLast('.')).ifBlank { "Untitled" }

class LibraryViewModel(private val c: AppContainer) : ViewModel() {
    /** Bumped when a cover lands on disk, so the shelf re-reads cover stamps. */
    private val coverTick = MutableStateFlow(0)

    /** Null until the first load, so the empty state never flashes. */
    val shelf: StateFlow<List<ShelfBook>?> = combine(c.db.books().all(), coverTick) { books, _ ->
        books.map { b ->
            val cover = c.files.cover(b.id)
            val stamp = cover.lastModified() // 0 when missing
            ShelfBook(b, cover.takeIf { stamp > 0 }, stamp)
        }
    }.flowOn(Dispatchers.IO).stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    val stats: StateFlow<ReadingStats?> =
        readingStatsFlow(c.db).stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    /** Imports in flight. */
    val importing = MutableStateFlow(0)

    private val _messages = Channel<String>(Channel.BUFFERED)
    val messages = _messages.receiveAsFlow()

    init {
        // PDFs shared or opened from other apps: already copied into the cache under their original name.
        viewModelScope.launch {
            c.incomingPdf.filterNotNull().collect { f ->
                c.incomingPdf.value = null
                c.appScope.launch(Dispatchers.IO) {
                    import(f.name) { dest ->
                        if (!f.renameTo(dest)) f.copyTo(dest, overwrite = true).also { f.delete() }
                    }
                }
            }
        }
        // Backfill covers a killed import never rendered.
        c.appScope.launch(Dispatchers.IO) {
            c.db.books().all().first()
                .filter { !background.containsKey(it.id) && !c.files.cover(it.id).exists() && c.files.pdf(it.id).exists() }
                .forEach { renderCover(c.files.pdf(it.id), it.id) }
        }
    }

    /** Copies a picked document into app storage and adds it as a Book. Survives leaving the screen. */
    fun importUri(resolver: ContentResolver, uri: Uri) {
        c.appScope.launch(Dispatchers.IO) {
            val name = runCatching {
                resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                    ?.use { if (it.moveToFirst()) it.getString(0) else null }
            }.getOrNull() ?: "Untitled.pdf"
            import(name) { dest ->
                (resolver.openInputStream(uri) ?: error("can't open $uri")).use { input ->
                    dest.outputStream().use { input.copyTo(it) }
                }
            }
        }
    }

    fun remove(book: Book) {
        c.appScope.launch(Dispatchers.IO) {
            // Stop its cover/text work first, so nothing writes files after they're deleted.
            background.remove(book.id)?.cancelAndJoin()
            c.db.books().deleteBook(book.id)
            c.files.deleteAll(book.id)
            _messages.trySend("Removed “${book.title}”")
        }
    }

    /** Runs on IO in appScope. [write] puts the PDF bytes at the given destination. */
    private suspend fun import(fileName: String, write: (File) -> Unit) {
        importing.update { it + 1 }
        val id = "pdf-${System.nanoTime()}"
        val pdf = c.files.pdf(id)
        try {
            write(pdf)
            // Best-effort metadata: a parse failure still adds the Book.
            val info = runCatching { c.pdf.info(pdf) }.getOrNull()
            val title = info?.title?.takeIf { it.isNotBlank() } ?: titleFromFileName(fileName)
            val (start, end) = CoverPalette.forTitle(title)
            // Detached so the shelf shows the Book now: gradient until the cover lands, text cached for first open.
            // Registered before the row exists, so a remove always finds it.
            val job = c.appScope.launch(Dispatchers.IO, CoroutineStart.LAZY) {
                launch { renderCover(pdf, id) }
                launch { runCatching { c.pdf.extract(pdf) } }
            }
            background[id] = job
            job.invokeOnCompletion { background.remove(id, job) }
            c.db.books().upsert(Book(id, title, info?.author ?: "", 0, info?.pageCount ?: 0, start, end))
            _messages.trySend("Added “$title”")
            job.start()
        } catch (e: Exception) {
            c.files.deleteAll(id)
            _messages.trySend("Couldn’t import PDF: ${e.message}")
        } finally {
            importing.update { it - 1 }
        }
    }

    /** Renders to a temp file and keeps it only if the Book still exists, so a remove mid-render leaves no orphan. */
    private suspend fun renderCover(pdf: File, id: String) {
        val cover = c.files.cover(id)
        val tmp = File(cover.path + ".tmp") // "<id>." prefix: StorageFiles.deleteAll sweeps it too
        val ok = runCatching { c.pdf.renderCover(pdf, tmp) }.getOrDefault(false)
        if (ok && c.db.books().get(id) != null && tmp.renameTo(cover)) coverTick.update { it + 1 } else tmp.delete()
    }

    private companion object {
        // ponytail: process-wide so a recreated ViewModel still sees in-flight work; one Job per Book id.
        /** Background cover/text work per Book id, cancelled on remove. */
        val background = ConcurrentHashMap<String, Job>()
    }
}
