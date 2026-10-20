package com.sarvarbek.ember.data.db

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(
    entities = [Book::class, Highlight::class, Bookmark::class, ReadingSession::class, WordCollection::class, Word::class],
    version = 1,
    exportSchema = false,
)
abstract class EmberDatabase : RoomDatabase() {
    abstract fun books(): BookDao
    abstract fun highlights(): HighlightDao
    abstract fun bookmarks(): BookmarkDao
    abstract fun sessions(): SessionDao
    abstract fun words(): WordDao

    companion object {
        fun build(context: Context): EmberDatabase =
            Room.databaseBuilder(context, EmberDatabase::class.java, "ember.db").build()
    }
}
