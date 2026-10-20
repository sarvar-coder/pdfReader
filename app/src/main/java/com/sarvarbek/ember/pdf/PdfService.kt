package com.sarvarbek.ember.pdf

import android.content.Context
import java.io.File

data class PdfInfo(val pageCount: Int, val title: String?, val author: String?)

/** A named division of a Book; [pageIndex] is the 0-based PDF page it starts on. */
data class Chapter(val title: String, val pageIndex: Int)

/** Reflowed text, one string per PDF page, plus the Book's Chapters. */
data class PdfContent(val pages: List<String>, val chapters: List<Chapter>)

/** PdfBox-Android text extraction and PdfRenderer covers. */
class PdfService(private val context: Context) {
    suspend fun info(file: File): PdfInfo = TODO("feat/pdf-extractor")

    suspend fun extract(file: File): PdfContent = TODO("feat/pdf-extractor")

    /** Renders page 1 to [out] as PNG. False if the PDF can't be rendered. */
    suspend fun renderCover(file: File, out: File): Boolean = TODO("feat/pdf-extractor")
}
