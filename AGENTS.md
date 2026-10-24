# Project Memory — Ember

Ember is a personal, single-user Android reading app (Kotlin, Jetpack Compose) that imports PDFs and
**reflows** their text into swipeable, restyleable pages — prose only, original layout and images discarded.

`CLAUDE.md` is a symlink to this file — edit `AGENTS.md`.

## Repo layout
```
app/src/main/java/com/sarvarbek/ember/
  navigation/  Routes (serializable NavKeys), EmberNavHost (the one back stack), AppShell (3 tabs)
  features/    library/  reader/  notes/  words/  stats/
  data/        Room entities + DAOs (db/), StorageFiles, WordRepository, ReadingStats
  pdf/         PdfService (PdfBox-Android text, PdfRenderer covers), LineStripper, Reflow
  ui/          theme/ (AppColors, type, theme) and widgets/ shared across features
app/src/test/java/com/sarvarbek/ember/   JVM unit tests, mirroring the source packages
app/proguard-rules.pro                   R8 rules for assembleRelease
.claude/hooks/guard.sh                   regex guard: only literal git reset --hard / checkout -- / clean -f
```
- `App` builds one `AppContainer` (Room db, `StorageFiles`, `PdfService`, `WordRepository`, prefs,
  `appScope`); screens get it as a parameter. ViewModels are created with `viewModel { … }` per Nav3 entry.
- `AppShell` holds the Library, Words and Stats tabs. Reader, Notes and a word Collection are pushed on the
  back stack over it, not tabs.
- Per-file invariants live at their code site: read the doc comments in `pdf/Reflow.kt`,
  `features/reader/Reflow.kt`, `features/reader/Pagination.kt` and `pdf/PdfService.kt` before editing those.
- Don't touch: `build/`, `app/build/`, `.gradle/`, `.kotlin/`, `.idea/`, `local.properties` (generated or
  machine-local).

## Terminology
Full glossary in `CONTEXT.md`. Use its words in code, commits and chat, and not the ones it lists under
_Avoid_. The ones most easily confused:
- **Book** — an imported PDF plus everything derived from it. The PDF is only the source.
- **Page** — one screenful of reflowed Blocks. Not a PDF page; changes when the style changes.
- **Block** — one classified unit of reflowed text: body paragraph, title or subtitle.
- **Reading fraction** — reading position as a proportion of the text. Canonical, because it survives
  restyling; never store a page number.
- **Word / Collection** — a long-pressed saved word (lower-cased, edge punctuation trimmed) / a numbered
  bucket of at most 20 Words. A Word already in any Collection is skipped.
- **Notebook** — the one per-Book piece of the reader's writing. Not "notes".

## Run & test
Needs JDK 17 and `local.properties` with `sdk.dir=…`.
- Install: nothing beyond the SDK; Gradle fetches dependencies.
- Run locally: `./gradlew installDebug` — needs a physical phone over adb (**never use an emulator**).
- Unit tests: `./gradlew testDebugUnitTest`; one class:
  `./gradlew testDebugUnitTest --tests 'com.sarvarbek.ember.pdf.ReflowTest'`.
- E2E / on-device verification: none set up yet — see `.agents/skills/e2e-testing`.
- Lint/build before finishing: `./gradlew testDebugUnitTest lintDebug assembleDebug assembleRelease`.

Unit tests are plain JVM (no Robolectric); PDF extraction is tested via hand-built `PdfLine`s. Release builds run
R8 with resource shrinking; add rules to `app/proguard-rules.pro` only when `assembleRelease` asks.

## Shipping & review
Every branch ships through the no-mistakes gate (`git push no-mistakes <branch>` or `/no-mistakes`), which
rebases, reviews, tests, lints, opens the PR and waits on CI.
- **High risk — read the diff, and require on-phone evidence:** `pdf/Reflow.kt`, `pdf/PdfService.kt`,
  `pdf/LineStripper.kt`, `features/reader/Reflow.kt`, `features/reader/Pagination.kt`, `data/db/` (schema or
  migrations), anything touching the Reading fraction, and `app/proguard-rules.pro`.
- **Low risk — evidence is enough (PR description, test results, green CI):** tests only, docs, CI config, and
  isolated UI copy or styling.
- Never approve the gate's "skip live validation" on a high-risk change: reflow, pagination and stored data
  only show their bugs on a real Book on the phone.

## Conventions
- Features under `features/` never import each other. Pass callbacks up (e.g. `onOpenNotes`) and let
  `EmberNavHost` own navigation.
- Shared UI in `ui/widgets/`, data access in `data/`, PDF work in `pdf/`. No grab-bag `common/` —
  anything shared gets a name from its domain.
- Writes that must outlive a screen go through `appScope`.
- Palette colors come from `ui/theme/AppColors.kt`; reader themes and typefaces from
  `features/reader/ReaderSettings.kt`.
- Fonts are Google Fonts at runtime (Fraunces / Inter / Spectral) — no bundled font files.
- IO, decoding and text measurement run off the main thread; lazy lists and the pager are keyed.
- Mark deliberate shortcuts with `// ponytail:` naming the ceiling and the upgrade path.

## Lessons learned
When the user corrects a mistake, add a one-line entry to Lessons learned. When a lesson recurs, promote it
to Conventions. Remove lessons that no longer apply. Format: `- YYYY-MM-DD <mistake> → <what to do instead>`.
- 2026-10-16 Rebuilt line text from words / glyph bounds; measured worse (glued prose, letter-spaced
  titles, broken ligatures) → take each extracted line's text as-is; kerning splits ("Y ou", "WHA T") are
  fixed by `repairKerningSplits` in `pdf/Reflow.kt`.
- 2026-10-20 Reached for Flutter paths and commands after the Kotlin port → no `lib/`, `.dart` or
  `flutter`; Kotlin and Gradle only.
