import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ember/models/book.dart';
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

  /// Updates the saved reading position for a book.
  Future<void> updateProgress(String id, int currentPage) async {
    final box = ref.read(storageServiceProvider).books;
    final book = box.get(id);
    if (book == null) return;
    await box.put(id, book.copyWith(currentPage: currentPage));
    state = box.values.toList(growable: false);
  }

  /// Removes a book from the library.
  Future<void> remove(String id) async {
    await ref.read(storageServiceProvider).books.delete(id);
    state = ref.read(storageServiceProvider).books.values.toList(growable: false);
  }
}

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
