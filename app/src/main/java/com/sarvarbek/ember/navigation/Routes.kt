package com.sarvarbek.ember.navigation

import androidx.navigation3.runtime.NavKey
import kotlinx.serialization.Serializable

/** Every destination on the back stack. Serializable so the stack survives process death. */
@Serializable
sealed interface Route : NavKey {
    /** The 3-tab home: Library, Words, Stats. Always at the bottom of the stack. */
    @Serializable data object Shell : Route

    @Serializable data class Reader(val bookId: String) : Route

    @Serializable data class Notes(val bookId: String, val title: String) : Route

    @Serializable data class WordCollection(val collectionId: Long, val name: String) : Route
}
