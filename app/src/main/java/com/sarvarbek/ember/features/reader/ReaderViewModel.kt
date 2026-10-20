package com.sarvarbek.ember.features.reader

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.sarvarbek.ember.AppContainer
import com.sarvarbek.ember.data.AddResult
import com.sarvarbek.ember.data.db.Bookmark
import com.sarvarbek.ember.data.db.Highlight
import com.sarvarbek.ember.data.db.ReadingSession
import com.sarvarbek.ember.pdf.Chapter
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.roundToInt

/** What the reading area shows. */
sealed interface ReaderContent {
    data object Loading : ReaderContent
    data object Missing : ReaderContent
    data object Empty : ReaderContent
    data class Failed(val message: String) : ReaderContent

    /** [pdfPages] is the real PDF page count, for the "p / N" label; [chars] the text length, see [totalChars]. */
    @Immutable
    data class Ready(val blocks: List<Block>, val chapters: List<Chapter>, val pdfPages: Int, val chars: Int) : ReaderContent
}

/**
 * The open Book: its extracted blocks, saved highlights/bookmarks, reader settings, and the bookkeeping that
 * must outlive the composable (reading position, reading session). Writes that must land after the user
 * leaves go through `container.appScope`.
 */
class ReaderViewModel(private val container: AppContainer, private val bookId: String) : ViewModel() {
    private val books = container.db.books()

    private val _content = MutableStateFlow<ReaderContent>(ReaderContent.Loading)
    val content: StateFlow<ReaderContent> = _content.asStateFlow()

    val title: StateFlow<String> = books.observe(bookId).map { it?.title.orEmpty() }.distinctUntilChanged()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), "")
    val highlights: StateFlow<List<Highlight>> = container.db.highlights().forBook(bookId)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
    val bookmarks: StateFlow<List<Bookmark>> = container.db.bookmarks().forBook(bookId)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    private val _settings = MutableStateFlow(ReaderSettings.load(container.prefs))
    val settings: StateFlow<ReaderSettings> = _settings.asStateFlow()

    private val snacks = Channel<String>(Channel.BUFFERED)
    val messages = snacks.receiveAsFlow()

    /**
     * Canonical position: char offset of the current page's start over the Book's total chars, so it survives
     * repagination exactly. Plain fields: nothing recomposes on a page turn.
     */
    var fraction = 0.0
        private set
    private var pdfPage = 0
    private var chapter: String? = null
    private var totalPages = 0
    private var currentPage = 0
    private var loaded = false
    private var saveJob: Job? = null

    private var sessionStart: Long? = null
    private var sessionStartPage = 0

    init {
        viewModelScope.launch {
            val book = books.get(bookId)
            if (book != null) {
                fraction = book.readingFraction
                totalPages = book.totalPages
                currentPage = book.currentPage
                sessionStartPage = currentPage
                // Seeded from the saved row so an onStop before the first settled page can't write page 0.
                pdfPage = (book.currentPage - 1).coerceAtLeast(0)
                chapter = book.chapter
            }
            loaded = true
            _content.value = load()
        }
    }

    private suspend fun load(): ReaderContent {
        val file = container.files.pdf(bookId)
        if (!file.exists()) return ReaderContent.Missing
        return try {
            val pdf = container.pdf.extract(file)
            withContext(Dispatchers.Default) {
                val blocks = pdf.pages.flatMapIndexed { i, text ->
                    if (text.isBlank()) emptyList() else toBlocks(text).map { it.copy(page = i) }
                }
                // No outline → the headings the classifier found (Flutter's buildChapters fallback).
                val chapters = pdf.chapters.ifEmpty {
                    blocks.filter { it.kind == BlockKind.Title }.map { Chapter(it.text.trim(), it.page) }
                }
                if (blocks.isEmpty()) ReaderContent.Empty else ReaderContent.Ready(blocks, chapters, pdf.pages.size, totalChars(blocks))
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) { // includes NotImplementedError until the extractor lands
            ReaderContent.Failed(e.message ?: e.toString())
        }
    }

    fun updateSettings(s: ReaderSettings) {
        _settings.value = s
        s.save(container.prefs)
    }

    /**
     * Called when the reader settles on reflowed page [index]. Settling on the page the saved fraction already
     * points into (a restore, a repagination) keeps the fraction as is. The Book row is written ~500 ms later.
     */
    fun onPosition(index: Int, pages: List<Page>) {
        val ready = _content.value as? ReaderContent.Ready ?: return
        val page = pages.getOrNull(index) ?: return
        pdfPage = page.pdfPage
        chapter = chapterAt(pdfPage)
        if (pageForFraction(fraction, pages, ready.chars) == index) return
        fraction = fractionOf(page, ready.chars)
        if (totalPages > 0) currentPage = (fraction * totalPages).roundToInt()
        saveJob?.cancel()
        saveJob = viewModelScope.launch { delay(500); savePosition() }
    }

    private fun chapterAt(pdfPage: Int): String? =
        (_content.value as? ReaderContent.Ready)?.chapters?.lastOrNull { it.pageIndex <= pdfPage }?.title

    /** Writes the position now, on the app scope so it survives leaving the screen. */
    private fun savePosition() {
        if (!loaded || _content.value !is ReaderContent.Ready) return
        val f = fraction
        val page = currentPage
        val chapter = chapter
        container.appScope.launch {
            val book = books.get(bookId) ?: return@launch
            books.update(book.copy(readingFraction = f, currentPage = page, chapter = chapter ?: book.chapter))
        }
    }

    fun onStart() {
        if (sessionStart == null) {
            sessionStart = System.currentTimeMillis()
            sessionStartPage = currentPage
        }
    }

    /** Ends the session (dropping a trivial one) and flushes the position. */
    fun onStop() {
        saveJob?.cancel()
        savePosition()
        val start = sessionStart ?: return
        sessionStart = null
        val now = System.currentTimeMillis()
        val minutes = ((now - start) / 60_000).toInt()
        val pagesRead = (currentPage - sessionStartPage).coerceAtLeast(0)
        if (minutes <= 0 && pagesRead <= 0) return
        container.appScope.launch {
            container.db.sessions().upsert(
                ReadingSession(id = "rs-$now", bookId = bookId, startedAt = start, endedAt = now, pagesRead = pagesRead, minutes = minutes),
            )
        }
    }

    override fun onCleared() = onStop()

    fun addBookmark() {
        val page = pdfPage + 1
        val chapter = chapter ?: "Page $page"
        val note = title.value
        viewModelScope.launch {
            val now = System.currentTimeMillis()
            container.db.bookmarks().insert(Bookmark("bm-$now", bookId, page, chapter, note, now))
            snacks.send("Bookmarked page $page")
        }
    }

    fun addHighlight(quote: String, color: Color, pdfPage: Int) {
        val clean = quote.trim().replace(Regex("\\s+"), " ")
        if (clean.isEmpty()) return
        viewModelScope.launch {
            val now = System.currentTimeMillis()
            container.db.highlights().insert(
                Highlight("hl-$now", bookId, clean, color.toArgb().toLong() and 0xFFFFFFFFL, pdfPage + 1, chapterAt(pdfPage).orEmpty(), now),
            )
            snacks.send("Highlight saved")
        }
    }

    fun addWord(word: String, context: String) {
        viewModelScope.launch {
            val result = runCatching { container.words.add(word, context, bookId) }
                .onFailure { if (it is CancellationException) throw it }.getOrNull()
            when (result) {
                is AddResult.Added -> snacks.send("Added “$word” to ${result.collection}")
                is AddResult.Duplicate -> snacks.send("“$word” is already in ${result.collection}")
                AddResult.Empty -> Unit
                null -> snacks.send("Couldn’t add “$word”")
            }
        }
    }
}
