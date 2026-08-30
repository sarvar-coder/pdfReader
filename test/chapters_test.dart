// Guards `buildChapters` in `providers/library_provider.dart`: the PDF's own
// outline wins, and a PDF without one falls back to the headings the reflow
// classifier finds, anchored to the page they were found on.
//
//   flutter test test/chapters_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:ember/providers/library_provider.dart';
import 'package:ember/services/pdf_service.dart';

/// A [PdfService] that parses nothing — the two answers are handed in.
class _FakePdf implements PdfService {
  _FakePdf({this.entries = const [], required this.content});

  final List<OutlineEntry> entries;
  final PdfContent content;

  @override
  Future<List<OutlineEntry>> outline(String path) async => entries;

  @override
  Future<PdfContent> extract(String path) async => content;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

void main() {
  test('the embedded outline is used when the PDF declares one', () async {
    final service = _FakePdf(
      entries: const [
        (title: 'One', pageIndex: 0),
        (title: 'Two', pageIndex: 7),
      ],
      content: const PdfContent(pageCount: 2, pages: ['CHAPTER NINE', 'body']),
    );

    final chapters = await buildChapters(service, 'book.pdf', null);

    expect(chapters.map((c) => c.title), ['One', 'Two']);
    expect(chapters.map((c) => c.pageIndex), [0, 7]);
  });

  test('without an outline, headings in the text become chapters', () async {
    final service = _FakePdf(
      content: const PdfContent(
        pageCount: 3,
        pages: [
          'CHAPTER ONE\n\nSome body text that is plainly not a heading at all.',
          'body only, nothing that looks like a heading in this page of prose.',
          'CHAPTER TWO\n\nMore body text.',
        ],
      ),
    );

    final chapters = await buildChapters(service, 'book.pdf', null);

    expect(chapters.map((c) => c.title), ['CHAPTER ONE', 'CHAPTER TWO']);
    expect(chapters.map((c) => c.pageIndex), [0, 2]);
  });

  test('the fallback reuses text already extracted, rather than re-parsing',
      () async {
    var extracted = 0;
    final service = _CountingPdf(() => extracted++);

    await buildChapters(
      service,
      'book.pdf',
      const PdfContent(pageCount: 1, pages: ['CHAPTER ONE\n\nbody.']),
    );

    expect(extracted, 0);
  });
}

class _CountingPdf extends _FakePdf {
  _CountingPdf(this.onExtract)
      : super(content: const PdfContent(pageCount: 0, pages: []));

  final void Function() onExtract;

  @override
  Future<PdfContent> extract(String path) async {
    onExtract();
    return super.extract(path);
  }
}
