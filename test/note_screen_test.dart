// Drives the real NoteScreen widget: writing mode must page horizontally on a
// whole-line grid, must not scroll vertically under the finger, and must keep
// saving. The gesture part matters most — flutter_test reports as Android,
// which is exactly the platform where the TextField's own horizontal-drag
// recognizer competes with the swipe overlay.
//
// Run this file on its own — a bare `flutter test` also runs gen_icon_test.dart,
// which rewrites assets/icon/*.png:
//
//   flutter test test/note_screen_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

import 'package:ember/features/notes/note_screen.dart';
import 'package:ember/features/reader/widgets/icon_btn.dart';
import 'package:ember/providers/storage_provider.dart';
import 'package:ember/services/storage_service.dart';

/// The bits of [StorageService] the notes screen touches. Its constructor is
/// private, so this implements rather than extends; `noSuchMethod` catches
/// anything the screen reaches for that the fake hasn't thought about.
class _FakeStorage implements StorageService {
  _FakeStorage(this._prefs, this.note);

  final Box _prefs;
  String note;

  @override
  Box get prefs => _prefs;

  @override
  Future<String> readNote(String bookId) async => note;

  @override
  Future<void> writeNote(String bookId, String text) async => note = text;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

/// The `n/m` page counter, as rendered.
String _counter(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((w) => w.data ?? '')
    .firstWhere((s) => RegExp(r'^\d+/\d+$').hasMatch(s));

int _page(WidgetTester tester) => int.parse(_counter(tester).split('/').first);
int _count(WidgetTester tester) => int.parse(_counter(tester).split('/').last);

double _offset(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;

/// The counter row's chevrons. Matched on size, because the top bar's back
/// button is the same glyph a few points larger.
Finder _chevron(IconData icon) => find.byWidgetPredicate(
      (w) => w is Icon && w.icon == icon && w.size == 22,
    );

final _back = _chevron(Icons.chevron_left);
final _forward = _chevron(Icons.chevron_right);

/// Whether a chevron is tappable.
bool _enabled(WidgetTester tester, Finder chevron) =>
    tester
        .widget<IconBtn>(
          find.ancestor(of: chevron, matching: find.byType(IconBtn)),
        )
        .onTap !=
    null;

/// A point on the visible page, well clear of the top bar and counter row.
const _inThePage = Offset(400, 300);

Future<void> _toFirstPage(WidgetTester tester) async {
  while (_page(tester) > 1) {
    await tester.tap(_back);
    await tester.pumpAndSettle();
  }
}

void main() {
  late Directory tmp;
  late Box prefs;

  setUpAll(() async {
    // No network in tests; fall back to the ambient font rather than logging a
    // failed fetch for every glyph run.
    GoogleFonts.config.allowRuntimeFetching = false;
    tmp = await Directory.systemTemp.createTemp('ember_note_test');
    Hive.init(tmp.path);
    prefs = await Hive.openBox('prefs');
  });

  tearDownAll(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  Future<_FakeStorage> pump(WidgetTester tester, String note) async {
    final storage = _FakeStorage(prefs, note);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
        child: const MaterialApp(
          home: NoteScreen(bookId: 'b1', title: 'Test Book'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return storage;
  }

  /// 120 lines is exactly 8 pages of 15 on the default 800x600 test surface.
  final longNote = List.generate(120, (i) => 'line $i').join('\n');

  testWidgets('a notebook that fits the box is a single page', (tester) async {
    await pump(tester, '');
    expect(_counter(tester), '1/1');
    expect(_offset(tester), 0);

    await pump(tester, 'one short thought');
    expect(_counter(tester), '1/1');
  });

  testWidgets('a long notebook paginates and opens where writing left off',
      (tester) async {
    await pump(tester, longNote);
    // autofocus drops the caret at the end of the text, as it always has, so
    // the notebook opens on its last page ready to keep writing.
    expect(_count(tester), greaterThan(1));
    expect(_page(tester), _count(tester));
  });

  testWidgets('a page turn moves the body by exactly one whole-line step',
      (tester) async {
    await pump(tester, longNote);
    await _toFirstPage(tester);
    expect(_offset(tester), 0);

    await tester.tap(_forward);
    await tester.pumpAndSettle();
    final step = _offset(tester);
    expect(step, greaterThan(0));
    expect(_page(tester), 2);

    await tester.tap(_forward);
    await tester.pumpAndSettle();
    expect(_offset(tester), closeTo(step * 2, 0.01));
    expect(_page(tester), 3);

    await tester.tap(_back);
    await tester.pumpAndSettle();
    expect(_offset(tester), closeTo(step, 0.01));
    expect(_page(tester), 2);
  });

  testWidgets('the last page lands on the grid, not short of it',
      (tester) async {
    await pump(tester, longNote);
    await _toFirstPage(tester);
    await tester.tap(_forward);
    await tester.pumpAndSettle();
    final step = _offset(tester);

    final last = _count(tester);
    while (_page(tester) < last) {
      await tester.tap(_forward);
      await tester.pumpAndSettle();
    }
    // Not clamped by maxScrollExtent into repeating the previous page's lines.
    expect(_offset(tester), closeTo(step * (last - 1), 0.01));
  });

  testWidgets('a horizontal swipe over the text turns the page', (tester) async {
    await pump(tester, longNote);
    await _toFirstPage(tester);

    // From a point inside the visible page — the TextField itself is taller
    // than the screen, so its center is nowhere near it. The overlay must beat
    // the field's own TapAndHorizontalDragGestureRecognizer in the arena.
    await tester.flingFrom(_inThePage, const Offset(-300, 0), 900);
    await tester.pumpAndSettle();
    expect(_page(tester), 2);

    await tester.flingFrom(_inThePage, const Offset(300, 0), 900);
    await tester.pumpAndSettle();
    expect(_page(tester), 1);
  });

  testWidgets('a vertical drag does not scroll the body', (tester) async {
    await pump(tester, longNote);
    await _toFirstPage(tester);
    final before = _offset(tester);

    await tester.dragFrom(_inThePage, const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(_offset(tester), before);
    expect(_page(tester), 1);
  });

  testWidgets('the chevrons stop at both ends', (tester) async {
    await pump(tester, longNote);
    // Opened on the last page: forward is dead, back is live.
    expect(_enabled(tester, _forward), isFalse);
    expect(_enabled(tester, _back), isTrue);

    await _toFirstPage(tester);
    expect(_enabled(tester, _back), isFalse);
    expect(_enabled(tester, _forward), isTrue);
  });

  testWidgets('typing past the end of a page opens a new one', (tester) async {
    await pump(tester, '');
    expect(_counter(tester), '1/1');

    await tester.enterText(
        find.byType(TextField), List.generate(40, (i) => 'line $i').join('\n'));
    await tester.pumpAndSettle();

    expect(_count(tester), 3);
    // The caret is at the end of what was just typed, so that is the page shown.
    expect(_page(tester), 3);
  });

  testWidgets('typing still saves through the debounce', (tester) async {
    final storage = await pump(tester, '');
    await tester.enterText(find.byType(TextField), 'a thought');
    await tester.pump(const Duration(seconds: 1));
    expect(storage.note, 'a thought');
  });

  testWidgets('closing the screen flushes what the debounce has not', (tester) async {
    final storage = await pump(tester, '');
    await tester.enterText(find.byType(TextField), 'unsaved when torn down');
    // Tear the screen down inside the debounce window: dispose must still get
    // the text out. It used to read the provider from dispose, where `ref`
    // throws, so the last edits were dropped.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    expect(storage.note, 'unsaved when torn down');
  });

  testWidgets('the mode toggle round-trips without losing the text',
      (tester) async {
    final storage = await pump(tester, longNote);

    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(_count(tester), greaterThan(1)); // reading mode paginated too

    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      longNote,
    );
    expect(storage.note, longNote);
  });
}
