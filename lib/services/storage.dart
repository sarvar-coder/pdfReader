import 'package:hive_flutter/hive_flutter.dart';

import '../models/book.dart';
import '../models/reading_theme.dart';

/// Thin wrapper over Hive: one box holds all books (as plain maps), another
/// holds reading preferences (theme, font size) shared across books.
class Storage {
  static const _booksBox = 'books';
  static const _settingsBox = 'settings';

  late final Box _books;
  late final Box _settings;

  Future<void> init() async {
    await Hive.initFlutter();
    _books = await Hive.openBox(_booksBox);
    _settings = await Hive.openBox(_settingsBox);
  }

  // --- Books ---

  List<Book> getBooks() {
    final books = _books.values
        .map((v) => Book.fromMap(Map<dynamic, dynamic>.from(v as Map)))
        .toList();
    books.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return books;
  }

  Future<void> saveBook(Book book) => _books.put(book.id, book.toMap());

  Future<void> deleteBook(String id) => _books.delete(id);

  // --- Reading preferences ---

  ReadingTheme get readingTheme {
    final i = _settings.get('readingTheme', defaultValue: 0) as int;
    return ReadingTheme.values[i.clamp(0, ReadingTheme.values.length - 1)];
  }

  set readingTheme(ReadingTheme theme) =>
      _settings.put('readingTheme', theme.index);

  double get fontSize =>
      (_settings.get('fontSize', defaultValue: 18.0) as num).toDouble();

  set fontSize(double size) => _settings.put('fontSize', size);
}
