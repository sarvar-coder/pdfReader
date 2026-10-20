package com.sarvarbek.ember.ui.widgets

import android.graphics.BitmapFactory
import android.util.LruCache
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import com.sarvarbek.ember.ui.theme.Fraunces
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

private val shape = RoundedCornerShape(10.dp)

/** Decoded covers by "path@stamp", so scrolling the shelf back neither re-decodes nor flashes the gradient. */
// ponytail: 32 entries (~300x450 ARGB at 2:3, ~17 MB; tall pages cost more); size by bytes if shelves grow far past that.
private val covers = LruCache<String, ImageBitmap>(32)

/** Covers are drawn about a third of the screen wide; decode no wider than ~this many pixels. */
private const val TARGET_WIDTH = 300

private fun decode(path: String): ImageBitmap? {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(path, bounds)
    var sample = 1
    while (bounds.outWidth / (sample * 2) >= TARGET_WIDTH) sample *= 2
    return BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })?.asImageBitmap()
}

/**
 * A Book's cover: the rendered first page from [coverFile] when it exists and decodes, otherwise
 * a two-color gradient with the centered title. The caller sizes it (e.g. aspectRatio(2f / 3f)).
 * [coverStamp] is the file's lastModified, so a re-rendered cover is decoded afresh.
 * In lazy lists, key items by book: a reused slot shows its previous cover until the new one decodes.
 */
@Composable
fun BookCover(
    title: String,
    gradient: List<Color>,
    modifier: Modifier = Modifier,
    coverFile: File? = null,
    coverStamp: Long = 0L,
    titleSize: TextUnit = 12.sp,
) {
    val cacheKey = coverFile?.let { "${it.path}@$coverStamp" }
    val bitmap by produceState(cacheKey?.let { covers.get(it) }, cacheKey) {
        // produceState keeps its value across keys: an old cover stays up until the new one decodes.
        val cached = cacheKey?.let { covers.get(it) }
        if (coverFile == null || cached != null) {
            value = cached
            return@produceState
        }
        value = withContext(Dispatchers.IO) { decode(coverFile.path)?.also { covers.put(cacheKey, it) } }
    }
    val image = bitmap
    if (image != null) {
        // White ground so a non-2:3 page letterboxes as clean page margin; Fit shows the whole cover.
        Image(
            image,
            contentDescription = title,
            modifier = modifier.clip(shape).background(Color.White).fillMaxSize(),
            contentScale = ContentScale.Fit,
        )
        return
    }
    Box(
        modifier
            .clip(shape)
            .background(Brush.linearGradient(gradient, start = Offset.Zero, end = Offset.Infinite))
            .fillMaxSize(),
    ) {
        // Spine line down the left edge.
        Box(Modifier.width(6.dp).fillMaxHeight().background(Color(0x2E000000)))
        Text(
            title,
            modifier = Modifier.align(Alignment.Center).padding(8.dp),
            textAlign = TextAlign.Center,
            maxLines = 4,
            overflow = TextOverflow.Ellipsis,
            style = TextStyle(
                fontFamily = Fraunces,
                fontSize = titleSize,
                lineHeight = 1.15.em,
                fontWeight = FontWeight.SemiBold,
                color = Color.White,
                shadow = Shadow(Color(0x66000000), Offset(0f, 1f), 4f),
            ),
        )
    }
}
