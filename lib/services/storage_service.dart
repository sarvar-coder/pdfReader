import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ember/features/library/dummy_data.dart';
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

  late final Box<Book> books;
  late final Box<Highlight> highlights;
  late final Box<Bookmark> bookmarks;
  late final Box<ReadingSession> sessions;

  /// Directory under which PDF files are stored (`<docs>/books/`).
  late final String _booksDir;

  /// Initializes Hive, registers adapters, opens all boxes, and seeds the
  /// sample library on first launch.
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

    final docs = await getApplicationDocumentsDirectory();
    service._booksDir = '${docs.path}/books';

    if (service.books.isEmpty) {
      await service._seedFromDummyData();
    }

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

  /// Seeds Hive from [DummyData] so Phase 2 has real, persisted content to show
  /// before PDF import exists. Runs once (when the books box is empty).
  Future<void> _seedFromDummyData() async {
    const overstoryId = 'overstory';

    final continueBook = DummyData.continueReading;
    final seededBooks = <Book>[
      Book(
        id: overstoryId,
        title: continueBook.title,
        author: continueBook.author,
        currentPage: continueBook.currentPage,
        totalPages: continueBook.totalPages,
        gradientColors:
            continueBook.gradient.map((c) => c.toARGB32()).toList(),
        chapter: continueBook.chapter,
      ),
      for (var i = 0; i < DummyData.shelf.length; i++)
        Book(
          id: 'seed-$i',
          title: DummyData.shelf[i].title,
          author: DummyData.shelf[i].author,
          currentPage: DummyData.shelf[i].currentPage,
          totalPages: DummyData.shelf[i].totalPages,
          gradientColors:
              DummyData.shelf[i].gradient.map((c) => c.toARGB32()).toList(),
          chapter: DummyData.shelf[i].chapter,
        ),
    ];
    await books.putAll({for (final b in seededBooks) b.id: b});

    final now = DateTime.now();
    final seededHighlights = <Highlight>[
      for (var i = 0; i < DummyData.highlights.length; i++)
        Highlight(
          id: 'hl-$i',
          bookId: overstoryId,
          quote: DummyData.highlights[i].quote,
          colorValue: DummyData.highlights[i].color.toARGB32(),
          page: DummyData.highlights[i].page,
          chapter: DummyData.highlights[i].chapter,
          // Stagger created dates so the "age" labels vary like the mockup.
          createdAt: now.subtract(Duration(days: i == 2 ? 5 : 2)),
        ),
    ];
    await highlights.putAll({for (final h in seededHighlights) h.id: h});

    final seededBookmarks = <Bookmark>[
      for (var i = 0; i < DummyData.bookmarks.length; i++)
        Bookmark(
          id: 'bm-$i',
          bookId: overstoryId,
          page: DummyData.bookmarks[i].page,
          chapter: DummyData.bookmarks[i].chapter,
          note: DummyData.bookmarks[i].note,
        ),
    ];
    await bookmarks.putAll({for (final b in seededBookmarks) b.id: b});
  }
}
