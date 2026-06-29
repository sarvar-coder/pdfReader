# Ember Reader — Detailed Steps

Follow these in order. Each step is a small, do-able action. When you reach a file
and want the actual code, ask: "give me the code for `<file>`". I won't write code
until you ask.

Legend: 🖥 = run in terminal · 📝 = create/edit a file · ✅ = checkpoint to verify

---

## PHASE 0 — Project setup

### 0.1 — Scaffold the Flutter project
🖥 From inside `/Users/boltaboyevsarvarbek/pdfReader`:
```
flutter create --org com.sarvarbek --project-name ember .
```
- `.` creates the project in the current folder (keeps your `.git`, `PLAN.md`, `STEPS.md`).
- If it complains the folder isn't empty, that's fine — it merges.

✅ `flutter run` shows the default counter app on your device/emulator.

### 0.2 — Pick your run target
🖥 `flutter devices` — note your phone or emulator id.
- Android emulator: open from Android Studio → Device Manager, or `flutter emulators --launch <id>`.
- iOS simulator (Mac): `open -a Simulator`.

✅ Your device appears in `flutter devices`.

### 0.3 — Add the starter packages
🖥
```
flutter pub add flutter_riverpod google_fonts
```
✅ `pubspec.yaml` lists both; `flutter pub get` ran clean.

### 0.4 — Clean out the boilerplate
📝 Delete the default counter code in `lib/main.dart`. We'll rebuild it.
📝 (Optional) delete `test/widget_test.dart` for now so `flutter analyze`/tests don't fail on the old counter test.

### 0.5 — Create the folder structure
🖥 Make the empty folders so files have a home:
```
mkdir -p lib/theme lib/models lib/providers lib/services \
  lib/features/library/widgets lib/features/reader/widgets \
  lib/features/saved/widgets lib/features/stats/widgets lib/widgets
```

### 0.6 — Theme files (ask me for code)
📝 `lib/theme/app_colors.dart` — every color from PLAN.md as named constants
  (paper, card, ink, ember, etc.).
📝 `lib/theme/app_theme.dart` — a `ThemeData` (light) using the palette as the color
  scheme, and a text theme wiring **Fraunces / Inter / Spectral** via `google_fonts`.

### 0.7 — App entry (ask me for code)
📝 `lib/main.dart` — `runApp(ProviderScope(child: EmberApp()))`.
📝 `lib/app.dart` — `EmberApp` = `MaterialApp` using your theme, home = a temporary
  blank `Scaffold` painted in `paper` with a centered "Ember" title.

✅ **Checkpoint:** app runs, shows a warm paper background with "Ember" in Fraunces.
   Commit: `git add -A && git commit -m "Phase 0: setup + theme"`.

---

## PHASE 1 — Build the design (dummy data, no PDF logic yet)

Build screens to match the mockup. Use hardcoded sample data so everything is
visible and clickable. We make it real in later phases.

### 1.1 — Dummy data (ask me for code)
📝 `lib/features/library/dummy_data.dart` (or similar) — a few fake books
  (title, author, page X of Y, progress %, gradient colors), a few fake highlights
  and bookmarks. Lets every screen render.

### 1.2 — App shell + bottom nav
📝 `lib/widgets/app_shell.dart` — a `Scaffold` holding the current screen + a bottom
  nav bar with 4 items: Library · Reading · Saved · Stats (frosted look, ember-colored
  selected item). Keep which tab is selected in local state for now.
✅ Tapping nav items switches between 4 placeholder screens.

### 1.3 — Library screen
Build top-to-bottom, one widget at a time (each in `features/library/widgets/`):
1. 📝 Header: eyebrow "Good evening, reader", big "Your shelf", subtitle.
2. 📝 `streak_card.dart` — dark gradient card, animated flickering ember circle,
   "12 days in a row", a row of week dots (some lit, today outlined). Tapping it
   navigates to Stats.
3. 📝 `continue_card.dart` — book cover + "Page X of Y", title, author, progress bar,
   "42% · 18 min left", "Tap to open ›". Tapping opens Reader.
4. 📝 `book_cover.dart` (shared) — gradient rectangle (2:3) with a spine line and the
   centered title. Reused on the shelf and continue card.
5. 📝 `shelf_grid.dart` — 3-column grid of covers + a dashed "Add a PDF" tile (just
   shows a toast/snackbar for now).
✅ Library matches the mockup and scrolls.

### 1.4 — Reader screen (static text)
📝 `features/reader/reader_screen.dart` plus widgets:
1. 📝 Top chrome: back, centered title "The Overstory · Chapter 6", bookmark icon, "Aa".
2. 📝 Page body: a `SingleChildScrollView` of sample paragraphs in Spectral, with one
   sentence wrapped in a highlight style.
3. 📝 Bottom chrome: thin progress bar + "Page 184 of 502 · 18 min left".
4. 📝 Tap-the-page → hide both top & bottom chrome (animate opacity); tap again to show.
5. 📝 `settings_sheet.dart` — bottom sheet opened by "Aa": Theme chips (Paper/Sepia/Night),
   font-size stepper (A− / value / A+), typeface chips (Spectral/Fraunces/Inter),
   line-spacing slider. Wire these to **live-update the sample text** (local state).
6. 📝 `selection_toolbar.dart` — a small dark floating bar with 4 color swatches
   (shown on a long-press/selection for now; just visual).
✅ Reader looks right; Aa sheet changes the sample text's size/font/spacing/theme live.

### 1.5 — Saved screen
📝 `features/saved/saved_screen.dart` — header, a two-tab switch (Highlights | Bookmarks):
- 📝 `highlight_card.dart` — colored left stripe, quote in Spectral, source line (page · chapter · time).
- 📝 `bookmark_tile.dart` — page-number badge + chapter + short description.
✅ Tabs switch; sample cards render.

### 1.6 — Stats screen
📝 `features/stats/stats_screen.dart`:
- 📝 Big animated ember + "12" + "day streak · longest yet was 23".
- 📝 `stat_grid.dart` — 2×2 cards (38 min today, 214 pages this week, 9 finished, 31 hrs this month).
- 📝 `heatmap.dart` — a 13-column grid of cells with 5 intensity levels (random fill for now).
✅ Stats matches the mockup.

✅ **Phase 1 checkpoint:** all 4 screens look like the design and are navigable on a
   real device. Commit: `git commit -am "Phase 1: full UI with dummy data"`.

---

## PHASE 2 — Data layer (make it real)
1. 🖥 `flutter pub add hive hive_flutter path_provider` (+ `flutter pub add -d hive_generator build_runner` if using codegen).
2. 📝 Models: `book.dart`, `highlight.dart`, `bookmark.dart`, `reading_session.dart`.
3. 📝 `services/storage_service.dart` — init Hive, open boxes, helper to derive a PDF's
   path from its id (`<docs>/books/<id>.pdf`).
4. 📝 `providers/library_provider.dart` etc. — Riverpod providers exposing the lists.
5. 📝 Swap each screen from dummy data to providers.
✅ Data survives an app restart.

## PHASE 3 — PDF import + reflow reader
1. 🖥 `flutter pub add file_picker`.
2. 📝 Wire "Add a PDF" → pick file → copy into app storage → create a Book record.
3. Decide the text-extraction package (ask me to compare options) and add it.
4. 📝 `services/pdf_service.dart` — extract text (and page count) from a saved PDF.
5. 📝 Replace the Reader's sample text with the real extracted text; apply the live
   font/typeface/spacing/theme settings to it.
6. 📝 Save & restore the last read position per book (resume).
✅ Import a real PDF, read it, close, reopen at the same spot.

## PHASE 4 — Highlights & bookmarks (real)
1. 📝 Selecting text → choose a color → save a Highlight; render it in the reader and Saved tab.
2. 📝 Bookmark button saves the current page; show in Saved tab; tap to jump there.
✅ Highlights/bookmarks persist and navigate correctly.

## PHASE 5 — Streak & stats (real)
1. 📝 Record a ReadingSession (start/stop, pages, minutes) while reading.
2. 📝 Compute day streak, today's minutes, weekly pages, books finished, heatmap from sessions.
✅ Numbers reflect actual reading.

## PHASE 6 — Polish
- Empty states · delete book (file + metadata) · open-PDF-from-other-apps (share intent) ·
  reduced-motion for the ember animation · app icon & splash.

---

### How we'll work
- You build; I supply code per file when you ask ("code for `streak_card.dart`").
- Hit a checkpoint → commit, then move on.
- Stuck or an error? Paste it and I'll debug.
