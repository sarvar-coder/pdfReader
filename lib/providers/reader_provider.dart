import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ember/models/book.dart';
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

/// On-disk PDF path for the open book, or null for seeded books without a file.
/// Kept separate from [currentBookProvider] so saving the scroll position (which
/// produces a new [Book] instance with the same id) does not re-run extraction.
final currentPdfPathProvider = Provider<String?>((ref) {
  final book = ref.watch(currentBookProvider);
  if (book == null) return null;
  final storage = ref.watch(storageServiceProvider);
  return storage.pdfExistsFor(book.id) ? storage.pdfPathFor(book.id) : null;
});

/// Extracted text for the open book. Returns null when the book has no PDF on
/// disk (the seeded demo books), so the Reader falls back to sample prose.
final readerContentProvider = FutureProvider.autoDispose<PdfContent?>((ref) async {
  final path = ref.watch(currentPdfPathProvider);
  if (path == null) return null;
  return ref.watch(pdfServiceProvider).extract(path);
});
