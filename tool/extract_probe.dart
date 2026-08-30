// ponytail: throwaway measurement harness, not a test. Runs under `flutter test`
// because syncfusion depends on dart:ui (so plain `dart run` cannot load it).
//
//   PDF=~/Downloads/design-patterns-en.pdf FROM=20 flutter test tool/extract_probe.dart
//
// Prints the real PdfService output for a page, plus the chapter list, so the
// extraction can be eyeballed against the book. Delete once it stops earning
// its keep.
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:ember/services/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

final _longRun = RegExp(r'[A-Za-z’,;]{18,}');

void main() {
  test('probe', () async {
    final path = Platform.environment['PDF'];
    if (path == null) return print('set PDF=<path to a pdf>');
    final from = int.parse(Platform.environment['FROM'] ?? '20');
    final count = int.parse(Platform.environment['COUNT'] ?? '2');

    const service = PdfService();
    final content = await service.extract(path);
    print('pages=${content.pageCount}  glued in full text: '
        '${_longRun.allMatches(content.fullText).length}');
    for (var i = from; i < from + count && i < content.pages.length; i++) {
      print('\n══ page $i ══');
      print(content.pages[i]);
    }
    final needle = Platform.environment['GREP'];
    if (needle != null) {
      for (final para in content.fullText.split('\n\n')) {
        if (para.toLowerCase().contains(needle.toLowerCase())) print('· $para');
      }
    }
    final outline = await service.outline(path);
    print('\n══ outline: ${outline.length} entries ══');
    for (final e in outline.take(15)) {
      print('  p.${e.pageIndex}  ${e.title}');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
