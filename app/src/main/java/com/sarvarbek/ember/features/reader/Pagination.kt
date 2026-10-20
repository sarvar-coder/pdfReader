package com.sarvarbek.ember.features.reader

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.runtime.Immutable
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import kotlin.math.roundToInt

/**
 * The reflow pipeline, part 2: [Block]s → screen-sized [Page]s. [paginate] is pure over a `measure` function so
 * the split rules are unit-tested; the reader feeds it a background `TextMeasurer` with the same styles the
 * page renders with ([blockStyle]), so layout == render.
 */

/** The page box inset: left, top, right, bottom. */
val PagePadding = PaddingValues(start = 26.dp, top = 14.dp, end = 26.dp, bottom = 24.dp)

/** [PagePadding]'s horizontal and vertical totals, in dp. */
const val PAD_H_DP = 52f
const val PAD_V_DP = 38f

/** Heading top/bottom margins as a multiple of the font size, per tier. */
private const val TITLE_TOP = 0.9f
private const val TITLE_BOTTOM = 0.4f
private const val SUB_TOP = 0.25f
private const val SUB_BOTTOM = 0.5f

/** Top/bottom margin of a heading slice, in multiples of the font size (body has none). */
fun headingGaps(kind: BlockKind, isFirst: Boolean): Pair<Float, Float> = when (kind) {
    BlockKind.Title -> (if (isFirst) TITLE_TOP else 0f) to TITLE_BOTTOM
    BlockKind.Subtitle -> (if (isFirst) SUB_TOP else 0f) to SUB_BOTTOM
    BlockKind.Body -> 0f to 0f
}

/** The style each block kind is both measured and drawn with. */
fun ReaderSettings.blockStyle(kind: BlockKind): TextStyle {
    val body = bodyStyle().copy(
        textAlign = TextAlign.Justify,
        lineHeightStyle = LineHeightStyle(LineHeightStyle.Alignment.Center, LineHeightStyle.Trim.None),
    )
    return when (kind) {
        BlockKind.Body -> body
        BlockKind.Title -> body.copy(
            fontWeight = FontWeight.Bold, fontSize = (fontSize * 1.25f).sp, lineHeight = 1.3.em, textAlign = TextAlign.Center,
        )
        BlockKind.Subtitle -> body.copy(
            fontWeight = FontWeight.SemiBold, fontSize = (fontSize * 1.08f).sp, lineHeight = 1.3.em, textAlign = TextAlign.Center,
        )
    }
}

/** A slice of [Block] number [block] that lands on one page, starting at char [start] of the block's text. */
@Immutable
data class Frag(val kind: BlockKind, val text: String, val isFirst: Boolean, val block: Int, val start: Int)

/**
 * One reflowed page. [pdfPage] is the 0-based PDF page its first slice comes from; [charStart] is that slice's
 * offset in the whole Book's text (all block texts end to end), the anchor that survives repagination.
 */
@Immutable
data class Page(val frags: List<Frag>, val pdfPage: Int, val charStart: Int)

/** A measured block: each line's end offset (exclusive) and height, in px. */
class Measured(val lineEnds: IntArray, val lineHeights: FloatArray)

/**
 * Lays out [blocks] into pages that each fill at most [height] px. Body paragraphs split at line boundaries
 * across pages; headings stay whole. No line is ever clipped: a line taller than an empty page still gets one.
 * [fontPx] scales the heading margins.
 */
fun paginate(blocks: List<Block>, height: Float, fontPx: Float, measure: (Block) -> Measured): List<Page> {
    val blockStart = IntArray(blocks.size)
    for (i in 1 until blocks.size) blockStart[i] = blockStart[i - 1] + blocks[i - 1].text.length
    val pages = mutableListOf<Page>()
    var current = mutableListOf<Frag>()
    var used = 0f

    fun flush() {
        if (current.isNotEmpty()) {
            val first = current.first()
            pages += Page(current, blocks[first.block].page, blockStart[first.block] + first.start)
            current = mutableListOf()
            used = 0f
        }
    }

    blocks.forEachIndexed { index, block ->
        val m = measure(block)
        if (block.kind != BlockKind.Body) {
            val (top, bottom) = headingGaps(block.kind, isFirst = true)
            val blockHeight = (top + bottom) * fontPx + m.lineHeights.sum()
            if (used > 0 && used + blockHeight > height) flush()
            current += Frag(block.kind, block.text, isFirst = true, block = index, start = 0)
            used += blockHeight
            return@forEachIndexed
        }

        val lines = m.lineHeights.size
        var lineIdx = 0
        while (lineIdx < lines) {
            val remaining = height - used
            var consumed = 0
            var accH = 0f
            while (lineIdx + consumed < lines) {
                val lh = m.lineHeights[lineIdx + consumed]
                if (accH + lh > remaining && (consumed > 0 || used > 0)) break
                accH += lh
                consumed++
            }
            if (consumed == 0) { flush(); continue } // nothing fits on this partial page: start fresh

            val start = if (lineIdx == 0) 0 else m.lineEnds[lineIdx - 1]
            val end = m.lineEnds[lineIdx + consumed - 1]
            val raw = block.text.substring(start, end)
            // No indent on continuations; keep [start] pointing at the first char actually shown.
            val text = if (lineIdx == 0) raw else raw.trimStart()
            current += Frag(BlockKind.Body, text, isFirst = lineIdx == 0, block = index, start = start + raw.length - text.length)
            used += accH
            lineIdx += consumed
            if (lineIdx < lines) flush() // remainder goes to the next page
        }
    }
    flush()
    return pages.ifEmpty { listOf(Page(emptyList(), 0, 0)) }
}

/** Total chars of [blocks] end to end: the denominator of the reading fraction. */
fun totalChars(blocks: List<Block>): Int = blocks.sumOf { it.text.length }

/** The reading fraction at the start of [page]: its char offset over the Book's [total] chars. */
fun fractionOf(page: Page, total: Int): Double = if (total <= 0) 0.0 else page.charStart.toDouble() / total

/** The page holding the char a 0..1 reading [fraction] of [total] chars points at. */
fun pageForFraction(fraction: Double, pages: List<Page>, total: Int): Int {
    val char = (fraction.coerceIn(0.0, 1.0) * total).roundToInt()
    return (pages.indexOfLast { it.charStart <= char }).coerceAtLeast(0)
}
