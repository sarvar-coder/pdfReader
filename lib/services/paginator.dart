import 'dart:math';

import 'package:flutter/widgets.dart';

/// A single rendered page of text plus where it starts in the full content.
class BookPage {
  final String text;

  /// Character offset of this page's first character within the full content.
  /// Used as the resume anchor so position survives re-pagination.
  final int startOffset;

  BookPage(this.text, this.startOffset);
}

/// Splits reflowable text into screen-sized pages for a swipe (PageView)
/// reader. Each page is guaranteed to fit the available height, so a page never
/// scrolls — when text doesn't fit we simply emit more pages.
///
/// Pagination depends on font size and available area, so it must be recomputed
/// whenever either changes.
///
/// Note: this uses [TextPainter], which relies on the Flutter engine, so it
/// must run on the UI isolate (it can't be moved to a background isolate).
class Paginator {
  /// Look-ahead window. A single page never holds more than a few thousand
  /// characters, so we only lay out a bounded slice at a time — laying out the
  /// whole remaining book on every page would be O(n²) on long books.
  static const _window = 6000;

  /// A fixed strut so measurement here matches how the reader renders the text.
  /// [SelectableText] applies a strut that can make lines taller than a bare
  /// [TextPainter] would measure; forcing the same strut in both places keeps
  /// pagination and rendering in lock-step, which is what stops overflow.
  static StrutStyle strutFor(TextStyle style) => StrutStyle(
        fontSize: style.fontSize,
        height: style.height,
        forceStrutHeight: true,
      );

  static List<BookPage> paginate({
    required String text,
    required TextStyle style,
    required Size size,
  }) {
    final pages = <BookPage>[];
    final strut = strutFor(style);
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      strutStyle: strut,
      maxLines: null,
    );

    int measure(String s) {
      painter.text = TextSpan(text: s, style: style);
      painter.layout(maxWidth: size.width);
      return painter.height.ceil();
    }

    // The page text is rendered inside a SelectableText, whose underlying
    // EditableText is internally scrollable. If a page's content is even 1px
    // taller than its box you can scroll it up/down. To make that impossible we
    // paginate against a height one line SHORTER than the real box, so every
    // page is guaranteed to leave slack — overflow rolls to the next page
    // instead of scrolling.
    final lineHeight = (style.fontSize ?? 16) * (style.height ?? 1.2);
    final usableHeight = (size.height - lineHeight).clamp(lineHeight, size.height);

    var start = 0;
    while (start < text.length) {
      // Skip leading whitespace so a page never opens with blank lines. We
      // advance the real offset (rather than trimming the page text later) so
      // that startOffset + localIndex still maps exactly to a content index —
      // highlights depend on this.
      while (start < text.length && _isWhitespace(text.codeUnitAt(start))) {
        start++;
      }
      if (start >= text.length) break;

      final windowEnd = min(start + _window, text.length);
      final slice = text.substring(start, windowEnd);

      final fits = measure(slice) <= usableHeight;
      int end;
      if (fits && windowEnd == text.length) {
        // Whole remaining text fits on this last page.
        end = slice.length;
      } else {
        // Estimate the break point at the bottom of the page, then verify and
        // shrink until it genuinely fits — this is what guarantees no scroll.
        final pos =
            painter.getPositionForOffset(Offset(size.width, usableHeight));
        end = pos.offset > 0 ? pos.offset : 1;
        end = _shrinkToFit(slice, end, usableHeight, measure);
      }

      end = _backUpToWordBoundary(slice, end);
      if (end <= 0) end = 1; // guarantee forward progress

      // Only trailing whitespace is trimmed (it sits at the end, so it can't
      // shift the offsets of earlier characters).
      pages.add(BookPage(slice.substring(0, end).trimRight(), start));
      start += end;
    }

    painter.dispose();
    return pages.isEmpty ? [BookPage('', 0)] : pages;
  }

  /// Reduce [end] one word at a time until `slice[0:end]` fits within
  /// [maxHeight]. The estimate from `getPositionForOffset` is usually correct or
  /// off by a line, so this rarely iterates more than once or twice.
  static int _shrinkToFit(
    String slice,
    int end,
    double maxHeight,
    int Function(String) measure,
  ) {
    while (end > 1 && measure(slice.substring(0, end)) > maxHeight) {
      final prevSpace = slice.lastIndexOf(RegExp(r'\s'), end - 1);
      end = prevSpace > 0 ? prevSpace : end - 1;
    }
    return end;
  }

  static bool _isWhitespace(int codeUnit) =>
      codeUnit == 0x20 || // space
      codeUnit == 0x0A || // \n
      codeUnit == 0x0D || // \r
      codeUnit == 0x09; // \t

  /// Avoid slicing through the middle of a word: back up to the last
  /// whitespace, unless that throws away most of the page.
  static int _backUpToWordBoundary(String slice, int end) {
    if (end >= slice.length) return slice.length;
    final lastSpace = slice.lastIndexOf(RegExp(r'\s'), end);
    if (lastSpace > end * 0.5) return lastSpace + 1;
    return end;
  }

  /// Index of the page containing [charOffset] — used to restore the resume
  /// position after (re)pagination.
  static int pageIndexForOffset(List<BookPage> pages, int charOffset) {
    for (var i = pages.length - 1; i >= 0; i--) {
      if (pages[i].startOffset <= charOffset) return i;
    }
    return 0;
  }
}
