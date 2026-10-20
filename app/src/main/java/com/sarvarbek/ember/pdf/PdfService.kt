package com.sarvarbek.ember.pdf

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import androidx.core.graphics.createBitmap
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.io.MemoryUsageSetting
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.pdmodel.interactive.documentnavigation.outline.PDOutlineNode
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File

data class PdfInfo(val pageCount: Int, val title: String?, val author: String?)

/** A named division of a Book; [pageIndex] is the 0-based PDF page it starts on. */
@Serializable
data class Chapter(val title: String, val pageIndex: Int)

/**
 * Reflowed text, one string per PDF page, plus the Book's Chapters. `pages[i]` holds the
 * blank-line separated paragraphs that *begin* on page `i` (see [reflowLines]).
 */
@Serializable
data class PdfContent(val pages: List<String>, val chapters: List<Chapter>)

/** The on-disk cache form of [PdfContent]. */
fun encodeContent(content: PdfContent): String = Json.encodeToString(PdfContent.serializer(), content)

/** Parses [encodeContent] output; null when corrupt. */
fun decodeContent(json: String): PdfContent? =
    runCatching { Json.decodeFromString(PdfContent.serializer(), json) }.getOrNull()

/** The extraction cache beside [pdf]; the same path as `StorageFiles.pages(id)`. */
fun pagesCacheFile(pdf: File) = File(pdf.absoluteFile.parentFile, pdf.nameWithoutExtension + ".v4.pages.json")

/** PdfBox-Android text extraction and PdfRenderer covers. */
class PdfService(context: Context) {
    init {
        PDFBoxResourceLoader.init(context.applicationContext)
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val lock = Mutex()
    private val inFlight = HashMap<String, Deferred<PdfContent>>()

    /**
     * Page count and metadata; title/author are null when unusable. No file-name fallback: the
     * stored file is named by id, so the importer applies [cleanTitle] to the original name.
     */
    suspend fun info(file: File): PdfInfo = withContext(Dispatchers.IO) {
        load(file).use { doc ->
            val meta = doc.documentInformation
            PdfInfo(
                pageCount = doc.numberOfPages,
                title = usableMeta(meta?.title),
                author = usableMeta(meta?.author),
            )
        }
    }

    /**
     * Per-page reflowed text and chapters, from the cache beside [file] when present. Concurrent
     * calls for one file (import prefetch + reader open) share one extraction, which keeps running
     * if a caller is cancelled so the cache still gets written.
     */
    suspend fun extract(file: File): PdfContent {
        val key = file.absolutePath
        val job = lock.withLock {
            inFlight.getOrPut(key) {
                scope.async {
                    try {
                        cachedOrExtract(file)
                    } finally {
                        lock.withLock { inFlight.remove(key) }
                    }
                }
            }
        }
        return job.await()
    }

    private suspend fun cachedOrExtract(file: File): PdfContent {
        val cache = pagesCacheFile(file)
        if (cache.exists()) runCatching { decodeContent(cache.readText()) }.getOrNull()?.let { return it }
        val content = extractFresh(file)
        runCatching {
            val tmp = File(cache.path + ".tmp")
            tmp.writeText(encodeContent(content))
            tmp.renameTo(cache)
        }
        return content
    }

    /**
     * Line extraction dominates and pages are independent, so big books split their page range
     * across workers, each with its own PDDocument (not thread-safe). The reflow runs once over
     * every line: running-head detection needs the whole book.
     */
    // ponytail: each worker parses the whole file, so memory grows with the worker count; capped at
    // 4 with mixed memory/temp-file buffers. Share one parse per page range if big books ever OOM.
    private suspend fun extractFresh(file: File): PdfContent = coroutineScope {
        load(file).use { doc ->
            val count = doc.numberOfPages
            val workers = if (count < PARALLEL_MIN_PAGES) 1
            else (Runtime.getRuntime().availableProcessors() / 2).coerceIn(1, 4)
            val chunk = maxOf(1, (count + workers - 1) / workers)
            val rest = (chunk until count step chunk).map { start ->
                async { load(file).use { LineStripper().lines(it, start, minOf(start + chunk, count)) } }
            }
            val head = LineStripper().lines(doc, 0, minOf(chunk, count))
            val chapters = outline(doc)
            val lines = head + rest.awaitAll().flatten()
            // ponytail: chapters come only from the PDF outline; empty when it has none and the
            // reader derives its own fallback. Detect heading-like lines here if that's not enough.
            PdfContent(reflowLines(lines, count), chapters)
        }
    }

    /** Renders page 1 to [out] as PNG. False if the PDF can't be rendered. */
    suspend fun renderCover(file: File, out: File): Boolean = withContext(Dispatchers.IO) {
        runCatching {
            PdfRenderer(ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)).use { renderer ->
                renderer.openPage(0).use { page ->
                    val height = (COVER_WIDTH * page.height / page.width.toFloat()).toInt().coerceAtLeast(1)
                    val bitmap = createBitmap(COVER_WIDTH, height)
                    bitmap.eraseColor(Color.WHITE)
                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                    out.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
                        .also { bitmap.recycle() }
                }
            }
        }.getOrDefault(false)
    }

    private companion object {
        /** Below this many pages one worker is fast enough; each extra costs a document load. */
        const val PARALLEL_MIN_PAGES = 40

        /** Rendered cover width in pixels (~2x the grid cell); height follows the aspect ratio. */
        const val COVER_WIDTH = 300

        fun load(file: File): PDDocument = PDDocument.load(file, MemoryUsageSetting.setupMixed(16L shl 20))

        /** The outline flattened depth-first; a malformed destination skips only that entry. */
        fun outline(doc: PDDocument): List<Chapter> {
            val out = ArrayList<Chapter>()
            fun walk(node: PDOutlineNode) {
                for (item in node.children()) {
                    runCatching {
                        val title = item.title?.trim().orEmpty()
                        val page = item.findDestinationPage(doc)
                        if (page != null && title.isNotEmpty()) {
                            val index = doc.pages.indexOf(page)
                            if (index >= 0) out += Chapter(title, index)
                        }
                    }
                    walk(item)
                }
            }
            runCatching { doc.documentCatalog.documentOutline?.let(::walk) }
            return out
        }
    }
}
