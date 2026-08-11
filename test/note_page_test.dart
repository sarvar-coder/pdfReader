// Guards the writing-mode page grid in `features/notes/note_screen.dart` — the
// part of paged note-taking that is pure arithmetic (no fonts, no binding).
// The widget wiring around it is verified by running the app.
//
// Run this file on its own — a bare `flutter test` also runs gen_icon_test.dart,
// which rewrites assets/icon/*.png:
//
//   flutter test test/note_page_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:ember/features/notes/note_screen.dart';

void main() {
  const lineH = 30.0;

  group('notePageGrid', () {
    test('keeps whole lines only, dropping the remainder', () {
      final grid = notePageGrid(500, lineH); // 16.6 lines
      expect(grid.lines, 16);
      expect(grid.step, 480);
    });

    test('never returns a zero-line page, however short the box', () {
      expect(notePageGrid(4, lineH).lines, 1);
      expect(notePageGrid(0, lineH).lines, 1);
    });

    test('survives a degenerate line height', () {
      expect(notePageGrid(500, 0).step, 0);
    });
  });

  group('notePageCount', () {
    const step = 480.0;

    test('an empty or single-page body is one page', () {
      expect(notePageCount(0, step), 1);
      expect(notePageCount(step, step), 1);
    });

    test('one line over a page boundary opens a new page', () {
      expect(notePageCount(step + 1, step), 2);
      expect(notePageCount(2 * step, step), 2);
      expect(notePageCount(2 * step + 1, step), 3);
    });
  });

  group('notePageFor', () {
    const step = 480.0;

    test('a forward caret reveal rounds up, not to nearest', () {
      // Typing past the bottom of page 0 scrolls by ~one line. That offset is
      // far nearer page 0 than page 1, so round() would strand the caret.
      expect(notePageFor(lineH, 0, step), 1);
      expect(notePageFor(step + lineH, 1, step), 2);
    });

    test('a backward caret reveal rounds down', () {
      expect(notePageFor(3 * step, 5, step), 3);
      expect(notePageFor(2 * step - lineH, 2, step), 1);
    });

    test('an on-grid offset stays put, within a pixel of slop', () {
      expect(notePageFor(2 * step, 2, step), 2);
      expect(notePageFor(2 * step + 0.2, 2, step), 2);
      expect(notePageFor(2 * step - 0.2, 2, step), 2);
    });

    test('never returns a negative page', () {
      expect(notePageFor(-50, 1, step), 0);
    });
  });
}
