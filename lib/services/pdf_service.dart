import 'dart:io';
import 'dart:isolate';

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Extracted text content of a PDF, one entry per page.
class PdfContent {
  const PdfContent({required this.pageCount, required this.pages});

  final int pageCount;

  /// Plain text per page; `pages.length == pageCount`.
  final List<String> pages;

  /// All pages joined, for the reflow reader.
  String get fullText => pages.join('\n\n');
}

/// Reads PDFs from disk using `syncfusion_flutter_pdf`. The reader reflows the
/// extracted text, so layout/images are dropped (acceptable for prose).
///
/// Parsing is CPU-bound and runs in a background isolate ([Isolate.run]) so it
/// never blocks the UI thread — syncfusion is pure Dart, so it works off the
/// main isolate. Without this, large files trigger an Android ANR.
class PdfService {
  const PdfService();

  /// Page count only — parsed off the main isolate at import time.
  Future<int> pageCount(String path) => Isolate.run(() {
        final document =
            PdfDocument(inputBytes: File(path).readAsBytesSync());
        try {
          return document.pages.count;
        } finally {
          document.dispose();
        }
      });

  /// Full per-page text extraction, used when opening the reader.
  Future<PdfContent> extract(String path) => Isolate.run(() {
        final document =
            PdfDocument(inputBytes: File(path).readAsBytesSync());
        try {
          final count = document.pages.count;
          final extractor = PdfTextExtractor(document);
          final pages = <String>[
            for (var i = 0; i < count; i++)
              extractor.extractText(startPageIndex: i, endPageIndex: i),
          ];
          return PdfContent(pageCount: count, pages: pages);
        } finally {
          document.dispose();
        }
      });
}
