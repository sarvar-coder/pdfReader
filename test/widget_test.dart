import 'package:flutter_test/flutter_test.dart';

import 'package:readme/models/book.dart';

void main() {
  test('toMap/fromMap round-trips offset and highlights', () {
    final book = Book(
      id: '1',
      title: 'Test',
      content: 'Hello world',
      addedAt: DateTime.parse('2026-01-01T00:00:00.000'),
      lastCharOffset: 42,
    );
    book.addHighlight(0, 5, 0xFFFFE082);
    final restored = Book.fromMap(book.toMap());
    expect(restored.title, 'Test');
    expect(restored.lastCharOffset, 42);
    expect(restored.highlights.length, 1);
    expect(restored.highlights.first.start, 0);
    expect(restored.highlights.first.end, 5);
    expect(restored.highlights.first.color, 0xFFFFE082);
  });

  test('fromMap defaults are safe for older records', () {
    final restored = Book.fromMap({
      'id': '1',
      'title': 'Old',
      'content': 'x',
      'addedAt': '2026-01-01T00:00:00.000',
    });
    expect(restored.lastCharOffset, 0);
    expect(restored.highlights, isEmpty);
  });

  test('addHighlight keeps list sorted and ignores empty ranges', () {
    final book = Book(id: '1', title: 't', content: 'x', addedAt: DateTime.now());
    book.addHighlight(10, 15, 1);
    book.addHighlight(0, 5, 1);
    book.addHighlight(7, 7, 1); // empty, ignored
    expect(book.highlights.map((h) => h.start), [0, 10]);
  });

  test('removeHighlightsIn removes overlapping spans only', () {
    final book = Book(id: '1', title: 't', content: 'x', addedAt: DateTime.now());
    book.addHighlight(0, 5, 1);
    book.addHighlight(20, 25, 1);
    final removed = book.removeHighlightsIn(2, 3); // overlaps first only
    expect(removed, isTrue);
    expect(book.highlights.length, 1);
    expect(book.highlights.first.start, 20);
  });
}
