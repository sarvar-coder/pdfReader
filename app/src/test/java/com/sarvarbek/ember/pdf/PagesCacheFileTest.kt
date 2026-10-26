package com.sarvarbek.ember.pdf

import com.sarvarbek.ember.data.StorageFiles
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class PagesCacheFileTest {
    @get:Rule val tmp = TemporaryFolder()

    @Test fun matchesStorageFilesPagesPath() {
        val storage = StorageFiles(tmp.root)
        val id = "3f2a-book"
        assertEquals(storage.pages(id), pagesCacheFile(storage.pdf(id)))
    }

    @Test fun sitsBesideThePdfWithOnlyTheLastExtensionReplaced() {
        val pdf = File(tmp.root, "my.great.book.pdf")
        assertEquals(File(tmp.root, "my.great.book.v4.pages.json"), pagesCacheFile(pdf))
    }

    /** A bare file name has no parent; the cache still resolves to a real directory. */
    @Test fun relativePdfResolvesAgainstTheWorkingDirectory() {
        val cache = pagesCacheFile(File("book.pdf"))
        assertTrue(cache.isAbsolute)
        assertEquals(File("book.v4.pages.json").absoluteFile, cache)
    }
}
