package com.sarvarbek.ember.data

import com.sarvarbek.ember.data.db.EmberDatabase

/** Adds Words into 20-word Collections. */
class WordRepository(private val db: EmberDatabase) {
    /** Adds [text] to the latest Collection, opening "Collection N+1" when it is full. */
    suspend fun add(text: String, context: String, bookId: String): Unit = TODO("feat/words-notes")
}
