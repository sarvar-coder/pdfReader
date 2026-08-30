# Ember

A personal reading app that turns an imported PDF into reflowed, restyleable prose. This glossary fixes
the words used for that, in code and in conversation.

## Language

**Book**:
One imported PDF and everything derived from it — its text, cover, reading position and notebook.
_Avoid_: Document, file, PDF (the PDF is the source, the Book is the thing the reader reads)

**Library**:
The full set of imported Books.
_Avoid_: Shelf, collection

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

**Highlight**:
A passage the reader marked, stored as the quoted text itself.
_Avoid_: Annotation, selection, marker

**Bookmark**:
A place in a Book the reader saved to return to.
_Avoid_: Favourite, saved page

**Notebook**:
The reader's own writing about one Book — one per Book, readable in the same reflowed form as the Book.
_Avoid_: Note, notes, journal

**Reading session**:
One continuous stretch of a Book being open, with its minutes and pages. Writing in the Notebook counts.
_Avoid_: Visit, sitting, log entry

**Streak**:
Consecutive days with at least one Reading session. Derived from the sessions, never stored.
_Avoid_: Chain, run
