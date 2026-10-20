package com.sarvarbek.ember.data.db

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

// All timestamps are epoch millis.

/** One imported PDF. The PDF itself lives at StorageFiles.pdf(id). */
@Entity(tableName = "books")
data class Book(
    @PrimaryKey val id: String,
    val title: String,
    val author: String,
    val currentPage: Int,
    val totalPages: Int,
    /** Cover fallback gradient, ARGB, painted top-left to bottom-right. */
    val gradientStart: Long,
    val gradientEnd: Long,
    val chapter: String? = null,
    val addedAt: Long = System.currentTimeMillis(),
    /** Canonical reading position: 0..1 of the Book's text. Survives style changes. */
    val readingFraction: Double = 0.0,
)

@Entity(tableName = "highlights", indices = [Index("bookId")])
data class Highlight(
    @PrimaryKey val id: String,
    val bookId: String,
    val quote: String,
    val colorValue: Long,
    val page: Int,
    val chapter: String,
    val createdAt: Long = System.currentTimeMillis(),
)

@Entity(tableName = "bookmarks", indices = [Index("bookId")])
data class Bookmark(
    @PrimaryKey val id: String,
    val bookId: String,
    val page: Int,
    val chapter: String,
    val note: String,
    val createdAt: Long = System.currentTimeMillis(),
)

@Entity(tableName = "sessions", indices = [Index("bookId")])
data class ReadingSession(
    @PrimaryKey val id: String,
    val bookId: String,
    val startedAt: Long,
    val endedAt: Long? = null,
    val pagesRead: Int = 0,
    val minutes: Int = 0,
)

/** A bucket of at most 20 Words, named "Collection N". */
@Entity(tableName = "word_collections")
data class WordCollection(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val createdAt: Long = System.currentTimeMillis(),
)

@Entity(
    tableName = "words",
    foreignKeys = [
        ForeignKey(
            entity = WordCollection::class,
            parentColumns = ["id"],
            childColumns = ["collectionId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [Index("collectionId")],
)
data class Word(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val collectionId: Long,
    val text: String,
    /** The sentence the word was picked from. */
    val context: String,
    val bookId: String,
    val addedAt: Long = System.currentTimeMillis(),
)

data class CollectionWithCount(
    val id: Long,
    val name: String,
    val createdAt: Long,
    val count: Int,
)
