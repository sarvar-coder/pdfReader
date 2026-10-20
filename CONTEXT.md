# Ember

A personal reading app that turns an imported PDF into reflowed, restyleable prose. This glossary fixes
the words used for that, in code and in conversation.

## Language

**Book**:
One imported PDF and everything derived from it — its text, cover, reading position and notebook.
_Avoid_: Document, file, PDF (the PDF is the source, the Book is the thing the reader reads)

**Library**:
The full set of imported Books.
_Avoid_: Shelf, Collection (that is a bucket of Words)

**Reflow**:
Discarding a PDF's original layout and re-laying its text out to the screen and the reader's current
style. The app's central act.
_Avoid_: Render, paginate, format

**Block**:
One classified unit of reflowed text — a body paragraph, a title or a subtitle.
_Avoid_: Node, element, section

**Page**:
One screenful of reflowed Blocks. Depends on screen size and style, so it is not a PDF page and not
stable across a style change.
_Avoid_: Screen, view, sheet

**Reading fraction**:
How far through a Book the reader has got, as a proportion of its text. The canonical form of reading
position, because it survives a style change.
_Avoid_: Page number, offset, progress

**Chapter**:
A named division of a Book, taken from the PDF's own outline or, failing that, from the headings
detected in its text. Used to jump around a Book, not to break it up — Pages ignore Chapters.
_Avoid_: Section, heading, toc, contents

**Highlight**:
A passage the reader marked, stored as the quoted text itself.
_Avoid_: Annotation, selection, marker

**Word**:
A single word the reader long-pressed in a Book and saved, stored lower-cased and trimmed of edge
punctuation, with the sentence it came from and the Book it was picked in.
_Avoid_: Vocabulary, term, flashcard

**Collection**:
A numbered bucket of at most 20 Words ("Collection 1", "Collection 2", …). A Word joins the newest
Collection; when that one is full, a new Collection opens. A Word already saved in any Collection is
skipped, never saved twice.
_Avoid_: Deck, list, set

**Bookmark**:
A place in a Book the reader saved to return to.
_Avoid_: Favourite, saved page

**Notebook**:
The reader's own writing about one Book — one per Book, written and read in the reading typeface.
_Avoid_: Note, notes, journal

**Reading session**:
One continuous stretch of a Book being open, with its minutes and pages. Writing in the Notebook counts.
_Avoid_: Visit, sitting, log entry

**Streak**:
Consecutive days with at least one Reading session. Derived from the sessions, never stored.
_Avoid_: Chain, run
