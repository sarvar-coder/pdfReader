import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ember/features/reader/reader_settings.dart';
import 'package:ember/models/book.dart';
import 'package:ember/models/chapter.dart';
import 'package:ember/providers/library_provider.dart';
import 'package:ember/providers/pdf_provider.dart';
import 'package:ember/providers/storage_provider.dart';
import 'package:ember/services/pdf_service.dart';

/// Holds the id of the book currently open in the Reader. Set when a book is
/// tapped in the Library or Saved screens; null falls back to "continue
/// reading" so the Reader tab still works on its own.
class CurrentBookId extends Notifier<String?> {
  @override
  String? build() => null;

  void open(String id) => state = id;
  void close() => state = null;
}

final currentBookIdProvider =
    NotifierProvider<CurrentBookId, String?>(CurrentBookId.new);

/// A one-shot scroll target (0.0–1.0) used to open the Reader at a specific
/// bookmark/highlight. The Reader consumes and clears it after jumping.
class PendingJump extends Notifier<double?> {
  @override
  double? build() => null;

  void to(double fraction) => state = fraction.clamp(0.0, 1.0);
  void clear() => state = null;
}

final pendingJumpProvider =
    NotifierProvider<PendingJump, double?>(PendingJump.new);

/// The resolved [Book] open in the Reader (or the continue-reading book).
final currentBookProvider = Provider<Book?>((ref) {
  final id = ref.watch(currentBookIdProvider);
  if (id == null) return ref.watch(continueReadingProvider);
  final books = ref.watch(libraryProvider);
  for (final b in books) {
    if (b.id == id) return b;
  }
  return ref.watch(continueReadingProvider);
});

/// On-disk PDF path for the open book, or null when the file is missing.
/// Kept separate from [currentBookProvider] so saving the scroll position (which
/// produces a new [Book] instance with the same id) does not re-run extraction.
final currentPdfPathProvider = Provider<String?>((ref) {
  final book = ref.watch(currentBookProvider);
  if (book == null) return null;
  final storage = ref.watch(storageServiceProvider);
  return storage.pdfExistsFor(book.id) ? storage.pdfPathFor(book.id) : null;
});

/// Extracted text for the open book. Returns null when the book has no PDF on
/// disk, so the Reader can show a missing-file notice.
final readerContentProvider = FutureProvider.autoDispose<PdfContent?>((ref) async {
  // Watch the path (a stable String) — not the Book — so saving the scroll
  // position (which mints a new Book instance) does not re-run extraction and
  // flash the reader. `ref.read` the book only for id/totalPages (no subscription).
  final path = ref.watch(currentPdfPathProvider);
  if (path == null) return null;
  final book = ref.read(currentBookProvider)!; // path != null ⇒ book exists
  final storage = ref.watch(storageServiceProvider);

  // Cache hit: skip PDF parsing entirely. `fullText` is all the reader uses.
  final cached = await storage.readTextCache(book.id);
  if (cached != null) {
    return PdfContent(pageCount: book.totalPages, pages: [cached]);
  }
  // Miss (opened before the import prefetch finished): parse once, then cache
  // so every reopen is an instant file read.
  final content = await ref.watch(pdfServiceProvider).extract(path);
  await storage.writeTextCache(book.id, content.fullText);
  return content;
});

/// The open book's chapters, for the contents sheet.
///
/// Backfills on first read: a book imported before chapters existed has no
/// sidecar, so it is derived and written once, exactly as the text cache does
/// on a miss.
final chaptersProvider = FutureProvider.autoDispose<List<Chapter>>((ref) async {
  final path = ref.watch(currentPdfPathProvider);
  if (path == null) return const [];
  final book = ref.read(currentBookProvider)!; // path != null ⇒ book exists
  final storage = ref.watch(storageServiceProvider);

  final cached = await storage.readToc(book.id);
  if (cached != null) return cached;
  final chapters =
      await buildChapters(ref.watch(pdfServiceProvider), path, null);
  await storage.writeToc(book.id, chapters);
  return chapters;
});

/// Reader settings persisted in the `prefs` Hive box, so the chosen theme, font
/// size, typeface and line spacing survive relaunches.
class ReaderSettingsNotifier extends Notifier<ReaderSettings> {
  static const _themeKey = 'rs_theme';
  static const _fontKey = 'rs_font';
  static const _faceKey = 'rs_face';
  static const _spacingKey = 'rs_spacing';

  @override
  ReaderSettings build() {
    final box = ref.watch(storageServiceProvider).prefs;
    const d = ReaderSettings();
    final themeIdx = box.get(_themeKey, defaultValue: d.theme.index) as int;
    final faceIdx = box.get(_faceKey, defaultValue: d.typeface.index) as int;
    return ReaderSettings(
      theme: ReaderTheme.values[themeIdx.clamp(0, ReaderTheme.values.length - 1)],
      fontSize: (box.get(_fontKey, defaultValue: d.fontSize) as num).toDouble(),
      typeface:
          ReaderTypeface.values[faceIdx.clamp(0, ReaderTypeface.values.length - 1)],
      lineSpacing:
          (box.get(_spacingKey, defaultValue: d.lineSpacing) as num).toDouble(),
    );
  }

  Future<void> update(ReaderSettings s) async {
    state = s;
    final box = ref.read(storageServiceProvider).prefs;
    await box.putAll({
      _themeKey: s.theme.index,
      _fontKey: s.fontSize,
      _faceKey: s.typeface.index,
      _spacingKey: s.lineSpacing,
    });
  }
}

final readerSettingsProvider =
    NotifierProvider<ReaderSettingsNotifier, ReaderSettings>(
  ReaderSettingsNotifier.new,
);
