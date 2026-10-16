// Guards the block classification in `features/reader/reflow.dart` — the part
// of the reflow pipeline that is pure string logic (no fonts, no binding).
// `paginate` is not covered here: its TextPainter needs real Google Fonts, so
// it is verified by running the app.
//
// Run this file on its own — a bare `flutter test` also runs gen_icon_test.dart,
// which rewrites assets/icon/*.png:
//
//   flutter test test/reflow_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:ember/features/reader/reflow.dart';

void main() {
  test('an all-caps line becomes a title block', () {
    final blocks = toBlocks('CHAPTER ONE\n\nHe woke before the alarm.');
    expect(blocks.first.kind, BlockKind.title);
    expect(blocks.first.text, 'CHAPTER ONE');
  });

  test('wrapped body lines re-join into one indented paragraph', () {
    final blocks = toBlocks(
      'The quick brown fox jumps over\nthe lazy dog and keeps running.',
    );
    expect(blocks, hasLength(1));
    expect(blocks.single.kind, BlockKind.body);
    expect(
      blocks.single.text,
      '${kIndent}The quick brown fox jumps over the lazy dog and keeps running.',
    );
  });

  test('a sentence opening with a section keyword stays body', () {
    final blocks =
        toBlocks('Part of the reason he left the city was the noise.');
    expect(blocks.single.kind, BlockKind.body);
  });

  test('the indent is two em-spaces, not ASCII spaces', () {
    expect(kIndent.codeUnits, [0x2003, 0x2003]);
  });

  test('a display title split across sizes folds into one title', () {
    final blocks = toBlocks(
      [
        '7',
        'WHAT the',
        'FEELINGS',
        'you most',
        'SUPPRESS',
        'are trying to',
        'TELL YOU',
        'Emotional intelligence is not how infrequently you feel anything.',
      ].join('\n\n'),
    );
    expect(
      [for (final b in blocks) b.kind],
      [BlockKind.title, BlockKind.title, BlockKind.body],
    );
    expect(blocks[0].text, '7');
    expect(
      blocks[1].text,
      'WHAT the FEELINGS you most SUPPRESS are trying to TELL YOU',
    );
  });

  test('consecutive headings with no fragment between stay apart', () {
    final blocks = toBlocks(
      'CHAPTER ONE\n\nThe Beginning\n\nHe woke before the alarm.',
    );
    expect(blocks.map((b) => b.text.trim()), [
      'CHAPTER ONE',
      'The Beginning',
      'He woke before the alarm.',
    ]);
  });
}
