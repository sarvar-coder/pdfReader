package com.sarvarbek.ember.features.reader

import android.os.SystemClock
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntRect
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupPositionProvider
import androidx.compose.ui.window.PopupProperties
import com.sarvarbek.ember.ui.theme.AppColors
import com.sarvarbek.ember.ui.theme.Inter
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** The four highlight swatches offered in the selection tooltip. */
private val Swatches = listOf(AppColors.hlYellow, AppColors.hlGreen, AppColors.hlBlue, AppColors.hlPink)

/**
 * A long-press selection: chars [start, end) of slice [frag] on reflowed page [page]. [done] once the
 * finger lifts, which is when the tooltip appears.
 */
@Immutable
data class WordSelection(val page: Int, val frag: Int, val start: Int, val end: Int, val done: Boolean)

/**
 * Keeps the lift of a long press from also counting as a page tap (which would clear the fresh selection and
 * toggle the chrome): taps are ignored while a long press is live and just after it ends.
 */
private class PressGate {
    var active = false
    private var endedAt = 0L

    fun end() {
        active = false
        endedAt = SystemClock.uptimeMillis()
    }

    fun blocksTap() = active || SystemClock.uptimeMillis() - endedAt < 300
}

/**
 * One swipeable reading page. A tap goes to [onTap]; a long press on a slice selects a word (dragging extends
 * it) and on release shows the highlight / add-to-words tooltip.
 */
@Composable
fun ReaderPage(
    page: Page,
    index: Int,
    blocks: List<Block>,
    settings: ReaderSettings,
    marks: List<Pair<String, Color>>,
    selection: WordSelection?,
    onSelect: (WordSelection?) -> Unit,
    onTap: () -> Unit,
    onHighlight: (quote: String, color: Color, pdfPage: Int) -> Unit,
    onAddWord: (word: String, context: String) -> Unit,
) {
    val tap by rememberUpdatedState(onTap)
    val gate = remember { PressGate() }
    val fontDp = with(LocalDensity.current) { settings.fontSize.sp.toDp() }
    Column(
        Modifier
            .fillMaxSize()
            .pointerInput(Unit) { detectTapGestures { if (!gate.blocksTap()) tap() } }
            // ponytail: scroll absorbs the rare re-wrap overflow; Flutter's "more below" chevron cue is skipped.
            .verticalScroll(rememberScrollState())
            .padding(PagePadding),
    ) {
        page.frags.forEachIndexed { i, frag ->
            val (top, bottom) = headingGaps(frag.kind, frag.isFirst)
            if (top > 0) Spacer(Modifier.height(fontDp * top))
            val sel = selection?.takeIf { it.page == index && it.frag == i }
            FragText(
                frag = frag,
                settings = settings,
                marks = marks,
                selection = sel,
                gate = gate,
                onSelect = { range, done -> onSelect(range?.let { WordSelection(index, i, it.start, it.end, done) }) },
                onHighlight = { color ->
                    onHighlight(frag.text.substring(sel!!.start, sel.end), color, blocks[frag.block].page)
                    onSelect(null)
                },
                onAddWord = singleWord(sel?.let { frag.text.substring(it.start, it.end) }.orEmpty())?.let { word ->
                    {
                        onAddWord(word, contextSentence(blocks[frag.block].text, frag.start + sel!!.start))
                        onSelect(null)
                    }
                },
            )
            if (bottom > 0) Spacer(Modifier.height(fontDp * bottom))
        }
    }
}

@Composable
private fun FragText(
    frag: Frag,
    settings: ReaderSettings,
    marks: List<Pair<String, Color>>,
    selection: WordSelection?,
    gate: PressGate,
    onSelect: (TextRange?, done: Boolean) -> Unit,
    onHighlight: (Color) -> Unit,
    onAddWord: (() -> Unit)?,
) {
    val haptics = LocalHapticFeedback.current
    val select by rememberUpdatedState(onSelect)
    var layout by remember { mutableStateOf<TextLayoutResult?>(null) }
    val text = remember(frag.text, marks) {
        buildAnnotatedString {
            append(frag.text)
            for ((s, e, color) in markRanges(frag.text, marks)) addStyle(SpanStyle(background = color), s, e)
        }
    }
    val selColor = AppColors.ember.copy(alpha = 0.3f)
    Box {
        BasicText(
            text = text,
            style = settings.blockStyle(frag.kind),
            onTextLayout = { layout = it },
            modifier = Modifier
                .fillMaxWidth()
                .drawBehind {
                    val l = layout
                    if (selection != null && l != null) drawPath(l.getPathForRange(selection.start, selection.end), selColor)
                }
                .pointerInput(frag) {
                    var anchor = TextRange.Zero
                    var range: TextRange? = null
                    fun wordAt(pos: Offset) = layout?.let { it.getWordBoundary(it.getOffsetForPosition(pos)) }
                    detectDragGesturesAfterLongPress(
                        onDragStart = { pos ->
                            anchor = wordAt(pos)?.takeIf { !it.collapsed } ?: return@detectDragGesturesAfterLongPress
                            range = anchor
                            gate.active = true
                            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                            select(anchor, false)
                        },
                        onDrag = { change, _ ->
                            val w = wordAt(change.position)
                            if (range != null && w != null && !w.collapsed) {
                                range = TextRange(min(anchor.start, w.start), max(anchor.end, w.end))
                                select(range, false)
                            }
                        },
                        onDragEnd = {
                            range?.let { select(it, true) }
                            range = null
                            gate.end()
                        },
                        onDragCancel = {
                            if (range != null) select(null, false)
                            range = null
                            gate.end()
                        },
                    )
                },
        )
        val l = layout
        if (selection != null && selection.done && l != null) {
            val gap = with(LocalDensity.current) { 8.dp.roundToPx() }
            val minTop = with(LocalDensity.current) { 56.dp.roundToPx() }
            val provider = remember(selection, l) {
                val first = l.getBoundingBox(selection.start)
                val last = l.getBoundingBox(selection.end - 1)
                val centerX = if (first.top == last.top) (first.left + last.right) / 2 else first.left
                AboveSelection(centerX, first.top, last.bottom, gap, minTop)
            }
            Popup(popupPositionProvider = provider, properties = PopupProperties(focusable = false, dismissOnClickOutside = false)) {
                SelectionTooltip(onHighlight, onAddWord)
            }
        }
    }
}

/** Centers the popup over the selection, just above it, or just below when that would hit the top bar. */
private class AboveSelection(
    val centerX: Float,
    val top: Float,
    val bottom: Float,
    val gap: Int,
    val minTop: Int,
) : PopupPositionProvider {
    override fun calculatePosition(
        anchorBounds: IntRect,
        windowSize: IntSize,
        layoutDirection: LayoutDirection,
        popupContentSize: IntSize,
    ): IntOffset {
        val x = (anchorBounds.left + centerX.roundToInt() - popupContentSize.width / 2)
            .coerceIn(gap, max(gap, windowSize.width - popupContentSize.width - gap))
        val above = anchorBounds.top + top.roundToInt() - popupContentSize.height - gap
        val y = if (above >= minTop) above else anchorBounds.top + bottom.roundToInt() + gap
        return IntOffset(x, y)
    }
}

@Composable
private fun SelectionTooltip(onHighlight: (Color) -> Unit, onAddWord: (() -> Unit)?) {
    Surface(shape = RoundedCornerShape(14.dp), color = AppColors.ink, shadowElevation = 8.dp) {
        Row(Modifier.padding(start = 10.dp, end = 4.dp, top = 6.dp, bottom = 6.dp), verticalAlignment = Alignment.CenterVertically) {
            for (color in Swatches) {
                Box(
                    Modifier
                        .padding(end = 8.dp)
                        .size(26.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(color)
                        .border(2.dp, AppColors.card.copy(alpha = 0.25f), RoundedCornerShape(8.dp))
                        .clickable { onHighlight(color) },
                )
            }
            Box(Modifier.width(1.dp).height(22.dp).background(AppColors.card.copy(alpha = 0.2f)))
            TextButton(onClick = { onAddWord?.invoke() }, enabled = onAddWord != null) {
                Text(
                    "Add to words",
                    fontFamily = Inter,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 13.sp,
                    color = AppColors.card.copy(alpha = if (onAddWord != null) 1f else 0.4f),
                )
            }
        }
    }
}
