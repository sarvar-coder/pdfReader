# Ember

A personal, single-user reading app for iOS and Android. Ember imports a PDF, extracts its text and
**reflows** it into swipeable, screen-sized pages you can restyle — theme, font size, typeface, line
spacing. The PDF's original layout and images are discarded on purpose: prose only.

## Features

- **Library** — import PDFs from the file picker or the system share sheet; covers rendered from page 1.
- **Reader** — reflowed pages, reading position kept as a fraction of the text so it survives restyling.
- **Chapters** — taken from the PDF outline, or from detected headings when there is none.
- **Highlights & bookmarks** — saved per book.
- **Notebook** — one per book, written and read in the same reflowed form as the book.
- **Stats** — reading sessions, minutes, pages and a daily streak.

Vocabulary (Book, Page, Block, Reading fraction, …) is defined in [`CONTEXT.md`](CONTEXT.md).

## Stack

Flutter · Riverpod 3 · Hive (hand-written adapters, no codegen) · `syncfusion_flutter_pdf` for text
extraction · `pdfrx` for cover thumbnails only · Google Fonts at runtime (Fraunces, Inter, Spectral).

## Getting started

```bash
flutter pub get
flutter run
```

## Tests

```bash
flutter test test/reflow_test.dart test/note_page_test.dart test/note_screen_test.dart \
  test/pdf_text_test.dart test/chapters_test.dart
```

Name the files explicitly. Bare `flutter test` also runs `test/gen_icon_test.dart`, which rewrites
`assets/icon/*.png`.

## Assets

```bash
dart run flutter_launcher_icons            # app icon
dart run flutter_native_splash:create      # splash screen
```

## Layout

```
lib/
  services/   storage (Hive + file paths), PDF extraction
  providers/  library, reader, highlights, bookmarks, sessions, stats
  features/   library, reader, notes, stats — never import each other
  widgets/    app shell (Library / Stats tabs) and shared widgets
  theme/      colors and app theme
tool/         extract_probe.dart — eyeball extraction on a real PDF
```

```bash
PDF=~/Downloads/book.pdf FROM=20 flutter test tool/extract_probe.dart
```

Contributor and agent conventions: [`CLAUDE.md`](CLAUDE.md).
