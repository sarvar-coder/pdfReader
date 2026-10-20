package com.sarvarbek.ember.features.notes

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.sarvarbek.ember.AppContainer

// Stub: filled in by feat/words-notes.
@Composable
fun NoteScreen(container: AppContainer, bookId: String, title: String, onBack: () -> Unit) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Text(title) }
}
