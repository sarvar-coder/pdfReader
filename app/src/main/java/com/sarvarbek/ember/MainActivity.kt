package com.sarvarbek.ember

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.core.content.IntentCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.lifecycle.lifecycleScope
import com.sarvarbek.ember.navigation.EmberNavHost
import com.sarvarbek.ember.ui.theme.EmberTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

class MainActivity : ComponentActivity() {
    private val container get() = (application as App).container

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        if (savedInstanceState == null) receive(intent)
        setContent { EmberTheme { EmberNavHost(container) } }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        receive(intent)
    }

    /**
     * VIEW ("Open with") and SEND ("Share") of a PDF land here. The read grant on the Uri dies with this
     * intent, so the bytes are copied now into a fresh cache dir, keeping the original file name as the title
     * source. A fresh path per share also keeps the StateFlow from dropping a repeat of the same file.
     */
    private fun receive(intent: Intent) {
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> IntentCompat.getParcelableExtra(intent, Intent.EXTRA_STREAM, Uri::class.java)
            else -> null
        }
        if (uri == null) return
        lifecycleScope.launch {
            val copy = withContext(Dispatchers.IO) {
                runCatching {
                    val dir = File(cacheDir, "incoming/${System.nanoTime()}").apply { mkdirs() }
                    val out = File(dir, displayName(uri) ?: "Untitled.pdf")
                    contentResolver.openInputStream(uri)!!.use { input -> out.outputStream().use { input.copyTo(it) } }
                    out
                }.getOrNull()
            }
            if (copy != null) container.incomingPdf.value = copy
        }
    }

    private fun displayName(uri: Uri): String? =
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) it.getString(0)?.substringAfterLast('/') else null
        } ?: uri.lastPathSegment?.substringAfterLast('/')
}
