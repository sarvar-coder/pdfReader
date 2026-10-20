package com.sarvarbek.ember.data

import androidx.room.withTransaction
import com.sarvarbek.ember.data.db.EmberDatabase
import com.sarvarbek.ember.data.db.Word
import com.sarvarbek.ember.data.db.WordCollection

/** How many Words one Collection holds before the next one opens. */
const val COLLECTION_LIMIT = 20

/** What [WordRepository.add] did, and in which Collection. */
sealed interface AddResult {
    val collection: String

    data class Added(override val collection: String) : AddResult
    data class Duplicate(override val collection: String) : AddResult
}

/** Where the next Word goes. */
sealed interface AddPlan {
    data class Into(val collection: WordCollection) : AddPlan
    data class Open(val name: String) : AddPlan
    data class Skip(val collection: WordCollection) : AddPlan
}

/**
 * The add rule, free of the database: a missing or full latest Collection opens "Collection N+1";
 * otherwise the Word joins the latest one, unless it is already there ([inLatest]).
 * Collections are never deleted, so the latest's number is also how many exist.
 */
fun planAdd(latest: WordCollection?, latestCount: Int, inLatest: Boolean): AddPlan = when {
    latest == null -> AddPlan.Open("Collection 1")
    latestCount >= COLLECTION_LIMIT -> {
        val n = latest.name.substringAfterLast(' ').toIntOrNull() ?: latest.id.toInt()
        AddPlan.Open("Collection ${n + 1}")
    }
    inLatest -> AddPlan.Skip(latest)
    else -> AddPlan.Into(latest)
}

/** Adds Words into 20-word Collections. */
class WordRepository(private val db: EmberDatabase) {
    /**
     * Adds [text] to the latest Collection, opening "Collection N+1" when it is full. Words are stored
     * trimmed and lower-cased, so "The" and "the" are one Word; a Word already in the target Collection
     * is skipped. One transaction, so two quick adds can't overfill a Collection.
     */
    suspend fun add(text: String, context: String, bookId: String): AddResult = db.withTransaction {
        val dao = db.words()
        val word = text.trim().lowercase()
        val latest = dao.latestCollection()
        val count = latest?.let { dao.countIn(it.id) } ?: 0
        val inLatest = latest != null && dao.existsIn(latest.id, word)
        val target = when (val plan = planAdd(latest, count, inLatest)) {
            is AddPlan.Skip -> return@withTransaction AddResult.Duplicate(plan.collection.name)
            is AddPlan.Into -> plan.collection
            is AddPlan.Open -> WordCollection(name = plan.name).let { it.copy(id = dao.insertCollection(it)) }
        }
        dao.insertWord(Word(collectionId = target.id, text = word, context = context.trim(), bookId = bookId))
        AddResult.Added(target.name)
    }
}
