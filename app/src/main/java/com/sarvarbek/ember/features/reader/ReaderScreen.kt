package com.sarvarbek.ember.features.reader

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.sarvarbek.ember.AppContainer

// Stub: filled in by feat/reader.
@Composable
fun ReaderScreen(container: AppContainer, bookId: String, onBack: () -> Unit, onOpenNotes: (String, String) -> Unit) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Text("Reader") }
}
