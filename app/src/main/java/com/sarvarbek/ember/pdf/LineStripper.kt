package com.sarvarbek.ember.pdf

import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import com.tom_roush.pdfbox.text.TextPosition
import java.io.Writer

/**
 * Collects one [PdfLine] per text line, with the geometry [reflowLines] needs. PdfBox calls
 * [writeString] once per word of a line and [writeLineSeparator] between lines, so words are
 * gathered until a line or page ends. Text never goes to the output writer.
 */
internal class LineStripper : PDFTextStripper() {
    private val lines = ArrayList<PdfLine>()
    private val text = StringBuilder()
    private val sizes = HashMap<Float, Int>()
    private var top = Float.MAX_VALUE
    private var left = Float.MAX_VALUE
    private var right = -Float.MAX_VALUE

    init {
        sortByPosition = true
    }

    /** Lines of 0-based pages [first] until [end] (exclusive). */
    fun lines(document: PDDocument, first: Int, end: Int): List<PdfLine> {
        startPage = first + 1
        endPage = end
        writeText(document, NullWriter)
        return lines
    }

    override fun writeString(string: String, positions: List<TextPosition>) {
        text.append(string)
        for (p in positions) {
            top = minOf(top, p.yDirAdj - p.heightDir)
            left = minOf(left, p.xDirAdj)
            right = maxOf(right, p.xDirAdj + p.widthDirAdj)
            sizes.merge(p.fontSizeInPt, 1, Int::plus)
        }
    }

    override fun writeWordSeparator() {
        text.append(' ')
    }

    override fun writeLineSeparator() = flush()

    override fun writePageEnd() = flush()

    private fun flush() {
        if (sizes.isNotEmpty()) {
            lines += PdfLine(
                text = text.toString(),
                top = top.toDouble(),
                left = left.toDouble(),
                right = right.toDouble(),
                fontSize = sizes.maxBy { it.value }.key.toDouble(),
                pageIndex = currentPageNo - 1,
            )
        }
        text.setLength(0)
        sizes.clear()
        top = Float.MAX_VALUE
        left = Float.MAX_VALUE
        right = -Float.MAX_VALUE
    }

    private object NullWriter : Writer() {
        override fun write(cbuf: CharArray, off: Int, len: Int) = Unit
        override fun flush() = Unit
        override fun close() = Unit
    }
}
