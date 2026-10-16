import 'dart:convert';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ember/models/book.dart';
import 'package:ember/models/bookmark.dart';
import 'package:ember/models/chapter.dart';
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

  /// On-disk path for a book's rendered cover thumbnail (PDF page 1 as PNG).
  /// Versioned like [textPathFor]: `v2` replaced covers rendered cropped.
  String coverPathFor(String bookId) => '$_booksDir/$bookId.v2.png';

  /// Whether a book's cover thumbnail has been rendered to disk yet.
  bool coverExistsFor(String bookId) => File(coverPathFor(bookId)).existsSync();

  /// On-disk path for a book's cached extracted text.
  ///
  /// The `v3` names the extraction that produced it. Bumping the suffix is how
  /// the cache is invalidated: text written by an older, worse extractor is
  /// simply never looked up again, and the next open re-extracts.
  String textPathFor(String bookId) => '$_booksDir/$bookId.v3.txt';

  /// Files written by superseded versions (text, chapters, covers), swept when
  /// a book is deleted so they do not outlive it.
  List<String> _legacyPathsFor(String bookId) => [
        '$_booksDir/$bookId.txt',
        '$_booksDir/$bookId.v2.txt',
        '$_booksDir/$bookId.toc.json',
        '$_booksDir/$bookId.png',
      ];

  /// Cached extracted text for a book, or `null` when no cache exists yet.
  /// An existing-but-empty file is a valid hit (a scanned/text-free PDF), so
  /// the miss check is file existence, not string emptiness.
  // ponytail: keyed by bookId, never invalidated within a version — PDFs are
  // copied once at import and never rewritten.
  Future<String?> readTextCache(String bookId) async {
    final file = File(textPathFor(bookId));
    if (!file.existsSync()) return null;
    return file.readAsString();
  }

  /// Persists extracted text so future opens skip re-parsing the PDF.
  Future<void> writeTextCache(String bookId, String text) =>
      File(textPathFor(bookId)).writeAsString(text);

  /// On-disk path for a book's chapter list (its table of contents).
  /// Versioned with [textPathFor]: heading-derived chapters change with it.
  String tocPathFor(String bookId) => '$_booksDir/$bookId.v3.toc.json';

  /// A book's chapters, or `null` when none have been derived yet. As with the
  /// text cache, an existing-but-empty list is a valid hit — plenty of PDFs
  /// declare no outline and have no detectable headings.
  Future<List<Chapter>?> readToc(String bookId) async {
    final file = File(tocPathFor(bookId));
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(await file.readAsString()) as List<dynamic>;
      return [
        for (final entry in json)
          Chapter.fromJson(entry as Map<String, dynamic>),
      ];
    } catch (_) {
      return null; // corrupt sidecar — treat as a miss and rebuild
    }
  }

  /// Persists a book's chapters so future opens skip re-parsing the PDF.
  Future<void> writeToc(String bookId, List<Chapter> chapters) => File(
        tocPathFor(bookId),
      ).writeAsString(jsonEncode([for (final c in chapters) c.toJson()]));

  /// On-disk path for a book's notebook (the reader's own written notes).
  String notePathFor(String bookId) => '$_booksDir/$bookId.note.txt';

  /// A book's notebook, or `''` when nothing has been written yet.
  Future<String> readNote(String bookId) async {
    final file = File(notePathFor(bookId));
    if (!file.existsSync()) return '';
    return file.readAsString();
  }

  /// Persists a book's notebook, creating the books directory if the book was
  /// never imported through [importPdfFile] (e.g. a shared-in PDF).
  Future<void> writeNote(String bookId, String text) async {
    final dir = Directory(_booksDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await File(notePathFor(bookId)).writeAsString(text);
  }

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

  /// Deletes every file derived from a book's id — PDF, text caches (current
  /// and superseded), chapters, cover and notebook (used when removing a book).
  Future<void> deletePdfFor(String bookId) async {
    for (final file in [
      File(pdfPathFor(bookId)),
      File(textPathFor(bookId)),
      for (final path in _legacyPathsFor(bookId)) File(path),
      File(tocPathFor(bookId)),
      File(coverPathFor(bookId)),
      File(notePathFor(bookId)),
    ]) {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
