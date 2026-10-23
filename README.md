# Ember

A personal, single-user reading app for Android. Ember imports a PDF, extracts its text and **reflows** it
into swipeable, screen-sized pages you can restyle — theme, font size, typeface, line spacing. The PDF's
original layout and images are discarded on purpose: prose only.

## Features

- **Library** — import PDFs from the file picker, "Open with" or the share sheet; covers rendered from page 1.
- **Reader** — reflowed pages, reading position kept as a fraction of the text so it survives restyling.
- **Chapters** — taken from the PDF outline, or from detected headings when there is none.
- **Highlights & bookmarks** — saved per book.
- **Words** — long-press a word to save it, with its sentence, into Collections of up to 20 Words.
- **Notebook** — one per book.
- **Stats** — reading sessions, minutes, pages, a daily streak and a heatmap of the last 91 days.

Vocabulary (Book, Page, Block, Reading fraction, Word, Collection, …) is defined in [`CONTEXT.md`](CONTEXT.md).

## Stack

Kotlin · Jetpack Compose (Material 3) · Navigation 3 · Room · PdfBox-Android for text extraction ·
`PdfRenderer` for covers · Google Fonts at runtime (Fraunces, Inter, Spectral).

## Build & test

Needs JDK 17 and the Android SDK (`local.properties` with `sdk.dir=…`).

```bash
./gradlew testDebugUnitTest lintDebug assembleDebug assembleRelease
./gradlew installDebug
```

Contributor and agent conventions: [`AGENTS.md`](AGENTS.md).
