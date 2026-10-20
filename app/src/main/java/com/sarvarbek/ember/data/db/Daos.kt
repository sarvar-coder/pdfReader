package com.sarvarbek.ember.data.db

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Update
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

@Dao
interface BookDao {
    @Query("SELECT * FROM books ORDER BY addedAt DESC")
    fun all(): Flow<List<Book>>

    @Query("SELECT * FROM books WHERE id = :id")
    fun observe(id: String): Flow<Book?>

    @Query("SELECT * FROM books WHERE id = :id")
    suspend fun get(id: String): Book?

    @Upsert
    suspend fun upsert(book: Book)

    @Update
    suspend fun update(book: Book)

    @Query("DELETE FROM books WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("DELETE FROM highlights WHERE bookId = :bookId")
    suspend fun deleteHighlights(bookId: String)

    @Query("DELETE FROM bookmarks WHERE bookId = :bookId")
    suspend fun deleteBookmarks(bookId: String)

    @Query("DELETE FROM sessions WHERE bookId = :bookId")
    suspend fun deleteSessions(bookId: String)

    /** Removes the Book row and everything hanging off it. Files are StorageFiles.deleteAll. */
    @Transaction
    suspend fun deleteBook(id: String) {
        deleteHighlights(id)
        deleteBookmarks(id)
        deleteSessions(id)
        deleteById(id)
    }
}

@Dao
interface HighlightDao {
    @Query("SELECT * FROM highlights WHERE bookId = :bookId ORDER BY createdAt DESC")
    fun forBook(bookId: String): Flow<List<Highlight>>

    @Query("SELECT * FROM highlights ORDER BY createdAt DESC")
    fun all(): Flow<List<Highlight>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(highlight: Highlight)

    @Delete
    suspend fun delete(highlight: Highlight)
}

@Dao
interface BookmarkDao {
    @Query("SELECT * FROM bookmarks WHERE bookId = :bookId ORDER BY page")
    fun forBook(bookId: String): Flow<List<Bookmark>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(bookmark: Bookmark)

    @Delete
    suspend fun delete(bookmark: Bookmark)
}

@Dao
interface SessionDao {
    @Query("SELECT * FROM sessions ORDER BY startedAt DESC")
    fun all(): Flow<List<ReadingSession>>

    @Upsert
    suspend fun upsert(session: ReadingSession)

    @Delete
    suspend fun delete(session: ReadingSession)
}

@Dao
interface WordDao {
    @Query("SELECT * FROM word_collections ORDER BY id DESC LIMIT 1")
    suspend fun latestCollection(): WordCollection?

    @Query("SELECT COUNT(*) FROM words WHERE collectionId = :collectionId")
    suspend fun countIn(collectionId: Long): Int

    @Query("SELECT EXISTS(SELECT 1 FROM words WHERE collectionId = :collectionId AND text = :text)")
    suspend fun existsIn(collectionId: Long, text: String): Boolean

    @Insert
    suspend fun insertCollection(collection: WordCollection): Long

    @Insert
    suspend fun insertWord(word: Word): Long

    @Query(
        """SELECT c.id, c.name, c.createdAt, COUNT(w.id) AS count
           FROM word_collections c LEFT JOIN words w ON w.collectionId = c.id
           GROUP BY c.id ORDER BY c.id DESC""",
    )
    fun collectionsWithCounts(): Flow<List<CollectionWithCount>>

    @Query("SELECT * FROM words WHERE collectionId = :collectionId ORDER BY addedAt")
    fun wordsIn(collectionId: Long): Flow<List<Word>>

    @Delete
    suspend fun deleteWord(word: Word)
}
