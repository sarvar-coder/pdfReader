package com.sarvarbek.ember

import com.sarvarbek.ember.data.StorageFiles
import org.junit.Assert.assertEquals
import org.junit.Test
import java.nio.file.Files

class StorageFilesTest {
    @Test
    fun deleteAllRemovesOnlyThatBooksFiles() {
        val files = StorageFiles(Files.createTempDirectory("ember").toFile())
        listOf(files.pdf("a"), files.cover("a"), files.pages("a"), files.note("a"), files.pdf("ab"))
            .forEach { it.writeText("x") }
        files.deleteAll("a")
        assertEquals(listOf("ab.pdf"), files.dir.list()!!.toList())
    }
}
