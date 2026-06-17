import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:readme/services/paginator.dart';

void main() {
  const style = TextStyle(fontSize: 18, height: 1.5);
  const size = Size(320, 480);

  testWidgets('every page fits the height (never needs to scroll)',
      (tester) async {
    final text = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. ' * 400;
    final pages = Paginator.paginate(text: text, style: style, size: size);
    final strut = Paginator.strutFor(style);

    expect(pages.length, greaterThan(1), reason: 'long text should paginate');

    // Each page must leave at least one line of slack below it, so the
    // SelectableText/EditableText that renders it has zero scroll extent and
    // can't be scrolled up/down.
    final lineHeight = style.fontSize! * style.height!;
    for (final page in pages) {
      final painter = TextPainter(
        text: TextSpan(text: page.text, style: style),
        strutStyle: strut,
        textDirection: TextDirection.ltr,
        maxLines: null,
      )..layout(maxWidth: size.width);
      expect(painter.height, lessThanOrEqualTo(size.height - lineHeight + 2),
          reason: 'page too tall, would be scrollable: '
              '"${page.text.substring(0, 20)}…"');
    }
  });

  testWidgets('page offsets are contiguous and increasing', (tester) async {
    final text = 'word ' * 500;
    final pages = Paginator.paginate(text: text, style: style, size: size);
    for (var i = 1; i < pages.length; i++) {
      expect(pages[i].startOffset, greaterThan(pages[i - 1].startOffset));
    }
  });
}
