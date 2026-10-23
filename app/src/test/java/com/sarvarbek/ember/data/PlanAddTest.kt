package com.sarvarbek.ember.data

import com.sarvarbek.ember.data.db.WordCollection
import org.junit.Assert.assertEquals
import org.junit.Test

class PlanAddTest {
    /** Runs [words] through [planAdd] the way WordRepository.add does; returns each Collection's words. */
    private fun fill(words: List<String>): Map<String, List<String>> {
        val collections = linkedMapOf<WordCollection, MutableList<String>>()
        for (w in words) {
            val latest = collections.keys.lastOrNull()
            val savedIn = collections.entries.find { w in it.value }?.key?.name
            when (val plan = planAdd(latest, latest?.let { collections.getValue(it).size } ?: 0, savedIn)) {
                is AddPlan.Skip -> Unit
                is AddPlan.Into -> collections.getValue(plan.collection) += w
                is AddPlan.Open ->
                    collections[WordCollection(id = collections.size + 1L, name = plan.name)] = mutableListOf(w)
            }
        }
        return collections.mapKeys { it.key.name }
    }

    private fun sizes(n: Int) = fill((1..n).map { "w$it" }).mapValues { it.value.size }

    @Test fun firstWordOpensCollection1() = assertEquals(mapOf("Collection 1" to 1), sizes(1))

    @Test fun nineteenAndTwentyFitInOne() {
        assertEquals(mapOf("Collection 1" to 19), sizes(19))
        assertEquals(mapOf("Collection 1" to 20), sizes(20))
    }

    @Test fun twentyFirstOpensCollection2() =
        assertEquals(mapOf("Collection 1" to 20, "Collection 2" to 1), sizes(21))

    @Test fun fortyFillTwo() = assertEquals(mapOf("Collection 1" to 20, "Collection 2" to 20), sizes(40))

    @Test fun fortyFirstOpensCollection3() =
        assertEquals(mapOf("Collection 1" to 20, "Collection 2" to 20, "Collection 3" to 1), sizes(41))

    @Test fun duplicateInSameCollectionIsSkipped() =
        assertEquals(mapOf("Collection 1" to listOf("a", "b")), fill(listOf("a", "b", "a")))

    @Test fun repeatOfAFullCollectionsWordIsSkipped() =
        assertEquals(mapOf("Collection 1" to 20), fill((1..20).map { "w$it" } + "w1").mapValues { it.value.size })

    @Test fun duplicateNamesTheCollectionHoldingIt() =
        assertEquals(AddPlan.Skip("Collection 1"), planAdd(WordCollection(2, "Collection 2"), 3, "Collection 1"))
}
