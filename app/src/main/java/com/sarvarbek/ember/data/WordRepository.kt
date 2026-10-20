package com.sarvarbek.ember.data

import androidx.room.withTransaction
import com.sarvarbek.ember.data.db.EmberDatabase
import com.sarvarbek.ember.data.db.Word
import com.sarvarbek.ember.data.db.WordCollection

/** How many Words one Collection holds before the next one opens. */
const val COLLECTION_LIMIT = 20

/** What [WordRepository.add] did. */
sealed interface AddResult {
    data class Added(val collection: String) : AddResult

    /** Already saved, in [collection]. */
    data class Duplicate(val collection: String) : AddResult

    /** Nothing word-like was left after trimming. */
    data object Empty : AddResult
}

/** Where the next Word goes. */
sealed interface AddPlan {
    data class Into(val collection: WordCollection) : AddPlan
    data class Open(val name: String) : AddPlan
    data class Skip(val collection: String) : AddPlan
}

/** Edge punctuation stripped from a picked word; inner characters (c++, don't) are kept. */
private const val EDGE_PUNCTUATION = ".,;:!?\"'()[]{}<>“”‘’«»—–…"

/** [text] as stored: trimmed of whitespace and edge punctuation, lower-cased. Empty if nothing is left. */
fun normalizeWord(text: String): String =
    text.trim { it.isWhitespace() || it in EDGE_PUNCTUATION }.lowercase()

/**
 * The add rule, free of the database: a Word already saved anywhere ([savedIn]) is skipped; a missing
 * or full latest Collection opens "Collection N+1"; otherwise the Word joins the latest one.
 * Collections are never deleted, so the latest's number is also how many exist.
 */
fun planAdd(latest: WordCollection?, latestCount: Int, savedIn: String?): AddPlan = when {
    savedIn != null -> AddPlan.Skip(savedIn)
    latest == null -> AddPlan.Open("Collection 1")
    latestCount >= COLLECTION_LIMIT -> {
        val n = latest.name.substringAfterLast(' ').toIntOrNull() ?: latest.id.toInt()
        AddPlan.Open("Collection ${n + 1}")
    }
    else -> AddPlan.Into(latest)
}

/** Adds Words into 20-word Collections. */
class WordRepository(private val db: EmberDatabase) {
    /**
     * Adds [text] to the latest Collection, opening "Collection N+1" when it is full. Words are stored
     * via [normalizeWord], so "The," and "the" are one Word, and a Word is saved only once across all
     * Collections. One transaction, so two quick adds can't overfill a Collection.
     */
    suspend fun add(text: String, context: String, bookId: String): AddResult {
        val word = normalizeWord(text)
        if (word.isEmpty()) return AddResult.Empty
        return db.withTransaction {
            val dao = db.words()
            val latest = dao.latestCollection()
            val count = latest?.let { dao.countIn(it.id) } ?: 0
            val target = when (val plan = planAdd(latest, count, dao.collectionOf(word))) {
                is AddPlan.Skip -> return@withTransaction AddResult.Duplicate(plan.collection)
                is AddPlan.Into -> plan.collection
                is AddPlan.Open -> WordCollection(name = plan.name).let { it.copy(id = dao.insertCollection(it)) }
            }
            dao.insertWord(Word(collectionId = target.id, text = word, context = context.trim(), bookId = bookId))
            AddResult.Added(target.name)
        }
    }
}
