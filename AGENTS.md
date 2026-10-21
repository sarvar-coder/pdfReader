# AGENTS.md

Guidance for coding agents working in this repository. `CLAUDE.md` is a symlink to this file — edit
`AGENTS.md`.

## Project

**Ember** — a personal, single-user Android reading app (Kotlin, Jetpack Compose). It imports PDFs, extracts
their text, and **reflows** it into swipeable, screen-sized pages the user can restyle (theme, font size,
typeface, line spacing). Original PDF layout/images are intentionally discarded — prose only. Long-pressing
a word saves it into 20-word Collections.

Domain vocabulary: `CONTEXT.md`. Use its words (Book, Page, Block, Reading fraction, Word, Collection, …)
in code, commits and chat, and not the words it lists under _Avoid_.

## Build & test

```bash
./gradlew testDebugUnitTest lintDebug assembleDebug assembleRelease   # JDK 17
```

Unit tests are plain JVM (no Robolectric). PdfBox-Android needs a `Context` for its font resources, so
extraction is tested through `reflowLines` on hand-built `PdfLine`s, not on real PDFs. Release builds
run R8 with resource shrinking; add rules to `app/proguard-rules.pro` only when `assembleRelease` asks.

- Needs `local.properties` with `sdk.dir=…` (gitignored).
- Tests live in `app/src/test/java/com/sarvarbek/ember/`, mirroring the source packages. One class:
  `./gradlew testDebugUnitTest --tests 'com.sarvarbek.ember.pdf.ReflowTest'`.
- No emulator or device is set up. PdfBox line stripping, covers and gestures are unverified on device —
  say so rather than claiming end-to-end verification.
- `.claude/hooks/guard.sh` blocks `git reset --hard`, `git checkout --` and `git clean -f`. Self-test:
  `bash .claude/hooks/guard.sh --self-test`.

## Architecture

`App` builds one `AppContainer` (Room db, `StorageFiles`, `PdfService`, `WordRepository`, prefs,
`appScope`), and screens get it as a parameter. ViewModels are created with `viewModel { … }` per Nav3 entry.

```
app/src/main/java/com/sarvarbek/ember/
  navigation/  Routes (serializable NavKeys), EmberNavHost (the one back stack), AppShell (3 tabs)
  features/    library/  reader/  notes/  words/  stats/
  data/        Room entities + DAOs (db/), StorageFiles, WordRepository, ReadingStats
  pdf/         PdfService (PdfBox-Android text, PdfRenderer covers), LineStripper, Reflow
  ui/          theme/ (AppColors, type, theme) and widgets/ shared across features
```

`AppShell` holds the Library, Words and Stats tabs. Reader, Notes and a word Collection are pushed on the
back stack over it, not tabs. Writes that must outlive a screen go through `appScope`.

Per-file invariants live at their code site: read the doc comments in `pdf/Reflow.kt`,
`features/reader/Reflow.kt`, `features/reader/Pagination.kt` and `pdf/PdfService.kt` before editing those.

## Packaging

- Features under `features/` never import each other. Pass callbacks up (e.g. `onOpenNotes`) and let
  `EmberNavHost` own navigation.
- Shared UI in `ui/widgets/`, data access in `data/`, PDF work in `pdf/`. No grab-bag `common/` —
  anything shared gets a name from its domain.

## Conventions

- Palette colors come from `ui/theme/AppColors.kt`; reader themes and typefaces from
  `features/reader/ReaderSettings.kt`.
- Fonts are Google Fonts at runtime (Fraunces / Inter / Spectral) — no bundled font files.
- IO, decoding and text measurement run off the main thread; lazy lists and the pager are keyed.
- Mark deliberate shortcuts with `// ponytail:` naming the ceiling and the upgrade path.

## Lessons

When an agent gets something wrong and is corrected, add one line here: `- YYYY-MM-DD — do/don't — why`.
Newest last. Delete a line once the code or a test enforces it.

- 2026-10-16 — Take each extracted line's text as-is; don't rebuild it from words or glyph bounds — both
  were measured worse (glued prose, letter-spaced titles, broken ligatures). Kerning splits ("Y ou",
  "WHA T") are fixed by `repairKerningSplits` in `pdf/Reflow.kt`.
- 2026-10-20 — Flutter is gone: no `lib/`, `.dart` files or `flutter` commands. Kotlin and Gradle only.
