package com.sarvarbek.ember.pdf

import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * One extracted line, reduced to what [reflowLines] needs. A plain class rather than PdfBox's
 * `TextPosition`s, so the normalization is unit-testable on the JVM without a real PDF.
 */
data class PdfLine(
    val text: String,
    val top: Double,
    val left: Double,
    val right: Double,
    val fontSize: Double,
    val pageIndex: Int,
)

/**
 * A metadata field worth showing, or null for the empty, the generic and the leaked file names
 * ("Microsoft Word - draft3.docx") producers leave behind.
 */
fun usableMeta(raw: String?): String? {
    val value = raw?.trim() ?: return null
    if (value.length < 2) return null
    if (JUNK_META.containsMatchIn(value)) return null
    return value
}

private val JUNK_META = Regex("""(?i)\.(pdf|docx?|indd|tex)$|^microsoft word|^untitled$""")

/**
 * A readable title from a file name stem, for PDFs whose metadata names none:
 * "31_10_2020_084952101_Essays_That_Will_Change" -> "Essays That Will Change".
 *
 * Underscores always separate words; hyphens and dots only when the file name has no spaces,
 * since "Node.js" or "Data-Intensive" in a spaced name are real. Pure digit runs (dates, upload
 * ids), version tags and download-site tags are dropped.
 */
fun cleanTitle(stem: String): String {
    var name = stem.replace('_', ' ').trim()
    if (' ' !in stem) name = name.replace(HYPHEN_DOT, " ")
    val words = name.split(WHITESPACE).filterNot { TITLE_JUNK.matches(it) }.toMutableList()
    // Short digit runs only go as a leading date ("31 10 2020 Essays"): one leading number is
    // content ("10 Rules for Life", "1984").
    if (words.size > 2 && DIGITS.matches(words[0]) && DIGITS.matches(words[1])) {
        while (words.size > 1 && DIGITS.matches(words.first())) words.removeAt(0)
    }
    val title = words.joinToString(" ").replace(TITLE_EDGES, "")
    return title.ifEmpty { stem }
}

private val HYPHEN_DOT = Regex("[-.]")
private val TITLE_JUNK = Regex("""(?i)^(\d{5,}|v\d+|pdf|compress|z-?lib\.?org|oceanofpdf\.com)$""")
private val DIGITS = Regex("""^\d+$""")
private val TITLE_EDGES = Regex("""^[-–\s]+|[-–\s]+$""")

/** Tabs, runs of spaces and Unicode spaces (NBSP...): Java's `\s` alone is ASCII-only. */
private val WHITESPACE = Regex("""[\s\p{Z}]+""")

/**
 * A lone capital the extractor split off its word at a kerning pair: "Y ou", "T able". The
 * producer pulls the pair together with a TJ offset, and the extractor reads the offset as a
 * word gap. Only kerning pairs qualify (the capital is one of [TVWYFP], the next letter one they
 * kern with), and a key combo or type parameter ("Shift+F on", "<T extends") is left alone.
 */
private val SPLIT_CAPITAL = Regex("""(?<![\p{L}\p{N}’'+\-<(])([TVWYFP]) ([aeoruy]\p{Ll}+)""")

/** Words that follow a lone capital on their own ("P and Q", "the Y axis"). */
private val STANDALONE_AFTER_CAPITAL =
    setOf("and", "are", "as", "at", "axis", "equals", "on", "or", "of", "over")

/** The same split in an all-caps word, around the A of a kerning pair: "F ACTORY", "WHA T". */
private val SPLIT_CAPS_LEFT = Regex("""(?<![\p{L}])([FPTVWY]) (A\p{Lu}+)""")
private val SPLIT_CAPS_RIGHT = Regex("""(?<![\p{L}])(\p{Lu}*A) ([TVWY])(?![\p{L}])""")

/** A two-digit list number split by kerning: "1 1. Feeling". */
private val SPLIT_NUMBER = Regex("""^(\d) (\d)([.)]) """)

/**
 * Re-joins words the extractor split at a kerning pair. The splits all fall at known kerning
 * pairs, so the text is enough; glyph geometry is too loose (ligatures, tracking) to rebuild
 * spaces from.
 */
// ponytail: pattern list, not a glyph rebuild. Measured on 9 books (Flutter/syncfusion): ~130
// fixes, a handful of misses on lone single-letter variables ("Y coords"). Re-measure on PdfBox
// output and rebuild spaces from TextPosition gaps if the miss rate grows.
fun repairKerningSplits(text: String): String = text
    .replace(SPLIT_CAPITAL) { m ->
        if (m.groupValues[2] in STANDALONE_AFTER_CAPITAL) m.value else m.groupValues[1] + m.groupValues[2]
    }
    .replace(SPLIT_CAPS_LEFT, "$1$2")
    .replace(SPLIT_CAPS_RIGHT, "$1$2")
    .replaceFirst(SPLIT_NUMBER, "$1$2$3 ")

/** Opens a list item, whose marker hangs left of the text that follows it. */
private val LIST_MARKER = Regex("""^([•▪◦·\-–—*]|\d{1,3}[.)]|[a-z][.)])\s""")

/** A list marker followed by a capitalized word: an item, not a wrapped line. */
private val LIST_ITEM_START = Regex("""^([•▪◦·\-–—*]|\d{1,3}[.)])\s+\p{Lu}""")

private val SENTENCE_END = Regex("""[.!?:"”)]$""")

/** Lines closer together than this many pitches belong to the same block. */
private const val BLOCK_PITCHES = 0.5

/** A top/bottom block must stand this many pitches clear of the page to be a running head. */
private const val ISOLATION_PITCHES = 1.5

/** A y position must carry such a candidate on at least this share of pages to be dropped. */
private const val REPEAT_SHARE = 0.4

/**
 * Turns extracted [lines] into reflow-ready page text: running heads and page numbers dropped,
 * wrapped lines re-joined into paragraphs, paragraphs separated by a blank line.
 *
 * Returns [pageCount] entries; `result[i]` holds the paragraphs that *begin* on page `i`, so a
 * paragraph spanning a page break stays whole and is attributed to the page it started on.
 */
// ponytail: assumes a single text column in reading order — a two-column PDF will interleave.
// Detect columns by clustering `left` if that ever matters.
fun reflowLines(lines: List<PdfLine>, pageCount: Int): List<String> {
    val pages = List(max(pageCount, 0)) { ArrayList<String>() }
    fun result() = pages.map { it.joinToString("\n\n") }
    if (lines.isEmpty()) return result()

    val ordered = lines.sortedWith(compareBy<PdfLine>({ it.pageIndex }, { it.top }, { it.left }))
    val rows = mergeRows(ordered)
    val pitch = pitchOf(rows)
    // Per page as well as overall: a page of code listings leads much tighter than a page of
    // prose, and one median for the whole book makes ordinary prose steps look like breaks.
    val pitchByPage = pitchPerPage(rows, pitch)
    val kept = withoutRunningHeads(rows, pitch)
    if (kept.isEmpty()) return result()

    // The measure: where full lines begin and end. Percentiles rather than the extremes (one wide
    // figure would define the column) and rather than the median (short code fragments drag it).
    val colLeft = percentile(DoubleArray(kept.size) { kept[it].left }, 0.15)
    val colRight = percentile(DoubleArray(kept.size) { kept[it].right }, 0.85)

    val buffer = StringBuilder()
    var bufferPage = kept.first().pageIndex
    var previous: PdfLine? = null
    var lastStep: Double? = null

    fun flush() {
        val text = buffer.trim()
        if (text.isNotEmpty() && bufferPage < pages.size) pages[bufferPage].add(text.toString())
        buffer.setLength(0)
    }

    for (raw in kept) {
        // Tabs and runs of spaces are layout, not language.
        val text = repairKerningSplits(raw.text.replace(WHITESPACE, " ").trim())
        if (text.isEmpty()) continue
        val line = raw.copy(text = text)
        val prev = previous
        val step = if (prev != null && prev.pageIndex == line.pageIndex) line.top - prev.top else null
        if (prev != null && startsParagraph(
                line, prev, step, lastStep ?: pitchByPage[line.pageIndex] ?: pitch, colLeft, colRight,
            )
        ) flush()
        if (buffer.isEmpty()) bufferPage = line.pageIndex else buffer.append(' ')
        buffer.append(text)
        previous = line
        if (step != null && step > 0.5) lastStep = step
    }
    flush()
    return result()
}

/**
 * Merges lines that share a baseline into one row, ordered left to right. An inline code span or
 * a differently-styled word can come back as its own line, nudged off the sentence's baseline.
 */
private fun mergeRows(ordered: List<PdfLine>): List<PdfLine> {
    val rows = ArrayList<PdfLine>(ordered.size)
    var i = 0
    while (i < ordered.size) {
        val first = ordered[i]
        var j = i
        while (j + 1 < ordered.size &&
            ordered[j + 1].pageIndex == first.pageIndex &&
            abs(ordered[j + 1].top - first.top) < max(first.fontSize, ordered[j + 1].fontSize) * 0.8
        ) j++
        if (j == i) {
            rows += first
        } else {
            val parts = ordered.subList(i, j + 1).sortedBy { it.left }
            // The widest part sets the row's type size: a body line keeps body size even when it
            // holds a small code span.
            val widest = parts.reduce { a, b -> if (b.right - b.left > a.right - a.left) b else a }
            rows += PdfLine(
                text = joinParts(parts),
                top = parts.minOf { it.top },
                left = parts.minOf { it.left },
                right = parts.maxOf { it.right },
                fontSize = widest.fontSize,
                pageIndex = first.pageIndex,
            )
        }
        i = j + 1
    }
    return rows
}

/**
 * Joins one row's parts left to right, inserting a space only where the parts stand apart. A
 * display line set with wide tracking arrives as touching parts: "CA T ALOG" otherwise.
 */
private fun joinParts(parts: List<PdfLine>): String {
    val out = StringBuilder()
    var previous: PdfLine? = null
    for (part in parts) {
        val text = part.text.trim()
        if (text.isEmpty()) continue
        if (previous != null && part.left - previous.right > part.fontSize * 0.25) out.append(' ')
        out.append(text)
        previous = part
    }
    return out.toString()
}

/** Sorts [values] in place. */
private fun percentile(values: DoubleArray, fraction: Double): Double {
    values.sort()
    return values[floor(values.size * fraction).toInt().coerceIn(0, values.size - 1)]
}

/** Same-page steps between consecutive rows, keyed by page. */
private inline fun forEachStep(rows: List<PdfLine>, action: (page: Int, step: Double) -> Unit) {
    for (i in 1 until rows.size) {
        if (rows[i].pageIndex != rows[i - 1].pageIndex) continue
        val step = rows[i].top - rows[i - 1].top
        if (step > 0.5) action(rows[i].pageIndex, step)
    }
}

/** The usual line-to-line step; falls back to 1.2x the median font size. */
private fun pitchOf(rows: List<PdfLine>): Double {
    val steps = ArrayList<Double>()
    forEachStep(rows) { _, step -> steps += step }
    if (steps.isEmpty()) {
        val sizes = rows.map { it.fontSize }.sorted()
        return (if (sizes.isEmpty()) 12.0 else sizes[sizes.size / 2]) * 1.2
    }
    steps.sort()
    return steps[steps.size / 2]
}

/** The usual line step of each page, [fallback] on a page with too few lines to say. */
private fun pitchPerPage(rows: List<PdfLine>, fallback: Double): Map<Int, Double> {
    val steps = HashMap<Int, ArrayList<Double>>()
    forEachStep(rows) { page, step -> steps.getOrPut(page) { ArrayList() } += step }
    return steps.mapValues { (_, s) -> if (s.size < 3) fallback else percentile(s.toDoubleArray(), 0.5) }
}

private fun bucket(top: Double) = (top / 3).roundToInt()

/**
 * Drops running heads, folios and page watermarks: the top or bottom block of a page, standing
 * clear of the rest of it, at a y position that repeats across many pages.
 *
 * All three conditions are required, and each rules out a different innocent. A chapter title
 * also stands clear at the top of its page — but only on its own page, so it fails repetition.
 * The first line of body text also opens a page — but it is one pitch from the second line, so
 * it fails isolation. Grouping into blocks first lets a running head beside a watermark count.
 */
private fun withoutRunningHeads(ordered: List<PdfLine>, pitch: Double): List<PdfLine> {
    // y bucket (3pt) -> the pages carrying a candidate there.
    val seen = HashMap<Int, MutableSet<Int>>()
    var pagesSeen = 0
    fun mark(from: Int, to: Int) {
        for (i in from..to) seen.getOrPut(bucket(ordered[i].top)) { HashSet() } += ordered[i].pageIndex
    }

    var start = 0
    while (start < ordered.size) {
        var end = start
        while (end + 1 < ordered.size && ordered[end + 1].pageIndex == ordered[start].pageIndex) end++
        pagesSeen++
        if (end > start) { // a one-line page tells us nothing
            var firstEnd = start
            while (firstEnd + 1 <= end &&
                ordered[firstEnd + 1].top - ordered[firstEnd].top < pitch * BLOCK_PITCHES
            ) firstEnd++
            var lastStart = end
            while (lastStart - 1 >= start &&
                ordered[lastStart].top - ordered[lastStart - 1].top < pitch * BLOCK_PITCHES
            ) lastStart--
            if (firstEnd < end &&
                ordered[firstEnd + 1].top - ordered[firstEnd].top > pitch * ISOLATION_PITCHES
            ) mark(start, firstEnd)
            if (lastStart > start &&
                ordered[lastStart].top - ordered[lastStart - 1].top > pitch * ISOLATION_PITCHES
            ) mark(lastStart, end)
        }
        start = end + 1
    }

    val threshold = max(3, (pagesSeen * REPEAT_SHARE).roundToInt())
    val dropped = seen.filterValues { it.size >= threshold }.keys
    if (dropped.isEmpty()) return ordered
    return ordered.filter { bucket(it.top) !in dropped }
}

/**
 * Whether [line] opens a new paragraph rather than continuing [previous]. [step] is the vertical
 * distance between them (null across a page break) and [leading] the step the text was running
 * at just before — local leading keeps tightly-led code from redefining a paragraph break.
 */
private fun startsParagraph(
    line: PdfLine,
    previous: PdfLine,
    step: Double?,
    leading: Double,
    colLeft: Double,
    colRight: Double,
): Boolean {
    // A change of type size separates a heading, and is the only signal across a page break.
    if (abs(line.fontSize - previous.fontSize) > 0.5) return true
    if (step != null && step > leading * 1.5) return true
    // A numbered or bulleted item after a finished sentence opens its own paragraph; the capital
    // after the marker keeps a wrapped "2. the" from breaking.
    if (LIST_ITEM_START.containsMatchIn(line.text) && SENTENCE_END.containsMatchIn(previous.text)) return true
    // A first-line indent, against the line above; a list item's hanging marker is the exception.
    if (line.left > previous.left + line.fontSize * 0.6 &&
        !LIST_MARKER.containsMatchIn(previous.text.trimStart())
    ) return true
    // Proportional to the measure: only a line giving up a real slice of it ends a paragraph.
    return previous.right < colRight - (colRight - colLeft) * 0.15
}
