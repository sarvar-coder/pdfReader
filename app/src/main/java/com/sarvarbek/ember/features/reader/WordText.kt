package com.sarvarbek.ember.features.reader

/** Pure text helpers behind the long-press tooltip and the highlight painting. */

/**
 * The selected text as a single Word: surrounding punctuation stripped, inner apostrophes and hyphens kept
 * ("“don't,” → don't"). Null when the selection is empty or spans more than one word.
 */
fun singleWord(selected: String): String? {
    val word = selected.trim().trim { !it.isLetterOrDigit() }
    return word.takeIf { it.isNotEmpty() && it.none(Char::isWhitespace) }
}

private const val MAX_CONTEXT = 200

/**
 * The sentence of [paragraph] around char [offset], split on . ! ? followed by whitespace. Longer than
 * [MAX_CONTEXT] chars → a window of whole words around [offset], with ellipses.
 */
fun contextSentence(paragraph: String, offset: Int): String {
    val at = offset.coerceIn(0, paragraph.length)
    fun isEnd(i: Int) = paragraph[i] in ".!?" && (i + 1 == paragraph.length || paragraph[i + 1].isWhitespace())
    var start = at
    while (start > 0 && !isEnd(start - 1)) start--
    var end = at
    while (end < paragraph.length && !isEnd(end)) end++
    if (end < paragraph.length) end++ // keep the terminal punctuation
    val sentence = paragraph.substring(start, end).trim()
    if (sentence.length <= MAX_CONTEXT) return sentence

    // ponytail: char window cut at spaces; a real sentence segmenter (BreakIterator) if this reads badly.
    val from = (at - MAX_CONTEXT / 2).coerceIn(start, end - MAX_CONTEXT)
    val window = paragraph.substring(from, from + MAX_CONTEXT)
    val head = if (from > start) window.substringAfter(' ') else window
    val tail = if (from + MAX_CONTEXT < end) head.substringBeforeLast(' ') else head
    return (if (from > start) "…" else "") + tail.trim() + (if (from + MAX_CONTEXT < end) "…" else "")
}

/**
 * Every occurrence of each mark's text in [text], as (start, end, tag), sorted, with overlaps dropped
 * left-to-right.
 */
fun <T> markRanges(text: String, marks: List<Pair<String, T>>): List<Triple<Int, Int, T>> {
    val ranges = mutableListOf<Triple<Int, Int, T>>()
    for ((quote, tag) in marks) {
        if (quote.isEmpty()) continue
        var idx = text.indexOf(quote)
        while (idx >= 0) {
            ranges += Triple(idx, idx + quote.length, tag)
            idx = text.indexOf(quote, idx + quote.length)
        }
    }
    ranges.sortBy { it.first }
    var cursor = 0
    return ranges.filter { r -> (r.first >= cursor).also { if (it) cursor = r.second } }
}
