package com.sarvarbek.ember.features.reader

import androidx.activity.compose.BackHandler
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PagerState
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.materialIcon
import androidx.compose.material.icons.materialPath
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFontFamilyResolver
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.sarvarbek.ember.AppContainer
import com.sarvarbek.ember.ui.theme.AppColors
import com.sarvarbek.ember.ui.theme.Inter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.math.max
import kotlin.math.roundToInt

private enum class Sheet { Settings, Contents }

/**
 * The Reader: the Book's extracted text reflowed into swipeable, screen-sized pages, with top/bottom chrome
 * that a page tap hides, an "Aa" settings sheet, a contents sheet, and a long-press word tooltip.
 */
@Composable
fun ReaderScreen(container: AppContainer, bookId: String, onBack: () -> Unit, onOpenNotes: (String, String) -> Unit) {
    val vm: ReaderViewModel = viewModel { ReaderViewModel(container, bookId) }
    val content by vm.content.collectAsStateWithLifecycle()
    val settings by vm.settings.collectAsStateWithLifecycle()
    val title by vm.title.collectAsStateWithLifecycle()
    val highlights by vm.highlights.collectAsStateWithLifecycle()
    val bookmarks by vm.bookmarks.collectAsStateWithLifecycle()

    val snackbar = remember { SnackbarHostState() }
    LaunchedEffect(vm) { vm.messages.collect { snackbar.showSnackbar(it) } }

    // Session + position bookkeeping: start when visible, end when stopped or when the screen leaves.
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    DisposableEffect(lifecycle, vm) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_START) vm.onStart()
            if (event == Lifecycle.Event.ON_STOP) vm.onStop()
        }
        lifecycle.addObserver(observer)
        onDispose {
            lifecycle.removeObserver(observer)
            vm.onStop()
        }
    }

    var chrome by rememberSaveable { mutableStateOf(true) }
    var sheet by rememberSaveable { mutableStateOf<Sheet?>(null) }
    var selection by remember { mutableStateOf<WordSelection?>(null) }
    BackHandler(selection != null) { selection = null }

    val ready = content as? ReaderContent.Ready
    var box by remember { mutableStateOf(IntSize.Zero) }
    val pages by rememberPages(ready?.blocks, box, settings)
    val pagerState = rememberPagerState { pages?.size ?: 0 }
    val scope = rememberCoroutineScope()

    // (Re)pagination keeps the reading fraction; then every settled page is reported as the position.
    LaunchedEffect(pages) {
        val p = pages ?: return@LaunchedEffect
        pagerState.scrollToPage(pageForFraction(vm.fraction, p.size))
        snapshotFlow { pagerState.settledPage }.collect { i ->
            p.getOrNull(i)?.let { vm.onPosition(i, p.size, it.pdfPage) }
        }
    }
    LaunchedEffect(pagerState) { snapshotFlow { pagerState.currentPage }.collect { selection = null } }

    fun jumpToPdfPage(pdfPage: Int) {
        val p = pages ?: return
        val blocks = ready?.blocks ?: return
        val i = p.indexOfFirst { pg -> pg.frags.any { blocks[it.block].page >= pdfPage } }
        scope.launch { pagerState.scrollToPage(if (i < 0) p.lastIndex else i) }
        sheet = null
    }

    val theme = settings.theme
    val bg by animateColorAsState(theme.bg, tween(350), label = "readerBg")
    val marks = remember(highlights) { highlights.map { it.quote to Color(it.colorValue).copy(alpha = 0.4f) } }

    Scaffold(containerColor = bg, snackbarHost = { SnackbarHost(snackbar) }) { insets ->
        Column(Modifier.fillMaxSize().padding(insets)) {
            Chrome(visible = chrome, up = true) {
                Row(Modifier.padding(start = 10.dp, end = 10.dp, top = 8.dp, bottom = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                    IconBtn(chrome, onBack) { Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, "Back", tint = theme.ink) }
                    Text(
                        title,
                        Modifier.weight(1f),
                        color = theme.ink.copy(alpha = 0.7f),
                        fontFamily = Inter,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        textAlign = TextAlign.Center,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    IconBtn(chrome, { onOpenNotes(bookId, title) }) { Icon(Icons.Filled.Edit, "Notes", Modifier.size(20.dp), tint = theme.ink) }
                    IconBtn(chrome && ready != null, vm::addBookmark) { Icon(BookmarkIcon, "Bookmark", Modifier.size(20.dp), tint = theme.ink) }
                    IconBtn(chrome, { sheet = Sheet.Settings }) {
                        Text("Aa", color = theme.ink, fontFamily = Inter, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                    }
                }
            }

            Box(Modifier.weight(1f).fillMaxWidth().onSizeChanged { box = it }, contentAlignment = Alignment.Center) {
                val p = pages
                when {
                    content is ReaderContent.Missing -> Notice("This book’s PDF is missing. Re-import it from your shelf.", settings)
                    content is ReaderContent.Empty ->
                        Notice("No selectable text found in this PDF. It may be made of scanned images.", settings)
                    content is ReaderContent.Failed ->
                        Notice("Couldn’t read this PDF.\n\n${(content as ReaderContent.Failed).message}", settings)
                    ready == null || p == null -> CircularProgressIndicator(color = theme.ink.copy(alpha = 0.5f))
                    else -> HorizontalPager(
                        state = pagerState,
                        key = { it },
                        beyondViewportPageCount = 1,
                        modifier = Modifier.fillMaxSize(),
                    ) { i ->
                        ReaderPage(
                            page = p[i],
                            index = i,
                            blocks = ready.blocks,
                            settings = settings,
                            marks = marks,
                            selection = selection,
                            onSelect = { selection = it },
                            onTap = { if (selection != null) selection = null else chrome = !chrome },
                            onHighlight = vm::addHighlight,
                            onAddWord = vm::addWord,
                        )
                    }
                }
            }

            Chrome(visible = chrome, up = false) {
                BottomBar(chrome, pagerState, pages, ready?.pdfPages ?: 0, theme.ink, onSeek = { scope.launch { pagerState.scrollToPage(it) } }) {
                    sheet = Sheet.Contents
                }
            }
        }
    }

    when (sheet) {
        Sheet.Settings -> SettingsSheet(settings, vm::updateSettings) { sheet = null }
        Sheet.Contents -> ContentsSheet(ready?.chapters.orEmpty(), highlights, bookmarks, ::jumpToPdfPage) { sheet = null }
        null -> Unit
    }
}

/**
 * Pages for [blocks] measured against the page [box], off the main thread. Re-measured only when the box,
 * the text or a layout-affecting setting changes (theme color doesn't). Keeps showing the old pages meanwhile.
 */
@Composable
private fun rememberPages(blocks: List<Block>?, box: IntSize, settings: ReaderSettings): State<List<Page>?> {
    val density = LocalDensity.current
    val resolver = LocalFontFamilyResolver.current
    val direction = LocalLayoutDirection.current
    return produceState<List<Page>?>(null, blocks, box, settings.fontSize, settings.lineSpacing, settings.typeface, density) {
        if (blocks == null || box.width == 0 || box.height == 0) return@produceState
        if (value != null) delay(150) // let a dragged slider settle before re-measuring a whole book
        // Google Fonts load async; measuring before they land would paginate against the fallback face.
        withTimeoutOrNull(3_000) { runCatching { resolver.preload(settings.typeface.family) } }
        value = withContext(Dispatchers.Default) {
            val job = coroutineContext.job
            val measurer = TextMeasurer(resolver, density, direction, cacheSize = 0)
            val styles = BlockKind.entries.associateWith { settings.blockStyle(it) }
            with(density) {
                val width = max(1, box.width - PAD_H_DP.dp.roundToPx())
                // Half a line of slack: a continuation slice can re-wrap to one extra line vs what was measured.
                val slack = settings.lineHeight.sp.toPx() * 0.5f
                val height = max(1f, box.height - PAD_V_DP.dp.toPx() - slack)
                paginate(blocks, height, settings.fontSize.sp.toPx()) { b ->
                    job.ensureActive()
                    val r = measurer.measure(b.text, styles.getValue(b.kind), constraints = Constraints(maxWidth = width))
                    Measured(
                        IntArray(r.lineCount) { r.getLineEnd(it) },
                        FloatArray(r.lineCount) { r.getLineBottom(it) - r.getLineTop(it) },
                    )
                }
            }
        }
    }
}

/** Fades and slides chrome 8 dp out of the way; it keeps its space so pages never re-measure. */
@Composable
private fun Chrome(visible: Boolean, up: Boolean, content: @Composable () -> Unit) {
    val t by animateFloatAsState(if (visible) 1f else 0f, tween(300), label = "chrome")
    Box(
        Modifier.graphicsLayer {
            alpha = t
            translationY = (1 - t) * 8.dp.toPx() * (if (up) -1 else 1)
        },
    ) { content() }
}

@Composable
private fun BottomBar(
    enabled: Boolean,
    pagerState: PagerState,
    pages: List<Page>?,
    pdfPages: Int,
    ink: Color,
    onSeek: (Int) -> Unit,
    onContents: () -> Unit,
) {
    val count = pages?.size ?: 0
    val current = pagerState.currentPage.coerceIn(0, max(0, count - 1))
    Column(Modifier.padding(start = 18.dp, end = 8.dp, top = 4.dp, bottom = 10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        val pdfPage = pages?.getOrNull(current)?.pdfPage
        Text(
            if (pdfPage != null && pdfPages > 0) "${pdfPage + 1} / $pdfPages" else "",
            color = ink.copy(alpha = 0.75f),
            fontFamily = Inter,
            fontSize = 12.5.sp,
            fontWeight = FontWeight.SemiBold,
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            Slider(
                value = current.toFloat(),
                onValueChange = { onSeek(it.roundToInt()) },
                valueRange = 0f..max(1, count - 1).toFloat(),
                enabled = enabled && count > 1,
                colors = SliderDefaults.colors(
                    thumbColor = AppColors.ember,
                    activeTrackColor = AppColors.ember,
                    inactiveTrackColor = ink.copy(alpha = 0.15f),
                ),
                modifier = Modifier.weight(1f),
            )
            IconBtn(enabled, onContents) { Icon(Icons.AutoMirrored.Filled.List, "Contents", Modifier.size(20.dp), tint = ink) }
        }
    }
}

/** A 38×38 tappable square used across the reader chrome. */
@Composable
private fun IconBtn(enabled: Boolean, onClick: () -> Unit, content: @Composable () -> Unit) {
    Box(
        Modifier.size(38.dp).clip(RoundedCornerShape(12.dp)).clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { content() }
}

/** A short message in the reading face, for the non-paged states. */
@Composable
private fun Notice(text: String, settings: ReaderSettings) {
    Text(
        text,
        Modifier.fillMaxSize().padding(PagePadding),
        style = settings.bodyStyle(),
    )
}

/** Material's "bookmark" glyph; only the core icon set is a dependency. */
internal val BookmarkIcon: ImageVector = materialIcon("Ember.Bookmark") {
    materialPath {
        moveTo(17f, 3f)
        horizontalLineTo(7f)
        curveTo(5.9f, 3f, 5.01f, 3.9f, 5.01f, 5f)
        lineTo(5f, 21f)
        lineToRelative(7f, -3f)
        lineToRelative(7f, 3f)
        verticalLineTo(5f)
        curveTo(19f, 3.9f, 18.1f, 3f, 17f, 3f)
        close()
    }
}
