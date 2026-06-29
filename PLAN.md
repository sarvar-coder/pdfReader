# Ember Reader — Build Plan

A personal Flutter reading app. Reflowable in-app book reader (change font size,
highlights, bookmarks, resume last page, streak + stats). Built with Flutter +
Riverpod. **Design-first:** build the UI to match the mockup, then wire PDF logic.

Design mockup: `~/Downloads/reader_app_design.html`

---

## Design tokens

**Palette**

| Token       | Hex       | Use                  |
|-------------|-----------|----------------------|
| paper       | `#F1E9DB` | app background       |
| card        | `#FBF7EF` | raised cards         |
| card-2      | `#F4ECDD` | secondary surfaces   |
| ink         | `#2A241E` | primary text         |
| ink-soft    | `#7A6F61` | secondary text       |
| ink-faint   | `#A89C8A` | tertiary text        |
| line        | `#E4D9C6` | hairlines/borders    |
| ember       | `#DD7536` | primary accent       |
| ember-deep  | `#BE4F1E` | accent pressed/links |
| ember-soft  | `#F6E2CF` | accent backgrounds   |
| gold        | `#D6A24B` | highlight default    |
| leaf        | `#7E8A5A` | "done"/success       |

**Fonts** (all on Google Fonts → use `google_fonts`, no asset bundling):
Fraunces (headings/serif), Inter (UI/sans), Spectral (reading text/serif).

**Reader themes:** Paper `bg #F6F1E7 / ink #2b2620` · Sepia `bg #E8D5AE / ink #4a3b28` · Night `bg #16130F / ink #D8CFC2`.

**Highlight colors:** yellow `#f2d24b` · green `#7fc56b` · blue `#6bb4f0` · pink `#f08aa6`.

**Font size range:** 14–26 pt. **Line spacing:** 1.4–2.2.

---

## Phase 0 — Project setup
- [ ] `flutter create` the app in this repo (`.`)
- [ ] Add packages: `flutter_riverpod`, `google_fonts`
- [ ] Wrap app in `ProviderScope`
- [ ] `lib/theme/app_colors.dart` (palette) + `lib/theme/app_theme.dart` (ThemeData + 3 Google fonts)
- [ ] Confirm it runs on device with a blank themed screen

**Folder layout** (Riverpod, feature-first):

```
lib/
  main.dart  app.dart
  theme/        app_colors.dart  app_theme.dart
  models/       book.dart  highlight.dart  bookmark.dart  reading_session.dart
  providers/    (Riverpod providers added per phase)
  services/     storage_service.dart  pdf_service.dart
  features/
    library/  reader/  saved/  stats/   (each: screen + widgets/)
  widgets/      app_shell.dart (bottom nav)  book_cover.dart
```

## Phase 1 — Build the design with dummy data (priority)
All 4 screens pixel-close to the mockup, navigable, no PDF logic — hardcoded data.
- [ ] App shell + bottom nav (Library · Reading · Saved · Stats)
- [ ] Library: greeting, animated streak card, continue-reading card, shelf grid + "Add a PDF" tile
- [ ] Reader (static text): top chrome, scrollable page, bottom progress; tap-to-hide-chrome; Aa settings sheet (theme/font-size/typeface/line-spacing) driving a dummy text block live; highlight selection toolbar (4 swatches)
- [ ] Saved: Highlights/Bookmarks tabs with sample cards
- [ ] Stats: big ember, streak number, stat grid, quarter heatmap
- Covers this phase: generated gradient + title cards (decide thumbnails later)

## Phase 2 — Data layer & persistence
- [ ] Choose local store (recommend Hive for metadata + settings)
- [ ] Models: Book, Highlight, Bookmark, ReadingSession
- [ ] StorageService: copy PDFs to `<docs>/books/<id>.pdf` (path derived from id) + Hive boxes
- [ ] Replace dummy data with Riverpod providers backed by storage

## Phase 3 — PDF import + text extraction (reflow engine)
- [ ] Add `file_picker` + `path_provider`; wire "Add a PDF" to pick & save permanently
- [ ] Choose text-extraction package (decision point; syncfusion_flutter_pdf is a candidate)
- [ ] Extract text → reflow reader (paginate or continuous); apply font/typeface/spacing/theme live
- [ ] Resume: save last position per book, reopen there

## Phase 4 — Reading features
- [ ] Highlights (4 colors, persisted, listed in Saved)
- [ ] Bookmarks (per page, persisted)
- [ ] Notes affordance

## Phase 5 — Streak & stats
- [ ] Track reading sessions → day streak, minutes/pages, books finished, heatmap from real data

## Phase 6 — Polish
- [ ] Empty states, delete book (file + metadata), open-from-other-apps (share intent), reduced-motion, icons/splash

---

## Open notes
- Reflow is great for prose, poor for textbooks/diagrams → consider a "view original page" fallback in Phase 3.
- Covers: generated gradient now; possibly real first-page thumbnails later.
