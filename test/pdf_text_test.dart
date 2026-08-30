// Guards `reflowLines` in `services/pdf_service.dart` — the geometry-to-prose
// half of extraction, which is pure and needs no PDF. The syncfusion parse
// either side of it is verified by running the app against a real book.
//
//   flutter test test/pdf_text_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:ember/services/pdf_service.dart';

/// A line of body text on the standard measure, 50pt to 500pt.
PdfLine line(
  String text, {
  required double top,
  double left = 50,
  double right = 500,
  double fontSize = 12,
  int page = 0,
}) =>
    (
      text: text,
      top: top,
      left: left,
      right: right,
      fontSize: fontSize,
      pageIndex: page,
    );

void main() {
  test('wrapped lines re-join into one paragraph', () {
    final pages = reflowLines([
      line('the first line of it', top: 100),
      line('the second line of it', top: 118),
      line('and the end.', top: 136, right: 300),
    ], 1);

    expect(pages.first, 'the first line of it the second line of it and the end.');
  });

  test('a wider-than-usual vertical step starts a new paragraph', () {
    final pages = reflowLines([
      line('one', top: 100),
      line('two', top: 118),
      line('a new paragraph', top: 150),
    ], 1);

    expect(pages.first.split('\n\n'), ['one two', 'a new paragraph']);
  });

  test('a first-line indent starts a new paragraph', () {
    final pages = reflowLines([
      line('one', top: 100),
      line('two', top: 118),
      line('indented', top: 136, left: 62),
    ], 1);

    expect(pages.first.split('\n\n'), ['one two', 'indented']);
  });

  test('a line stopping short of the measure ends its paragraph', () {
    final pages = reflowLines([
      line('one', top: 100),
      line('short of the measure', top: 118, right: 300),
      line('next', top: 136),
    ], 1);

    expect(pages.first.split('\n\n'), ['one short of the measure', 'next']);
  });

  test('a running head repeated across pages is dropped, a chapter title is not',
      () {
    final lines = <PdfLine>[];
    for (var page = 0; page < 4; page++) {
      lines.add(line('Running Head', top: 10, right: 200, page: page));
      if (page == 0) {
        lines.add(line('A Chapter Title', top: 60, right: 200, page: page));
      }
      lines.add(line('body one', top: 100, page: page));
      lines.add(line('body two', top: 118, page: page));
      lines.add(line('body three.', top: 136, right: 300, page: page));
    }

    final pages = reflowLines(lines, 4);

    expect(pages.every((p) => !p.contains('Running Head')), isTrue);
    expect(pages.first, contains('A Chapter Title'));
    expect(pages.last, 'body one body two body three.');
  });

  test('a paragraph spanning a page break stays whole, on the page it began',
      () {
    final pages = reflowLines([
      line('this paragraph starts here', top: 100, page: 0),
      line('and runs on', top: 118, page: 0),
      line('to the next page.', top: 100, page: 1, right: 300),
    ], 2);

    expect(pages[0], 'this paragraph starts here and runs on to the next page.');
    expect(pages[1], '');
  });

  test('a change of type size separates a heading across a page break', () {
    final pages = reflowLines([
      line('a paragraph that fills the measure', top: 100, page: 0),
      line('A Heading', top: 100, page: 1, fontSize: 20, right: 300),
      line('its first paragraph', top: 140, page: 1, right: 300),
    ], 2);

    expect(pages[0], 'a paragraph that fills the measure');
    expect(pages[1].split('\n\n'), ['A Heading', 'its first paragraph']);
  });

  test('lines sharing a baseline merge into one row, left to right', () {
    final pages = reflowLines([
      line('the', top: 100, right: 120),
      line('command runs.', top: 102, left: 165, right: 300),
      line('touch', top: 101, left: 124, right: 160),
    ], 1);

    expect(pages.first, 'the touch command runs.');
  });

  test('touching parts of a tracked-out display line join without a space', () {
    final pages = reflowLines([
      line('CA', top: 100, right: 120, fontSize: 20),
      line('T', top: 100, left: 120, right: 132, fontSize: 20),
      line('ALOG', top: 100, left: 132, right: 200, fontSize: 20),
    ], 1);

    expect(pages.first, 'CATALOG');
  });

  test('tabs and runs of spaces collapse to single spaces', () {
    final pages = reflowLines([
      line('set\tand\t\tmodify', top: 100, right: 300),
    ], 1);

    expect(pages.first, 'set and modify');
  });
}
