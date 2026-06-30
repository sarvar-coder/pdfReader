import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ember/models/book.dart';
import 'package:ember/providers/pdf_provider.dart';
import 'package:ember/providers/storage_provider.dart';

/// The library: all books, backed by the Hive `books` box. Mutations write
/// through to Hive and refresh the in-memory list so the UI rebuilds.
class LibraryNotifier extends Notifier<List<Book>> {
  @override
  List<Book> build() {
    final box = ref.watch(storageServiceProvider).books;
    return box.values.toList(growable: false);
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
    var pageCount = 0;
    try {
      pageCount = await ref.read(pdfServiceProvider).pageCount(dest);
    } catch (_) {
      pageCount = 0;
    }

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

/// Books shown in the shelf grid (everything except the featured book).
final shelfProvider = Provider<List<Book>>((ref) {
  final books = ref.watch(libraryProvider);
  final featured = ref.watch(continueReadingProvider);
  return books.where((b) => b.id != featured?.id).toList(growable: false);
});

/// Count of books currently in progress (for the header subtitle).
final inProgressCountProvider = Provider<int>(
  (ref) => ref.watch(libraryProvider).where((b) => b.inProgress).length,
);
