# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Ember** — a personal, single-user Flutter reading app (iOS/Android). It imports PDFs, extracts their
text, and **reflows** it into swipeable, screen-sized pages the user can restyle (theme, font size,
typeface, line spacing). Original PDF layout/images are intentionally discarded — prose only.

`PLAN.md` / `STEPS.md` are the original build spec and are partly stale (they describe 4 bottom-nav
tabs incl. a "Saved" screen; shipped app has 2 tabs — Library and Stats — with highlights/bookmarks
in the reader's contents sheet). Use them for design tokens (palette, reader themes, ranges), not for
current structure.

## Commands

```bash
flutter pub get
flutter run                       # attach a device first: flutter devices
flutter analyze                   # lint gate (flutter_lints)
flutter test                      # see caveat below
flutter build apk --debug         # Android toolchain check
```

`test/gen_icon_test.dart` is **not a test** — it's a one-off rasterizer that paints the app icon /
splash logo into `assets/icon/`. `flutter test` runs it and rewrites those PNGs. After changing it:

```bash
flutter test test/gen_icon_test.dart   # regenerate PNGs
dart run flutter_launcher_icons        # icons
dart run flutter_native_splash:create  # splash
```

The real tests are three files, always named explicitly so the rasterizer above never runs:

```bash
flutter test test/reflow_test.dart test/note_page_test.dart test/note_screen_test.dart
```

`reflow_test` guards block classification, `note_page_test` the notes page-grid arithmetic, and
`note_screen_test` drives the notes screen itself (paging, swipe, saving) through a `_FakeStorage`
that `implements StorageService` — its constructor is private, so a fake cannot extend it. Coverage
stops there; everything else is verified by running the app.

## Toolchain constraints

Flutter 3.41 / Dart 3.11 / AGP 8.11 / Kotlin 2.2. Two pins depend on this and must not be bumped
casually:

- `receive_sharing_intent: 1.8.1` (exact) — 1.9.0 needs AGP 9 / Kotlin 2.4 / compileSdk 37.
- Hive adapters are **hand-written**, not generated — `hive_generator` conflicts with the analyzer
  version Riverpod 3 pulls in. Never add `build_runner`/codegen for models.

## Architecture

Layers: `main.dart` builds `StorageService` **before** `runApp` and injects it via a `ProviderScope`
override → providers read it → screens watch providers. `services/` never imports `providers/`.

```
main.dart → StorageService.init() → ProviderScope(override storageServiceProvider)
services/   storage_service.dart (Hive boxes + file paths)  pdf_service.dart (both PDF libs)
providers/  library, reader, highlights, bookmarks, sessions, stats
features/   library/  reader/  notes/  stats/   widgets/ app_shell.dart (2-tab frosted nav)
```

Imports inside `lib/` use absolute `package:ember/...` (only `main.dart`/`app.dart` use relative).

### The two PDF packages — do not mix them up

`pdf_service.dart` is the only file that touches either, and the split is deliberate:

- **syncfusion_flutter_pdf** — text extraction and page count. Pure Dart, so it runs inside
  `Isolate.run`; keeping it off the UI isolate is what prevents an Android ANR on large files. It
  cannot render, and it cannot extract images — its `PdfImage`/`PdfBitmap` are for *writing* PDFs.
- **pdfrx** — rasterizes page 1 into a cover PNG only. Uses PDFium via FFI, so it **cannot** go
  through `Isolate.run` — it must stay on the main isolate. It's imported `as pdfrx` because both
  packages export `PdfDocument`/`PdfPage`.

The reader is text-only by design: images, tables and original page layout are dropped, and that is
the intended product, not a gap to fill.

### Per-book files and caching

Everything for a book is derived from its id under `<docs>/books/`: `<id>.pdf`, `<id>.txt`
(extracted-text cache), `<id>.png` (cover), `<id>.note.txt` (the user's notebook).
`StorageService` owns all four paths; deleting a book removes all four.

The text cache is **never invalidated** — PDFs are copied once at import and never rewritten. Import
(`LibraryNotifier.importPdf`) is non-blocking: page count is awaited, but full extraction and cover
rendering are detached `unawaited` best-effort jobs that bump `state` when they land. A reader open
that beats the prefetch extracts on demand and writes the cache itself. Missing cover → gradient
fallback (`_coverGradients`, assigned by title hash).

### The reflow pipeline (`features/reader/reflow.dart`)

Shared by the reader (a book's extracted text) and the notes screen (a book's notebook), so both
read identically. Public surface is only `toBlocks`, `Block`/`BlockKind`, `Mark`, `PagedBody`,
`Paragraph`, `kIndent` and `kPagePadding` — everything else is private to that file. `kPagePadding`
is the page box inset; the notes editor measures its own grid against the same box, so the two must
not drift apart again (they were duplicated constants).

Text → `Block`s (`toBlocks` classifies each line as body / title / subtitle via keyword, numbering,
ALL-CAPS and Title-Case heuristics) → `_PagedBodyState._paginate` measures blocks with a
`TextPainter` against the real box and slices paragraphs at line boundaries → `PageView` of
`_ReaderPage`s. Constraints that hold this together:

- Pagination is memoized on `Object.hashAll([width, height, fontSize, lineSpacing, typeface, block
  texts])`. Theme color and highlight marks deliberately aren't in the key — they don't affect layout.
- The `PageView` is wrapped in `MediaQuery.withNoTextScaling` because `_paginate`'s `TextPainter` has
  no scaler; the OS font scale would otherwise overflow every measured page. In-app "Aa" is the only
  size control.
- Each page keeps a small vertical scroll and half-a-line of measured slack, because a continuation
  slice can re-wrap one line longer than measured. Don't remove either without re-checking clipping.
- Highlights are re-matched by `String.indexOf` of the saved quote inside each rendered paragraph
  (`Paragraph`), not by stored offsets — offsets would break on re-flow.
- `kIndent` is two **em-spaces** (U+2003), not ASCII spaces. Retyping it as spaces silently kills
  the first-line indent. `test/reflow_test.dart` guards this and the block classification; run it
  alone (`flutter test test/reflow_test.dart`), never via bare `flutter test`.

### Notes (`features/notes/note_screen.dart`)

One notebook per book, a plain text file — no Hive box, no model, no provider; the screen reads and
writes it through `storageServiceProvider` — captured into a `_storage` field while mounted, because
`ref` throws once the element is defunct and `dispose` runs the last save. Pushed as a full-screen
route from the reader's `edit_note` icon. The book icon in its top bar toggles writing and reading
(`PagedBody` over `toBlocks(text)`) mode; both render with the live `ReaderSettings`, and both turn
pages horizontally, by swipe or by the `‹ n/m ›` chevrons under the page. Saves are debounced 800 ms
and repeated on mode switch, back, dispose and app pause; `_saved` makes an unchanged notebook a
no-op write. The reader's session timer keeps running underneath, so time spent writing counts as
reading time.

Writing mode is **not** a `PageView` — it is one natural-height `TextField` inside the screen's own
`SingleChildScrollView`, whose offset is quantized to whole lines. Four things hold it up:

- `measuredLineHeight` measures the line box with a `TextPainter` and the field's forced strut.
  `fontSize * lineSpacing` is the nominal value and it is **not** good enough: the engine rounds a
  line box up (30.6 → 31.0), and a third of a pixel per line puts the grid out by two lines within a
  few pages. `ReaderSettings.lineHeight` is fine for slack, never for a grid.
- A trailing `SizedBox` of one full viewport makes `maxScrollExtent` exactly the field's own height,
  so the last page lands on the grid instead of clamping short and repeating the previous page.
- `_PagedOnlyScrollPhysics` overrides `allowUserScrolling` only. `NeverScrollableScrollPhysics` also
  clears `allowImplicitScrolling`, which makes `RenderEditable.showOnScreen` a no-op and strands the
  caret off-screen while typing.
- The swipe `GestureDetector` must be the **topmost** child of the `Stack` with
  `HitTestBehavior.translucent`. `Stack` hit-tests its last child first, so it is routed before the
  `TextField`'s own `TapAndHorizontalDragGestureRecognizer` and wins the Android arena; an *ancestor*
  detector loses it. Taps, long-press and selection handles still reach the field underneath.

`_settle` (on `ScrollEndNotification` at `depth == 0`) pulls the offset back onto the grid after the
caret reveal that follows a keystroke; `notePageFor` rounds **up** going forward and **down** going
back, never to nearest. `_reanchor` holds the top *line* index across a grid change, so opening the
keyboard doesn't walk the view backwards.

### Reading position and sessions

Position is stored as `Book.readingFraction` (0.0–1.0), never a page index or pixel offset, so it
survives font/spacing changes; `currentPage` is derived for display only. `_onPaginated` realigns the
controller after every re-pagination; a one-shot `pendingJumpProvider` handles bookmark/highlight
jumps.

`readerContentProvider` watches `currentPdfPathProvider` (a stable `String`), **not** the `Book` —
saving the scroll position mints a new `Book` instance, and watching it would re-run extraction and
flash the reader on every swipe. Preserve that indirection.

Reading sessions are timed in `_ReaderScreenState`: started on open, ended in `dispose` and on
app-lifecycle pause/hide/detach. `_endSession` goes through a `ProviderContainer` captured in
`initState`, not `ref` — Riverpod 3 throws unconditionally on `ref` from `dispose`, and because
`_endSession` is sync that threw before `removeObserver`/`_pageController.dispose()` could run. Sessions with 0 minutes and 0 pages are dropped. `statsProvider`
derives streak, longest streak, week dots, heatmap levels and totals purely from those sessions plus
the library — there is no stored streak counter.

### Adding a persisted field

Hive adapters are manual. To add a field to `Book`/`Highlight`/`Bookmark`/`ReadingSession`: append a
new index in `write` (bump the `writeByte(n)` field count), read it in `read` with a null-safe default
for records written before it existed, and never renumber existing indices. TypeIds: Book 0,
Highlight 1, Bookmark 2, ReadingSession 3.

### Navigation

`AppShell` is an `IndexedStack` of Library and Stats behind a frosted nav bar. The reader is **not** a
tab — it's a full-screen `MaterialPageRoute` pushed from Library, so `currentBookIdProvider` (and its
`continueReadingProvider` fallback) is what tells it which book to show. The notes screen is a second
full-screen route pushed on top of the reader; it takes `bookId`/`title` as constructor args rather
than reading `currentBookProvider`, so the continue-reading fallback can't swap the book under it.

PDFs shared or opened from other apps arrive through `receive_sharing_intent` in `AppShell.initState`
(both `getInitialMedia` for cold start and `getMediaStream` for warm); Android intent filters and iOS
`CFBundleDocumentTypes` are already configured.

## Conventions

- Colors come from `theme/app_colors.dart`; reader themes/typefaces from
  `features/reader/reader_settings.dart`. No raw hex in widgets.
- Fonts are Google Fonts at runtime (Fraunces / Inter / Spectral) — no bundled font assets.
- Deliberate shortcuts are marked with `// ponytail:` comments naming the ceiling; keep that style
  when simplifying.
