/// A highlight over a span of the book's text, stored as character offsets into
/// [Book.content] (not screen coordinates) so it survives re-pagination, font
/// changes and theme changes.
class Highlight {
  final int start;
  final int end;

  /// ARGB color value (e.g. Colors.yellow.value).
  final int color;

  const Highlight({required this.start, required this.end, required this.color});

  bool overlaps(int from, int to) => start < to && end > from;

  Map<String, dynamic> toMap() => {'start': start, 'end': end, 'color': color};

  factory Highlight.fromMap(Map<dynamic, dynamic> m) => Highlight(
        start: m['start'] as int,
        end: m['end'] as int,
        color: m['color'] as int,
      );
}

/// A book imported from a PDF. We store the extracted plain text (not the PDF
/// itself) so the reader can reflow it — change font size, highlight words, and
/// resume by character offset regardless of how the text wraps on screen.
class Book {
  final String id;
  final String title;

  /// Full extracted text. Paragraphs are separated by single newlines.
  final String content;

  final DateTime addedAt;

  /// Resume anchor: the character offset into [content] of the first character
  /// on the page the user last had open. Stored as a logical position (not a
  /// page number or pixel offset) so it stays correct after the text is
  /// re-paginated at a different font size or on a different screen.
  int lastCharOffset;

  /// Highlights, kept sorted by [Highlight.start].
  List<Highlight> highlights;

  Book({
    required this.id,
    required this.title,
    required this.content,
    required this.addedAt,
    this.lastCharOffset = 0,
    List<Highlight>? highlights,
  }) : highlights = highlights ?? [];

  void addHighlight(int start, int end, int color) {
    if (end <= start) return;
    highlights
      ..add(Highlight(start: start, end: end, color: color))
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  /// Removes any highlight overlapping the given range. Returns true if one was
  /// removed (used so a selection over a highlight toggles it off).
  bool removeHighlightsIn(int start, int end) {
    final before = highlights.length;
    highlights.removeWhere((h) => h.overlaps(start, end));
    return highlights.length != before;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'addedAt': addedAt.toIso8601String(),
        'lastCharOffset': lastCharOffset,
        'highlights': highlights.map((h) => h.toMap()).toList(),
      };

  factory Book.fromMap(Map<dynamic, dynamic> map) => Book(
        id: map['id'] as String,
        title: map['title'] as String,
        content: map['content'] as String,
        addedAt: DateTime.parse(map['addedAt'] as String),
        lastCharOffset: (map['lastCharOffset'] as int?) ?? 0,
        highlights: ((map['highlights'] as List?) ?? [])
            .map((h) => Highlight.fromMap(Map<dynamic, dynamic>.from(h as Map)))
            .toList(),
      );
}
