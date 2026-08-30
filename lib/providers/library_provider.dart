import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ember/features/reader/reflow.dart';
import 'package:ember/models/book.dart';
import 'package:ember/models/chapter.dart';
import 'package:ember/providers/pdf_provider.dart';
import 'package:ember/providers/storage_provider.dart';
import 'package:ember/services/pdf_service.dart';

/// The library: all books, backed by the Hive `books` box. Mutations write
/// through to Hive and refresh the in-memory list so the UI rebuilds.
class LibraryNotifier extends Notifier<List<Book>> {
  bool _coversChecked = false;

  @override
  List<Book> build() {
    final box = ref.watch(storageServiceProvider).books;
    final books = box.values.toList(growable: false);
    // One-time backfill of covers for books imported before covers existed.
    if (!_coversChecked) {
      _coversChecked = true;
      Future(() => _ensureCovers());
    }
    return books;
  }

  /// Renders a cover thumbnail for any book that lacks one, then refreshes the
  /// list so the grid picks up the new PNGs. Best-effort and sequential — cover
  /// rendering is not worth blocking or racing on.
  Future<void> _ensureCovers() async {
    final storage = ref.read(storageServiceProvider);
    final service = ref.read(pdfServiceProvider);
    var changed = false;
    for (final book in storage.books.values) {
      if (storage.coverExistsFor(book.id)) continue;
      if (!storage.pdfExistsFor(book.id)) continue;
      try {
        await service.renderCover(
          storage.pdfPathFor(book.id),
          storage.coverPathFor(book.id),
        );
        changed = true;
      } catch (_) {/* keep the gradient fallback */}
    }
    if (changed) {
      state = storage.books.values.toList(growable: false);
    }
  }

  /// Adds (or replaces) a book and persists it.
  Future<void> upsert(Book book) async {
    await ref.read(storageServiceProvider).books.put(book.id, book);
    state = ref.read(storageServiceProvider).books.values.toList(growable: false);
  }

  /// Imports a picked PDF: copies the file into app storage and creates a new
  /// [Book] record. Page count stays 0 until the PDF is parsed (step 3.4).
  Future<Book> importPdf({
    required String sourcePath,
    required String title,
    String author = 'Unknown',
  }) async {
    final storage = ref.read(storageServiceProvider);
    final id = 'pdf-${DateTime.now().microsecondsSinceEpoch}';
    final dest = await storage.importPdfFile(sourcePath, id);

    // Best-effort page count; a parse failure still adds the book (pages = 0).
    final service = ref.read(pdfServiceProvider);
    var pageCount = 0;
    try {
      pageCount = await service.pageCount(dest);
    } catch (_) {
      pageCount = 0;
    }

    // Prefetch the full text off the UI thread and cache it, so the first open
    // is instant. Detached (not awaited) so import returns immediately; if the
    // user opens before it finishes, the reader extracts on demand instead.
    // ponytail: two isolate opens (count now, text in background) — both off-UI,
    // import never blocks.
    unawaited(() async {
      try {
        final content = await service.extract(dest);
        await storage.writeTextCache(id, content.fullText);
        await storage.writeToc(id, await buildChapters(service, dest, content));
      } catch (_) {/* first open will extract on demand */}
    }());

    final palette = _coverGradients[title.hashCode.abs() % _coverGradients.length];
    final book = Book(
      id: id,
      title: title,
      author: author,
      currentPage: 0,
      totalPages: pageCount,
      gradientColors: palette,
    );
    await storage.books.put(id, book);
    state = storage.books.values.toList(growable: false);

    // Render the real cover off the critical path; the tile shows the gradient
    // until this lands, then the state bump swaps in the image. Same detached
    // best-effort style as the text prefetch above.
    unawaited(() async {
      try {
        await service.renderCover(dest, storage.coverPathFor(id));
        state = storage.books.values.toList(growable: false);
      } catch (_) {/* gradient fallback stays */}
    }());
    return book;
  }

  /// Updates the saved reading position for a book.
  Future<void> updateProgress(String id, int currentPage) async {
    final box = ref.read(storageServiceProvider).books;
    final book = box.get(id);
    if (book == null) return;
    await box.put(id, book.copyWith(currentPage: currentPage));
    state = box.values.toList(growable: false);
  }

  /// Saves the reading position as a 0.0–1.0 [fraction] and derives the page
  /// number for display. Called as the user scrolls the reader.
  Future<void> updateReadingPosition(String id, double fraction) async {
    final box = ref.read(storageServiceProvider).books;
    final book = box.get(id);
    if (book == null) return;
    final f = fraction.clamp(0.0, 1.0);
    final page =
        book.totalPages == 0 ? book.currentPage : (f * book.totalPages).round();
    await box.put(id, book.copyWith(readingFraction: f, currentPage: page));
    state = box.values.toList(growable: false);
  }

  /// Removes a book from the library, deleting its PDF file too.
  Future<void> remove(String id) async {
    final storage = ref.read(storageServiceProvider);
    await storage.deletePdfFor(id);
    await storage.books.delete(id);
    state = storage.books.values.toList(growable: false);
  }
}

/// A book's chapters: the PDF's own outline when it declares one, otherwise the
/// headings the reflow classifier finds in the extracted text.
///
/// This lives in the provider layer, not in [PdfService], because the fallback
/// needs `toBlocks` from the reader feature and `services/` sits below features.
/// Pass [content] when the caller already has it; otherwise it is extracted
/// only if the fallback is actually reached.
Future<List<Chapter>> buildChapters(
  PdfService service,
  String pdfPath,
  PdfContent? content,
) async {
  final outline = await service.outline(pdfPath);
  if (outline.isNotEmpty) {
    return [
      for (final entry in outline)
        Chapter(title: entry.title, pageIndex: entry.pageIndex),
    ];
  }
  final text = content ?? await service.extract(pdfPath);
  return [
    for (var page = 0; page < text.pages.length; page++)
      for (final block in toBlocks(text.pages[page]))
        if (block.kind == BlockKind.title)
          Chapter(title: block.text.trim(), pageIndex: page),
  ];
}

/// Cover gradients (ARGB pairs) assigned to imported books by title hash, so each
/// gets a distinct warm/cool cover until real thumbnails arrive.
const List<List<int>> _coverGradients = [
  [0xFF3F5A3A, 0xFF7E8A5A],
  [0xFFBE4F1E, 0xFFDD7536],
  [0xFF1F3A52, 0xFF6BB4F0],
  [0xFF8A5A1E, 0xFFD6A24B],
  [0xFF4A4A6A, 0xFFA89C8A],
  [0xFFB23E5A, 0xFFF08AA6],
];

final libraryProvider =
    NotifierProvider<LibraryNotifier, List<Book>>(LibraryNotifier.new);

/// The book featured in the "Continue reading" card: the first in-progress book,
/// falling back to the first book on the shelf (or null when the library empty).
final continueReadingProvider = Provider<Book?>((ref) {
  final books = ref.watch(libraryProvider);
  if (books.isEmpty) return null;
  return books.firstWhere(
    (b) => b.inProgress,
    orElse: () => books.first,
  );
});

/// Books shown in the shelf grid: the whole library.
final shelfProvider = Provider<List<Book>>(
  (ref) => ref.watch(libraryProvider),
);

/// Count of books currently in progress (for the header subtitle).
final inProgressCountProvider = Provider<int>(
  (ref) => ref.watch(libraryProvider).where((b) => b.inProgress).length,
);
