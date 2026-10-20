package com.sarvarbek.ember.features.reader

import androidx.compose.runtime.Immutable

/**
 * The reflow pipeline, part 1: plain extracted text → classified [Block]s. Pure string logic;
 * [paginate] turns the blocks into screen-sized pages.
 */

/** A justified body paragraph, or a centered bold heading: a [Title] (chapter/section) or a smaller [Subtitle]. */
enum class BlockKind { Title, Subtitle, Body }

/** [page] is the 0-based PDF page the block starts on. */
@Immutable
data class Block(val kind: BlockKind, val text: String, val page: Int = 0)

private enum class HeadingLevel { Title, Subtitle, None }

/** First-line indent prepended to body paragraphs (two em-spaces). */
const val INDENT = "  "

/** Section keywords that mark a title line (case-insensitive, at line start). */
private val titleKeyword = Regex(
    "^(chapter|part|book|volume|section|prologue|epilogue|introduction|" +
        "foreword|preface|afterword|appendix|contents|conclusion|dedication|" +
        "acknowledg)",
    RegexOption.IGNORE_CASE,
)
private val romanOnly = Regex("^[IVXLCDM]{1,7}\\.?$")
private val numberOnly = Regex("^\\d{1,4}\\.?$")
private val numberedSection = Regex("^\\d+([.)]\\d+)+[.)]?(\\s.{0,50})?$|^\\d+[.)]\\s+\\S.{0,48}$")
private val endsSentence = Regex("[.!?]$")
private val endsClause = Regex("[.!?:;,]$")
private val blankLine = Regex("\\n[ \\t]*\\n")
private val spaces = Regex("\\s+")
private val plainWords = Regex("^\\p{L}[\\p{L} ’'-]*$")

/** Fraction of cased letters that are uppercase (0 when there are fewer than two). */
private fun upperRatio(t: String): Double {
    var cased = 0
    var upper = 0
    for (ch in t) {
        if (ch.lowercaseChar() == ch.uppercaseChar()) continue // not a cased letter
        cased++
        if (ch == ch.uppercaseChar()) upper++
    }
    return if (cased < 2) 0.0 else upper.toDouble() / cased
}

/** True when most words in [t] start with an uppercase letter (Title Case). */
private fun isTitleCase(t: String): Boolean {
    val words = t.split(spaces).filter { it.isNotEmpty() }
    if (words.isEmpty()) return false
    val caps = words.count { val c = it[0]; c.uppercaseChar() == c && c.lowercaseChar() != c }
    return caps.toDouble() / words.size >= 0.6
}

/**
 * Classifies a single [line] as a heading tier (or None for body). When [allowTitleCase] is false, a
 * plain Title-Case line is body (only allowed for standalone lines or lines right under another heading).
 */
private fun classifyLine(line: String, allowTitleCase: Boolean): HeadingLevel {
    val t = line.trim()
    if (t.isEmpty() || t.length > 64) return HeadingLevel.None
    val endsSentence = endsSentence.containsMatchIn(t)

    // Titles: a lone roman/number marker; a short section-keyword line (guarded by length + punctuation so
    // "Part of the reason…" is not caught); or an all-caps line.
    if (romanOnly.matches(t) ||
        numberOnly.matches(t) ||
        (titleKeyword.containsMatchIn(t) && t.length <= 30 && !endsSentence) ||
        (upperRatio(t) >= 0.8 && !endsSentence)
    ) {
        return HeadingLevel.Title
    }

    // Subtitles: numbered sections, or (when allowed) short Title-Case lines.
    if (numberedSection.containsMatchIn(t) && !endsSentence) return HeadingLevel.Subtitle
    if (allowTitleCase && t.length <= 48 && !endsClause.containsMatchIn(t) && isTitleCase(t)) {
        return HeadingLevel.Subtitle
    }
    return HeadingLevel.None
}

/**
 * Turns extracted text into [Block]s. Works line-by-line within blank-line groups so a heading line is split
 * off from the body that follows it (even with no blank line between); wrapped body lines are re-joined into
 * paragraphs carrying a first-line indent (so layout == render).
 */
fun toBlocks(text: String): List<Block> {
    val result = mutableListOf<Block>()
    for (group in text.split(blankLine)) {
        val lines = group.split('\n').map { it.trim() }.filter { it.isNotEmpty() }
        if (lines.isEmpty()) continue
        val standalone = lines.size == 1

        val buffer = mutableListOf<String>()
        fun flushBody() {
            if (buffer.isNotEmpty()) {
                result += Block(BlockKind.Body, INDENT + buffer.joinToString(" "))
                buffer.clear()
            }
        }

        var prevHeading = false
        for (line in lines) {
            when (classifyLine(line, allowTitleCase = standalone || prevHeading)) {
                HeadingLevel.Title -> { flushBody(); result += Block(BlockKind.Title, line); prevHeading = true }
                HeadingLevel.Subtitle -> { flushBody(); result += Block(BlockKind.Subtitle, line); prevHeading = true }
                HeadingLevel.None -> { buffer += line; prevHeading = false }
            }
        }
        flushBody()
    }
    if (result.isEmpty()) result += Block(BlockKind.Body, text)
    return foldDisplayTitles(result)
}

/**
 * A display title set in mixed sizes ("WHAT the / FEELINGS / you most / SUPPRESS") is extracted one size per
 * line, so it arrives as headings alternating with short body fragments. Folds each such run into a single
 * title. A leading chapter label ("7", "Chapter 3") keeps its own block.
 *
 * Only a run with at least one word fragment bridging two headings is folded: plain consecutive headings
 * ("Chapter 1" then "Getting Started") stay apart.
 */
private fun foldDisplayTitles(blocks: List<Block>): List<Block> {
    fun isHeading(i: Int) = blocks[i].kind != BlockKind.Body
    fun isFragment(i: Int): Boolean {
        val t = blocks[i].text.trim()
        // Plain words only: a code line or figure label between two headings ("}", "9") is not a title part.
        return blocks[i].kind == BlockKind.Body &&
            t.length <= 40 &&
            ' ' in t && // one word ("Really") is a line of dialogue
            plainWords.matches(t)
    }

    val out = mutableListOf<Block>()
    var i = 0
    while (i < blocks.size) {
        if (!isHeading(i)) {
            out += blocks[i++]
            continue
        }
        var end = i
        var bridged = false
        while (true) {
            if (end + 1 < blocks.size && isHeading(end + 1)) {
                end++
            } else if (end + 2 < blocks.size && isFragment(end + 1) && isHeading(end + 2)) {
                end += 2
                bridged = true
            } else {
                break
            }
        }
        var start = i
        val label = blocks[i].text.trim()
        if (bridged &&
            (romanOnly.matches(label) || numberOnly.matches(label) ||
                (titleKeyword.containsMatchIn(label) && label.length <= 30))
        ) {
            out += blocks[start++]
        }
        if (bridged && end > start) {
            out += Block(BlockKind.Title, (start..end).joinToString(" ") { blocks[it].text.trim() })
        } else {
            out += blocks.subList(start, end + 1)
        }
        i = end + 1
    }
    return out
}
