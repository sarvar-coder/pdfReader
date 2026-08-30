# CLAUDE.md

Guidance for Claude Code working in this repository.

## Project

**Ember** — a personal, single-user Flutter reading app (iOS/Android). It imports PDFs, extracts their
text, and **reflows** it into swipeable, screen-sized pages the user can restyle (theme, font size,
typeface, line spacing). Original PDF layout/images are intentionally discarded — prose only.

Domain vocabulary: `CONTEXT.md`.

## Tests

```bash
flutter test test/reflow_test.dart test/note_page_test.dart test/note_screen_test.dart
```

Always name the three files. Bare `flutter test` also runs `test/gen_icon_test.dart`, which is a
rasterizer rather than a test — it rewrites `assets/icon/*.png`.

## Architecture

`main.dart` builds `StorageService` **before** `runApp` and injects it via a `ProviderScope` override,
providers read it, screens watch providers. `services/` never imports `providers/`.

```
services/   storage_service.dart (Hive boxes + file paths)  pdf_service.dart (both PDF libs)
providers/  library, reader, highlights, bookmarks, sessions, stats
features/   library/  reader/  notes/  stats/
widgets/    app_shell.dart (2-tab frosted nav) + shared widgets
theme/      app_colors.dart, app_theme.dart
```

`AppShell` holds two tabs, Library and Stats. Reader and notes are full-screen routes pushed on top,
not tabs.

Per-file invariants live at their code site: read the doc comments in `reflow.dart`, `note_screen.dart`,
`pdf_service.dart` and `storage_service.dart` before editing those files.

## Packaging

- Features under `lib/features/` never import each other. Pass callbacks up (e.g. `onQuoteTap`) and let
  the pushing screen own navigation.
- Shared UI in `lib/widgets/`, data access in `lib/services/`, models in `lib/models/`. No grab-bag
  `common/` — anything shared gets a name from its domain.
- This is the single-package form of a package-per-feature layout. Keep the boundaries clean so a split
  into real packages stays mechanical.

## Conventions

- Colors come from `theme/app_colors.dart`; reader themes and typefaces from
  `features/reader/reader_settings.dart`. No raw hex in widgets.
- Fonts are Google Fonts at runtime (Fraunces / Inter / Spectral) — no bundled font assets.
- Imports inside `lib/` are absolute `package:ember/...`; only `main.dart` and `app.dart` use relative.
- Mark deliberate shortcuts with `// ponytail:` naming the ceiling and the upgrade path.
