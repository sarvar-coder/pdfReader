import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ember/models/book.dart';
import 'package:ember/models/bookmark.dart';
import 'package:ember/models/highlight.dart';
import 'package:ember/models/reading_session.dart';

/// Owns Hive initialization and the open boxes. A single instance is created in
/// `main()` (before `runApp`) and handed to the provider layer.
class StorageService {
  StorageService._();

  static const _booksBox = 'books';
  static const _highlightsBox = 'highlights';
  static const _bookmarksBox = 'bookmarks';
  static const _sessionsBox = 'sessions';
  static const _prefsBox = 'prefs';

  late final Box<Book> books;
  late final Box<Highlight> highlights;
  late final Box<Bookmark> bookmarks;
  late final Box<ReadingSession> sessions;

  /// Small key/value box for persisted reader settings.
  late final Box prefs;

  /// Directory under which PDF files are stored (`<docs>/books/`).
  late final String _booksDir;

  /// Initializes Hive, registers adapters, and opens all boxes.
  static Future<StorageService> init() async {
    final service = StorageService._();

    await Hive.initFlutter();
    Hive
      ..registerAdapter(BookAdapter())
      ..registerAdapter(HighlightAdapter())
      ..registerAdapter(BookmarkAdapter())
      ..registerAdapter(ReadingSessionAdapter());

    service.books = await Hive.openBox<Book>(_booksBox);
    service.highlights = await Hive.openBox<Highlight>(_highlightsBox);
    service.bookmarks = await Hive.openBox<Bookmark>(_bookmarksBox);
    service.sessions = await Hive.openBox<ReadingSession>(_sessionsBox);
    service.prefs = await Hive.openBox(_prefsBox);

    final docs = await getApplicationDocumentsDirectory();
    service._booksDir = '${docs.path}/books';

    return service;
  }

  /// On-disk path for a book's PDF.
  String pdfPathFor(String bookId) => '$_booksDir/$bookId.pdf';

  /// Whether a book's PDF file exists on disk.
  bool pdfExistsFor(String bookId) => File(pdfPathFor(bookId)).existsSync();

  /// Copies a picked PDF into app storage as `<docs>/books/<bookId>.pdf`,
  /// creating the books directory if needed. Returns the destination path.
  Future<String> importPdfFile(String sourcePath, String bookId) async {
    final dir = Directory(_booksDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final dest = pdfPathFor(bookId);
    await File(sourcePath).copy(dest);
    return dest;
  }

  /// Deletes a book's PDF file if present (used when removing a book).
  Future<void> deletePdfFor(String bookId) async {
    final file = File(pdfPathFor(bookId));
    if (await file.exists()) {
      await file.delete();
    }
  }
}
