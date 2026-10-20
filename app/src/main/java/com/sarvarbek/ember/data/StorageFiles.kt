package com.sarvarbek.ember.data

import java.io.File

/**
 * Where a Book's files live: `filesDir/books/<id>.*`. The version tags in the cache names are bumped
 * whenever the format of what they hold changes, so stale caches are simply never read again.
 */
class StorageFiles(filesDir: File) {
    val dir: File = File(filesDir, "books").apply { mkdirs() }

    fun pdf(id: String) = File(dir, "$id.pdf")
    fun cover(id: String) = File(dir, "$id.v2.png")
    fun pages(id: String) = File(dir, "$id.v4.pages.json")
    fun toc(id: String) = File(dir, "$id.v4.toc.json")
    fun note(id: String) = File(dir, "$id.note.txt")

    /** Deletes every file belonging to [id], including stale cache versions. */
    fun deleteAll(id: String) {
        dir.listFiles { f -> f.name.startsWith("$id.") }?.forEach { it.delete() }
    }
}
