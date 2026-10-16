import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:syncfusion_flutter_pdf/pdf.dart';
// Prefixed: pdfrx also exports `PdfDocument`/`PdfPage`, clashing with syncfusion.
import 'package:pdfrx/pdfrx.dart' as pdfrx;

/// Extracted text content of a PDF, one entry per page.
class PdfContent {
  const PdfContent({required this.pageCount, required this.pages});

  final int pageCount;

  /// Reflow-ready text per page: blank-line separated paragraphs, holding the
  /// paragraphs that *begin* on that page. `pages.length == pageCount`.
  final List<String> pages;

  /// All pages joined, for the reflow reader.
  String get fullText => pages.join('\n\n');
}

/// One extracted line, reduced to what [reflowLines] needs. Deliberately a
/// plain record rather than syncfusion's `TextLine`, whose constructor is
/// private — the normalization can then be unit-tested without a real PDF.
typedef PdfLine = ({
  String text,
  double top,
  double left,
  double right,
  double fontSize,
  int pageIndex,
});

/// A chapter as the PDF itself declares it, before it becomes a `Chapter`.
typedef OutlineEntry = ({String title, int pageIndex});

/// What import needs from a PDF: its page count, and its declared title and
/// author when the metadata holds something usable (null otherwise).
typedef PdfInfo = ({int pageCount, String? title, String? author});

/// Reads PDFs from disk using `syncfusion_flutter_pdf`. The reader reflows the
/// extracted text, so layout/images are dropped (acceptable for prose).
///
/// Text comes from `extractTextLines`, never `extractText`: the flat extractor
/// glues runs that the PDF separated by position rather than by a space glyph
/// ("alreadyseen,thereare…" — 60 such runs on a sample of design-patterns-en.pdf
/// against 2 for the line extractor). Lines also carry the geometry
/// [reflowLines] needs to rebuild paragraphs and drop running heads.
///
/// Parsing is CPU-bound and runs in a background isolate ([Isolate.run]) so it
/// never blocks the UI thread — syncfusion is pure Dart, so it works off the
/// main isolate. Without this, large files trigger an Android ANR.
class PdfService {
  const PdfService();

  /// Page count and metadata — parsed off the main isolate at import time.
  Future<PdfInfo> info(String path) => Isolate.run(() {
        final document =
            PdfDocument(inputBytes: File(path).readAsBytesSync());
        try {
          final meta = document.documentInformation;
          return (
            pageCount: document.pages.count,
            title: _usableMeta(meta.title),
            author: _usableMeta(meta.author),
          );
        } finally {
          document.dispose();
        }
      });

  /// Below this many pages one isolate is fast enough; splitting costs an
  /// extra document load per worker.
  static const _parallelMinPages = 40;

  /// Full per-page text extraction, used when opening the reader.
  ///
  /// Line extraction dominates (tens of seconds for a 400-page book on a
  /// phone) and pages are independent, so the page range is split across
  /// several isolates. The reflow then runs once over every line: running-head
  /// detection needs the whole book.
  // ponytail: each worker loads the full document, so memory grows with the
  // worker count; capped at 4. Share one parse if large books ever OOM.
  Future<PdfContent> extract(String path) async {
    final count = await Isolate.run(() => _pageCount(path));
    final workers = count < _parallelMinPages
        ? 1
        : (Platform.numberOfProcessors ~/ 2).clamp(1, 4);
    final chunk = (count / workers).ceil();
    final parts = await Future.wait([
      for (var start = 0; start < count; start += chunk)
        Isolate.run(
          () => _extractLines(path, start, math.min(start + chunk, count) - 1),
        ),
    ]);
    final lines = [for (final part in parts) ...part];
    return Isolate.run(
      () => PdfContent(pageCount: count, pages: reflowLines(lines, count)),
    );
  }

  /// The PDF's own table of contents, flattened depth-first, or an empty list
  /// when the file declares none. Nesting is dropped — the reader shows one
  /// flat chapter list.
  Future<List<OutlineEntry>> outline(String path) => Isolate.run(() {
        final document =
            PdfDocument(inputBytes: File(path).readAsBytesSync());
        try {
          final entries = <OutlineEntry>[];
          _collectOutline(document, document.bookmarks, entries);
          return entries;
        } catch (_) {
          return const <OutlineEntry>[];
        } finally {
          document.dispose();
        }
      });

  /// Rendered cover width in pixels (~2x the grid cell); height follows the
  /// page's aspect ratio.
  static const _coverWidth = 300;

  /// Rasterizes page 1 of [pdfPath] to a PNG at [outPngPath] using pdfrx
  /// (syncfusion community can't render). Runs on the main isolate — pdfrx uses
  /// PDFium via FFI and cannot go through [Isolate.run].
  Future<void> renderCover(String pdfPath, String outPngPath) async {
    final doc = await pdfrx.PdfDocument.openFile(pdfPath);
    try {
      final page = doc.pages.first;
      final height = (_coverWidth * page.height / page.width).round();
      // fullWidth/fullHeight scale the whole page into the bitmap; without them
      // pdfrx renders at 72 dpi and crops a width x height window from it.
      final rendered = await page.render(
        width: _coverWidth,
        height: height,
        fullWidth: _coverWidth.toDouble(),
        fullHeight: height.toDouble(),
      );
      if (rendered == null) return;
      ui.Image? image;
      try {
        image = await rendered.createImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) return;
        await File(outPngPath).writeAsBytes(bytes.buffer.asUint8List());
      } finally {
        image?.dispose();
        rendered.dispose();
      }
    } finally {
      await doc.dispose();
    }
  }
}

/// A metadata field worth showing, or null for the empty, the generic and the
/// leaked file names ("Microsoft Word - draft3.docx") producers leave behind.
String? _usableMeta(String raw) {
  final value = raw.trim();
  if (value.length < 2) return null;
  if (RegExp(
    r'\.(pdf|docx?|indd|tex)$|^microsoft word|^untitled$',
    caseSensitive: false,
  ).hasMatch(value)) {
    return null;
  }
  return value;
}

/// A readable title from a file name stem, for PDFs whose metadata names none:
/// "31_10_2020_084952101_Essays_That_Will_Change" -> "Essays That Will Change".
///
/// Underscores always separate words; hyphens and dots only when the file name
/// has no spaces, since "Node.js" or "Data-Intensive" in a spaced name are real.
/// Pure digit runs (dates, upload ids), version tags and download-site tags
/// are dropped.
String cleanTitle(String stem) {
  var name = stem.replaceAll('_', ' ').trim();
  if (!stem.contains(' ')) name = name.replaceAll(RegExp(r'[-.]'), ' ');
  final words = [
    for (final word in name.split(RegExp(r'\s+')))
      if (!RegExp(
        r'^(\d{5,}|v\d+|pdf|compress|z-?lib\.?org|oceanofpdf\.com)$',
        caseSensitive: false,
      ).hasMatch(word))
        word,
  ];
  // Short digit runs only go as a leading date ("31 10 2020 Essays"): one
  // leading number is content ("10 Rules for Life", "1984").
  final isDigits = RegExp(r'^\d+$');
  if (words.length > 2 &&
      isDigits.hasMatch(words[0]) &&
      isDigits.hasMatch(words[1])) {
    while (words.length > 1 && isDigits.hasMatch(words.first)) {
      words.removeAt(0);
    }
  }
  final title = words.join(' ').replaceAll(RegExp(r'^[-–\s]+|[-–\s]+$'), '');
  return title.isEmpty ? stem : title;
}

int _pageCount(String path) {
  final document = PdfDocument(inputBytes: File(path).readAsBytesSync());
  try {
    return document.pages.count;
  } finally {
    document.dispose();
  }
}

/// The lines of pages [first]..[last] (inclusive), as plain records so they
/// can cross back from a worker isolate.
List<PdfLine> _extractLines(String path, int first, int last) {
  final document = PdfDocument(inputBytes: File(path).readAsBytesSync());
  try {
    return [
      for (final line in PdfTextExtractor(document)
          .extractTextLines(startPageIndex: first, endPageIndex: last))
        (
          text: line.text,
          top: line.bounds.top,
          left: line.bounds.left,
          right: line.bounds.right,
          fontSize: line.fontSize,
          pageIndex: line.pageIndex,
        ),
    ];
  } finally {
    document.dispose();
  }
}

/// Walks the outline tree depth-first, keeping every entry that resolves to a
/// page. A malformed destination skips that entry rather than failing the book.
void _collectOutline(
  PdfDocument document,
  PdfBookmarkBase node,
  List<OutlineEntry> into,
) {
  for (var i = 0; i < node.count; i++) {
    final bookmark = node[i];
    try {
      final page = bookmark.destination?.page;
      final title = bookmark.title.trim();
      if (page != null && title.isNotEmpty) {
        final index = document.pages.indexOf(page);
        if (index >= 0) into.add((title: title, pageIndex: index));
      }
    } catch (_) {/* unresolvable destination — skip this entry */}
    _collectOutline(document, bookmark, into);
  }
}

/// A lone capital the extractor split off its word at a kerning pair: "Y ou",
/// "T able". The producer pulls the pair together with a TJ offset, and
/// syncfusion reads the offset as a word gap. Only kerning pairs qualify (the
/// capital is one of [TVWYFP], the next letter one they kern with), and a key
/// combo or type parameter ("Shift+F on", "<T extends") is left alone.
final RegExp _kSplitCapital = RegExp(
  r"(?<![\p{L}\p{N}’'+\-<(])([TVWYFP]) ([aeoruy]\p{Ll}+)",
  unicode: true,
);

/// Words that follow a lone capital on their own ("P and Q", "the Y axis"),
/// so a split before one of them is left alone.
const Set<String> _kStandaloneAfterCapital = {
  'and',
  'are',
  'as',
  'at',
  'axis',
  'equals',
  'on',
  'or',
  'of',
  'over',
};

/// The same split in an all-caps word, around the A of a kerning pair:
/// "F ACTORY", "WHA T".
final RegExp _kSplitCapsLeft = RegExp(
  r'(?<![\p{L}])([FPTVWY]) (A\p{Lu}+)',
  unicode: true,
);
final RegExp _kSplitCapsRight = RegExp(
  r'(?<![\p{L}])(\p{Lu}*A) ([TVWY])(?![\p{L}])',
  unicode: true,
);

/// A two-digit list number split by kerning: "1 1. Feeling".
final RegExp _kSplitNumber = RegExp(r'^(\d) (\d)([.)]) ');

/// Re-joins words the extractor split at a kerning pair.
///
/// Geometry cannot do this: syncfusion's glyph bounds are too loose (ligatures,
/// tracking) — rebuilding spaces from them cost one book 30% of its real word
/// breaks. The splits all fall at known kerning pairs, so the text is enough.
// ponytail: pattern list, not a glyph rebuild. Measured on 9 books: ~130 fixes,
// a handful of misses on lone single-letter variables ("Y coords").
String repairKerningSplits(String text) => text
    .replaceAllMapped(
      _kSplitCapital,
      (m) => _kStandaloneAfterCapital.contains(m[2]) ? m[0]! : '${m[1]}${m[2]}',
    )
    .replaceAllMapped(_kSplitCapsLeft, (m) => '${m[1]}${m[2]}')
    .replaceAllMapped(_kSplitCapsRight, (m) => '${m[1]}${m[2]}')
    .replaceFirstMapped(_kSplitNumber, (m) => '${m[1]}${m[2]}${m[3]} ');

/// Opens a list item, whose marker hangs left of the text that follows it.
final RegExp _kListMarker = RegExp(r'^([•▪◦·\-–—*]|\d{1,3}[.)]|[a-z][.)])\s');

/// A list marker followed by a capitalized word: an item, not a wrapped line.
final RegExp _kListItemStart = RegExp(
  r'^([•▪◦·\-–—*]|\d{1,3}[.)])\s+\p{Lu}',
  unicode: true,
);

/// Lines closer together than this many pitches belong to the same block — a
/// running head and the watermark printed beside it, for instance.
const double _blockPitches = 0.5;

/// A block at the top or bottom of a page must stand this many line pitches
/// clear of the rest of the page to be a running-head candidate.
const double _isolationPitches = 1.5;

/// A y position must carry such a candidate on at least this share of pages
/// before every line at that position is dropped.
const double _repeatShare = 0.4;

/// Turns extracted [lines] into reflow-ready page text: running heads and page
/// numbers dropped, wrapped lines re-joined into paragraphs, paragraphs
/// separated by a blank line (the shape `toBlocks` groups on).
///
/// Returns [pageCount] entries; `result[i]` holds the paragraphs that *begin*
/// on page `i`, so a paragraph spanning a page break stays whole and is
/// attributed to the page it started on.
///
/// Pure by design (no PDF types) so it is unit-testable.
// ponytail: assumes a single text column in reading order — a two-column PDF
// will interleave. Detect columns by clustering `left` if that ever matters.
List<String> reflowLines(List<PdfLine> lines, int pageCount) {
  final pages = List.generate(math.max(pageCount, 0), (_) => <String>[]);
  if (lines.isEmpty) return [for (final p in pages) p.join('\n\n')];

  final ordered = [...lines]..sort((a, b) {
      final page = a.pageIndex.compareTo(b.pageIndex);
      if (page != 0) return page;
      final top = a.top.compareTo(b.top);
      return top != 0 ? top : a.left.compareTo(b.left);
    });

  final rows = _mergeRows(ordered);
  final pitch = _pitchOf(rows);
  // Per page as well as overall: a page of code listings leads much tighter
  // than a page of prose, and one median for the whole book makes ordinary
  // prose steps look like paragraph breaks.
  final pitchByPage = _pitchPerPage(rows, pitch);
  final kept = _withoutRunningHeads(rows, pitch);
  if (kept.isEmpty) return [for (final p in pages) p.join('\n\n')];

  // The measure: where full lines begin and end. Percentiles rather than the
  // extremes (one wide figure would define the column) and rather than the
  // median (half a technical book's lines are short code fragments, which drags
  // a median measure far inside the real one).
  final colLeft = _percentile([for (final l in kept) l.left], 0.15);
  final colRight = _percentile([for (final l in kept) l.right], 0.85);

  var buffer = StringBuffer();
  var bufferPage = kept.first.pageIndex;
  PdfLine? previous;
  double? lastStep;

  void flush() {
    final text = buffer.toString().trim();
    if (text.isNotEmpty && bufferPage < pages.length) {
      pages[bufferPage].add(text);
    }
    buffer = StringBuffer();
  }

  for (final raw in kept) {
    // Tabs and runs of spaces are layout, not language: some books set their
    // measure with tabs and the extractor hands them straight back.
    final text = repairKerningSplits(
      raw.text.replaceAll(RegExp(r'\s+'), ' ').trim(),
    );
    if (text.isEmpty) continue;
    final line = (
      text: text,
      top: raw.top,
      left: raw.left,
      right: raw.right,
      fontSize: raw.fontSize,
      pageIndex: raw.pageIndex,
    );
    final samePage = previous != null && previous.pageIndex == line.pageIndex;
    final step = samePage ? line.top - previous.top : null;
    if (previous != null &&
        _startsParagraph(
          line,
          previous,
          step,
          lastStep ?? pitchByPage[line.pageIndex] ?? pitch,
          colLeft,
          colRight,
        )) {
      flush();
    }
    if (buffer.isEmpty) bufferPage = line.pageIndex;
    buffer.write(buffer.isEmpty ? text : ' $text');
    previous = line;
    lastStep = step != null && step > 0.5 ? step : lastStep;
  }
  flush();

  return [for (final p in pages) p.join('\n\n')];
}

/// Merges lines that share a baseline into one row, ordered left to right.
///
/// An inline code span or a differently-styled word comes back as its own
/// `TextLine`, nudged a point or two off the baseline of the sentence holding
/// it. Sorted by `top` alone it lands *after* that sentence, which is how
/// "the command was designed" ends up followed by a stray "touch".
List<PdfLine> _mergeRows(List<PdfLine> ordered) {
  final rows = <PdfLine>[];
  var i = 0;
  while (i < ordered.length) {
    final first = ordered[i];
    final parts = <PdfLine>[first];
    var j = i;
    while (j + 1 < ordered.length &&
        ordered[j + 1].pageIndex == first.pageIndex &&
        (ordered[j + 1].top - first.top).abs() <
            math.max(first.fontSize, ordered[j + 1].fontSize) * 0.8) {
      j++;
      parts.add(ordered[j]);
    }
    if (parts.length == 1) {
      rows.add(first);
    } else {
      parts.sort((a, b) => a.left.compareTo(b.left));
      // The widest part sets the row's type size: a body line keeps body size
      // even when it holds a small code span.
      final widest = parts.reduce(
        (a, b) => (b.right - b.left) > (a.right - a.left) ? b : a,
      );
      rows.add((
        text: _joinParts(parts),
        top: parts.map((p) => p.top).reduce(math.min),
        left: parts.map((p) => p.left).reduce(math.min),
        right: parts.map((p) => p.right).reduce(math.max),
        fontSize: widest.fontSize,
        pageIndex: first.pageIndex,
      ));
    }
    i = j + 1;
  }
  return rows;
}

/// Joins one row's parts left to right, inserting a space only where the parts
/// stand apart. A display line set with wide letter tracking arrives as several
/// touching parts — joined unconditionally it reads "CA T ALOG OF".
String _joinParts(List<PdfLine> parts) {
  final buffer = StringBuffer();
  PdfLine? previous;
  for (final part in parts) {
    final text = part.text.trim();
    if (text.isEmpty) continue;
    if (previous != null && part.left - previous.right > part.fontSize * 0.25) {
      buffer.write(' ');
    }
    buffer.write(text);
    previous = part;
  }
  return buffer.toString();
}

double _median(List<double> values) => _percentile(values, 0.5);

double _percentile(List<double> values, double fraction) {
  final sorted = [...values]..sort();
  final index = (sorted.length * fraction).floor().clamp(0, sorted.length - 1);
  return sorted[index];
}

/// The document's usual line-to-line step, as the median of same-page steps.
/// Falls back to the median font size when a document has too few steps.
double _pitchOf(List<PdfLine> ordered) {
  final steps = <double>[];
  for (var i = 1; i < ordered.length; i++) {
    if (ordered[i].pageIndex != ordered[i - 1].pageIndex) continue;
    final step = ordered[i].top - ordered[i - 1].top;
    if (step > 0.5) steps.add(step);
  }
  if (steps.isEmpty) {
    final sizes = [for (final l in ordered) l.fontSize]..sort();
    final median = sizes.isEmpty ? 12.0 : sizes[sizes.length ~/ 2];
    return median * 1.2;
  }
  steps.sort();
  return steps[steps.length ~/ 2];
}

/// The usual line step of each page, falling back to [fallback] on a page with
/// too few lines to say.
Map<int, double> _pitchPerPage(List<PdfLine> rows, double fallback) {
  final steps = <int, List<double>>{};
  for (var i = 1; i < rows.length; i++) {
    if (rows[i].pageIndex != rows[i - 1].pageIndex) continue;
    final step = rows[i].top - rows[i - 1].top;
    if (step > 0.5) steps.putIfAbsent(rows[i].pageIndex, () => []).add(step);
  }
  return {
    for (final entry in steps.entries)
      entry.key: entry.value.length < 3 ? fallback : _median(entry.value),
  };
}

/// Drops running heads, folios and page watermarks: the top or bottom block of
/// a page, standing clear of the rest of it, at a y position that repeats
/// across many pages.
///
/// All three conditions are required, and each rules out a different innocent.
/// A chapter title also stands clear at the top of its page — but only on its
/// own page, so it fails the repetition test. The first line of ordinary body
/// text also opens a page — but it is one pitch from the second line, so it
/// fails the isolation test. Grouping into blocks first is what lets a running
/// head printed beside a watermark still count as isolated.
List<PdfLine> _withoutRunningHeads(List<PdfLine> ordered, double pitch) {
  // y (rounded into 3pt buckets) -> the pages carrying a candidate there.
  final seen = <int, Set<int>>{};
  final pageStarts = <int, int>{};
  for (var i = 0; i < ordered.length; i++) {
    pageStarts.putIfAbsent(ordered[i].pageIndex, () => i);
  }

  for (final entry in pageStarts.entries) {
    final start = entry.value;
    var end = start;
    while (end + 1 < ordered.length &&
        ordered[end + 1].pageIndex == entry.key) {
      end++;
    }
    if (end == start) continue; // a one-line page tells us nothing

    // Walk the first block down from the top and the last block up from the
    // bottom, then check each stands clear of what remains.
    var firstEnd = start;
    while (firstEnd + 1 <= end &&
        ordered[firstEnd + 1].top - ordered[firstEnd].top < pitch * _blockPitches) {
      firstEnd++;
    }
    var lastStart = end;
    while (lastStart - 1 >= start &&
        ordered[lastStart].top - ordered[lastStart - 1].top < pitch * _blockPitches) {
      lastStart--;
    }

    void mark(int from, int to) {
      for (var i = from; i <= to; i++) {
        seen
            .putIfAbsent((ordered[i].top / 3).round(), () => <int>{})
            .add(ordered[i].pageIndex);
      }
    }

    if (firstEnd < end &&
        ordered[firstEnd + 1].top - ordered[firstEnd].top >
            pitch * _isolationPitches) {
      mark(start, firstEnd);
    }
    if (lastStart > start &&
        ordered[lastStart].top - ordered[lastStart - 1].top >
            pitch * _isolationPitches) {
      mark(lastStart, end);
    }
  }

  final pagesSeen = {for (final l in ordered) l.pageIndex}.length;
  final threshold = math.max(3, (pagesSeen * _repeatShare).round());
  final dropped = {
    for (final entry in seen.entries)
      if (entry.value.length >= threshold) entry.key,
  };
  if (dropped.isEmpty) return ordered;
  return [
    for (final l in ordered)
      if (!dropped.contains((l.top / 3).round())) l,
  ];
}

/// Whether [line] opens a new paragraph rather than continuing [previous].
///
/// [step] is the vertical distance between the two (null across a page break),
/// and [leading] the step the text was running at just before — comparing
/// against the *local* leading rather than a book-wide average is what keeps a
/// chapter of tightly-led code listings from redefining what a paragraph break
/// looks like in the prose around it.
bool _startsParagraph(
  PdfLine line,
  PdfLine previous,
  double? step,
  double leading,
  double colLeft,
  double colRight,
) {
  // A change of type size separates a heading from the paragraph before it,
  // and is the only signal that survives a page break — no vertical step
  // exists to measure across one, and a paragraph may legitimately continue.
  if ((line.fontSize - previous.fontSize).abs() > 0.5) return true;
  if (step != null && step > leading * 1.5) return true;
  // A numbered or bulleted item after a finished sentence opens its own
  // paragraph even when the book sets it flush, at body leading.
  // The capital after the marker keeps a wrapped sentence that happens to
  // start "2. the" from breaking.
  if (_kListItemStart.hasMatch(line.text) &&
      RegExp(r'[.!?:"”)]$').hasMatch(previous.text)) {
    return true;
  }
  // A first-line indent, measured against the line above rather than the page:
  // a book with a second, indented margin for asides would otherwise read as
  // one indent per line. A list item is the exception — its marker hangs to the
  // left, so every line after the first looks indented.
  if (line.left > previous.left + line.fontSize * 0.6 &&
      !_kListMarker.hasMatch(previous.text.trimLeft())) {
    return true;
  }
  // Proportional to the measure, not to the type size: a ragged-right book's
  // lines all stop a little short, so only a line giving up a real slice of the
  // measure is a paragraph's last one.
  if (previous.right < colRight - (colRight - colLeft) * 0.15) return true;
  return false;
}
