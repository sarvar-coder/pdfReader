package com.sarvarbek.ember.pdf

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** A line of body text on the standard measure, 50pt to 500pt. */
private fun line(
    text: String,
    top: Double,
    left: Double = 50.0,
    right: Double = 500.0,
    fontSize: Double = 12.0,
    page: Int = 0,
) = PdfLine(text, top, left, right, fontSize, page)

private fun String.paras() = split("\n\n")

class ReflowTest {
    @Test fun `wrapped lines re-join into one paragraph`() {
        val pages = reflowLines(
            listOf(
                line("the first line of it", 100.0),
                line("the second line of it", 118.0),
                line("and the end.", 136.0, right = 300.0),
            ), 1,
        )
        assertEquals("the first line of it the second line of it and the end.", pages.first())
    }

    @Test fun `a wider-than-usual vertical step starts a new paragraph`() {
        val pages = reflowLines(listOf(line("one", 100.0), line("two", 118.0), line("a new paragraph", 150.0)), 1)
        assertEquals(listOf("one two", "a new paragraph"), pages.first().paras())
    }

    @Test fun `a first-line indent starts a new paragraph`() {
        val pages = reflowLines(listOf(line("one", 100.0), line("two", 118.0), line("indented", 136.0, left = 62.0)), 1)
        assertEquals(listOf("one two", "indented"), pages.first().paras())
    }

    @Test fun `a line stopping short of the measure ends its paragraph`() {
        val pages = reflowLines(
            listOf(line("one", 100.0), line("short of the measure", 118.0, right = 300.0), line("next", 136.0)), 1,
        )
        assertEquals(listOf("one short of the measure", "next"), pages.first().paras())
    }

    @Test fun `a running head repeated across pages is dropped, a chapter title is not`() {
        val lines = buildList {
            for (page in 0 until 4) {
                add(line("Running Head", 10.0, right = 200.0, page = page))
                if (page == 0) add(line("A Chapter Title", 60.0, right = 200.0, page = page))
                add(line("body one", 100.0, page = page))
                add(line("body two", 118.0, page = page))
                add(line("body three.", 136.0, right = 300.0, page = page))
            }
        }
        val pages = reflowLines(lines, 4)
        assertTrue(pages.none { "Running Head" in it })
        assertTrue("A Chapter Title" in pages.first())
        assertEquals("body one body two body three.", pages.last())
    }

    @Test fun `a paragraph spanning a page break stays whole, on the page it began`() {
        val pages = reflowLines(
            listOf(
                line("this paragraph starts here", 100.0, page = 0),
                line("and runs on", 118.0, page = 0),
                line("to the next page.", 100.0, page = 1, right = 300.0),
            ), 2,
        )
        assertEquals("this paragraph starts here and runs on to the next page.", pages[0])
        assertEquals("", pages[1])
    }

    @Test fun `a change of type size separates a heading across a page break`() {
        val pages = reflowLines(
            listOf(
                line("a paragraph that fills the measure", 100.0, page = 0),
                line("A Heading", 100.0, page = 1, fontSize = 20.0, right = 300.0),
                line("its first paragraph", 140.0, page = 1, right = 300.0),
            ), 2,
        )
        assertEquals("a paragraph that fills the measure", pages[0])
        assertEquals(listOf("A Heading", "its first paragraph"), pages[1].paras())
    }

    @Test fun `lines sharing a baseline merge into one row, left to right`() {
        val pages = reflowLines(
            listOf(
                line("the", 100.0, right = 120.0),
                line("command runs.", 102.0, left = 165.0, right = 300.0),
                line("touch", 101.0, left = 124.0, right = 160.0),
            ), 1,
        )
        assertEquals("the touch command runs.", pages.first())
    }

    @Test fun `touching parts of a tracked-out display line join without a space`() {
        val pages = reflowLines(
            listOf(
                line("CA", 100.0, right = 120.0, fontSize = 20.0),
                line("T", 100.0, left = 120.0, right = 132.0, fontSize = 20.0),
                line("ALOG", 100.0, left = 132.0, right = 200.0, fontSize = 20.0),
            ), 1,
        )
        assertEquals("CATALOG", pages.first())
    }

    @Test fun `tabs and runs of spaces collapse to single spaces`() {
        val pages = reflowLines(listOf(line("set\tand\t\tmodify", 100.0, right = 300.0)), 1)
        assertEquals("set and modify", pages.first())
    }

    @Test fun `a numbered item after a finished sentence opens a paragraph`() {
        val pages = reflowLines(
            listOf(
                line("something you have never experienced before.", 100.0),
                line("09. Downsizing your friend group; feeling", 118.0),
                line("more and more uncomfortable.", 136.0, right = 300.0),
            ), 1,
        )
        assertEquals(
            listOf(
                "something you have never experienced before.",
                "09. Downsizing your friend group; feeling more and more uncomfortable.",
            ),
            pages.first().paras(),
        )
    }

    @Test fun `a wrapped line opening with a number does not break the paragraph`() {
        val pages = reflowLines(
            listOf(line("the version shipped in release", 100.0), line("2. the next one fixed it.", 118.0, right = 300.0)),
            1,
        )
        assertEquals("the version shipped in release 2. the next one fixed it.", pages.first())
    }

    @Test fun `kerning splits re-join, real one-letter words stay`() {
        assertEquals("You’re beginning", repairKerningSplits("Y ou’re beginning"))
        assertEquals("Table of Contents", repairKerningSplits("T able of Contents"))
        assertEquals("WHAT the", repairKerningSplits("WHA T the"))
        assertEquals("ABSTRACT FACTORY", repairKerningSplits("ABSTRACT F ACTORY"))
        assertEquals("11. Feeling as though", repairKerningSplits("1 1. Feeling as though"))
        assertEquals("A lot of I think", repairKerningSplits("A lot of I think"))
        assertEquals("press Shift+F on Mac", repairKerningSplits("press Shift+F on Mac"))
        assertEquals("class Box<T extends Object>", repairKerningSplits("class Box<T extends Object>"))
        assertEquals("Plan B is set", repairKerningSplits("Plan B is set"))
        assertEquals("if P and Q hold", repairKerningSplits("if P and Q hold"))
        assertEquals("along the Y axis", repairKerningSplits("along the Y axis"))
        assertEquals("TOTAL W", repairKerningSplits("TOTAL W"))
    }

    @Test fun `file names clean into titles`() {
        assertEquals("Maybe You Should Talk to Someone", cleanTitle("Maybe_You_Should_Talk_to_Someone"))
        assertEquals(
            "Essays That Will Change",
            cleanTitle("31_10_2020_084952101_Essays_That_Will_Change_250402_141956"),
        )
        assertEquals("Clean Code A Handbook", cleanTitle("Clean.Code.A.Handbook"))
        assertEquals("Heathy Brain Happy Life", cleanTitle("Heathy-Brain-Happy-Life-pdf"))
        assertEquals("Mobile System Design", cleanTitle("750267473-Mobile-System-Design-v008_241222_214424"))
        assertEquals("10 Rules for Life", cleanTitle("10_Rules_for_Life"))
        assertEquals("Designing Data-Intensive Applications", cleanTitle("Designing Data-Intensive Applications"))
    }

    @Test fun `metadata filters junk`() {
        assertEquals(null, usableMeta("Microsoft Word - draft3.docx"))
        assertEquals(null, usableMeta(" Untitled "))
        assertEquals("Ember", usableMeta(" Ember "))
    }

    @Test fun `content cache round-trips, corrupt is a miss`() {
        val content = PdfContent(listOf("one\n\ntwo", "", "three"), listOf(Chapter("Intro", 0)))
        assertEquals(content, decodeContent(encodeContent(content)))
        assertEquals(PdfContent(emptyList(), emptyList()), decodeContent(encodeContent(PdfContent(emptyList(), emptyList()))))
        assertEquals(null, decodeContent("{\"pages\": [1"))
    }
}
