/// A named division of a Book, taken from the PDF's own outline or, when it has
/// none, from the headings detected in its text. Anchored to a PDF page, the
/// same unit bookmarks and highlights are anchored to.
///
/// Not a Hive record: chapters live in a `<bookId>.toc.json` sidecar beside the
/// text cache, so adding them needed no change to the hand-written [Book]
/// adapter.
class Chapter {
  const Chapter({required this.title, required this.pageIndex});

  final String title;

  /// Zero-based PDF page the chapter starts on.
  final int pageIndex;

  Map<String, dynamic> toJson() => {'title': title, 'page': pageIndex};

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
        title: json['title'] as String? ?? '',
        pageIndex: (json['page'] as num?)?.toInt() ?? 0,
      );
}
