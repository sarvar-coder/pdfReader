import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Result of importing a PDF. [text] is empty when the PDF has no extractable
/// text (e.g. a scanned/image-only book that would need OCR).
class ExtractedPdf {
  final String text;
  final int pageCount;

  const ExtractedPdf({required this.text, required this.pageCount});

  bool get hasText => text.trim().isNotEmpty;
}

class PdfService {
  /// Extracts all text from the PDF at [path]. Syncfusion is pure Dart (no
  /// `dart:ui`), so the heavy parsing runs in a background isolate via
  /// [compute] — keeping the UI thread free while importing large books.
  static Future<ExtractedPdf> extract(String path) {
    return compute(_extractInIsolate, path);
  }
}

/// Runs on a background isolate. Must be a top-level function for [compute].
ExtractedPdf _extractInIsolate(String path) {
  final bytes = File(path).readAsBytesSync();
  final document = PdfDocument(inputBytes: bytes);
  try {
    final pageCount = document.pages.count;
    final buffer = StringBuffer();
    for (var i = 0; i < pageCount; i++) {
      final pageText = PdfTextExtractor(document)
          .extractText(startPageIndex: i, endPageIndex: i);
      buffer.writeln(pageText.trim());
      buffer.writeln();
    }
    return ExtractedPdf(text: buffer.toString(), pageCount: pageCount);
  } finally {
    document.dispose();
  }
}
