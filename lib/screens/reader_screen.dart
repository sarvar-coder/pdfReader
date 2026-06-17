import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/book.dart';
import '../models/reading_theme.dart';
import '../services/paginator.dart';
import '../services/storage.dart';

class ReaderScreen extends StatefulWidget {
  final Book book;
  final Storage storage;
  const ReaderScreen({super.key, required this.book, required this.storage});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  static const _minFont = 14.0;
  static const _maxFont = 32.0;
  // Generous top/bottom keeps text clear of the notch/home indicator without a
  // SafeArea — whose insets would change when we hide the status bar and force
  // an unwanted re-pagination.
  static const _pagePadding =
      EdgeInsets.only(left: 24, right: 24, top: 44, bottom: 32);

  late double _fontSize;
  late ReadingTheme _theme;
  List<BookPage> _pages = [];
  int _currentPage = 0;
  PageController? _controller;
  Size? _lastArea;

  /// Whether the controls (top bar + page counter) are showing. Hidden on open
  /// for a distraction-free read; a single tap toggles it.
  bool _chromeVisible = false;

  // For passive tap detection that doesn't interfere with text selection.
  Offset _pointerDownPos = Offset.zero;
  int _pointerDownAt = 0;

  @override
  void initState() {
    super.initState();
    _fontSize = widget.storage.fontSize;
    _theme = widget.storage.readingTheme;
    _applySystemUi();
  }

  @override
  void dispose() {
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _applySystemUi() {
    // Hide the status/navigation bars while reading; reveal them with the
    // controls.
    SystemChrome.setEnabledSystemUIMode(
      _chromeVisible ? SystemUiMode.edgeToEdge : SystemUiMode.immersive,
    );
  }

  TextStyle get _textStyle =>
      TextStyle(fontSize: _fontSize, height: 1.5, color: _theme.text);

  /// (Re)paginate for the given content area, then restore the reading position
  /// by character offset so the user stays on the same words across font and
  /// screen-size changes.
  void _paginate(Size area) {
    final anchorOffset = _pages.isEmpty
        ? widget.book.lastCharOffset
        : _pages[_currentPage].startOffset;

    _pages = Paginator.paginate(
      text: widget.book.content,
      style: _textStyle,
      size: area,
    );
    _currentPage = Paginator.pageIndexForOffset(_pages, anchorOffset);
    _lastArea = area;

    _controller?.dispose();
    _controller = PageController(initialPage: _currentPage);
  }

  void _toggleChrome() {
    setState(() => _chromeVisible = !_chromeVisible);
    _applySystemUi();
  }

  /// Treat a short, near-stationary pointer press as a tap (toggles controls).
  /// Doing it here, rather than via GestureDetector.onTap, avoids competing
  /// with SelectableText's selection gestures and the PageView's swipe.
  void _onPointerDown(PointerDownEvent e) {
    _pointerDownPos = e.position;
    _pointerDownAt = DateTime.now().millisecondsSinceEpoch;
  }

  void _onPointerUp(PointerUpEvent e) {
    final elapsed = DateTime.now().millisecondsSinceEpoch - _pointerDownAt;
    final moved = (e.position - _pointerDownPos).distance;
    if (elapsed < 250 && moved < 12) _toggleChrome();
  }

  void _changeFont(double delta) {
    final next = (_fontSize + delta).clamp(_minFont, _maxFont);
    if (next == _fontSize) return;
    setState(() {
      _fontSize = next;
      if (_lastArea != null) _paginate(_lastArea!);
    });
    widget.storage.fontSize = next;
  }

  void _setTheme(ReadingTheme theme) {
    setState(() => _theme = theme);
    widget.storage.readingTheme = theme;
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    widget.book.lastCharOffset = _pages[index].startOffset;
  }

  void _addHighlight(int start, int end) {
    setState(
        () => widget.book.addHighlight(start, end, _theme.highlight.toARGB32()));
    widget.storage.saveBook(widget.book);
  }

  void _removeHighlight(int start, int end) {
    setState(() => widget.book.removeHighlightsIn(start, end));
    widget.storage.saveBook(widget.book);
  }

  Future<void> _saveAndLeave() async {
    if (_pages.isNotEmpty) {
      widget.book.lastCharOffset = _pages[_currentPage].startOffset;
    }
    await widget.storage.saveBook(widget.book);
    if (mounted) Navigator.pop(context);
  }

  /// Builds the text spans for a page, shading any characters covered by a
  /// highlight. Highlights are stored as global offsets, so we map them into
  /// this page's local range.
  List<TextSpan> _spansFor(BookPage page) {
    final base = page.startOffset;
    final text = page.text;
    final pageEnd = base + text.length;

    final relevant = widget.book.highlights
        .where((h) => h.overlaps(base, pageEnd))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final h in relevant) {
      final localStart = (h.start - base).clamp(0, text.length);
      final localEnd = (h.end - base).clamp(0, text.length);
      if (localEnd <= cursor) continue; // fully covered by a previous highlight
      final segStart = localStart < cursor ? cursor : localStart;
      if (segStart > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, segStart)));
      }
      spans.add(TextSpan(
        text: text.substring(segStart, localEnd),
        style: TextStyle(backgroundColor: Color(h.color)),
      ));
      cursor = localEnd;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }

  Widget _contextMenu(
      BuildContext context, EditableTextState editable, BookPage page) {
    final sel = editable.textEditingValue.selection;
    final items = <ContextMenuButtonItem>[];

    if (sel.isValid && !sel.isCollapsed) {
      final gStart = page.startOffset + sel.start;
      final gEnd = page.startOffset + sel.end;
      final overlapsHighlight =
          widget.book.highlights.any((h) => h.overlaps(gStart, gEnd));
      items.add(ContextMenuButtonItem(
        label: overlapsHighlight ? 'Remove highlight' : 'Highlight',
        onPressed: () {
          if (overlapsHighlight) {
            _removeHighlight(gStart, gEnd);
          } else {
            _addHighlight(gStart, gEnd);
          }
          editable.hideToolbar();
        },
      ));
    }
    items.addAll(editable.contextMenuButtonItems);

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editable.contextMenuAnchors,
      buttonItems: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _saveAndLeave();
      },
      child: Scaffold(
        backgroundColor: _theme.background,
        body: Stack(
          children: [
            // Full-screen reading surface.
            Positioned.fill(
              child: Listener(
                onPointerDown: _onPointerDown,
                onPointerUp: _onPointerUp,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final area = Size(
                      constraints.maxWidth - _pagePadding.horizontal,
                      constraints.maxHeight - _pagePadding.vertical,
                    );
                    if (_lastArea != area) _paginate(area);

                    return PageView.builder(
                      controller: _controller,
                      onPageChanged: _onPageChanged,
                      itemCount: _pages.length,
                      itemBuilder: (_, i) {
                        final page = _pages[i];
                        return Padding(
                          padding: _pagePadding,
                          child: SelectableText.rich(
                            TextSpan(
                                style: _textStyle, children: _spansFor(page)),
                            strutStyle: Paginator.strutFor(_textStyle),
                            contextMenuBuilder: (ctx, editable) =>
                                _contextMenu(ctx, editable, page),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            // Controls — slide in/out from the top edge.
            Positioned(top: 0, left: 0, right: 0, child: _topBar(context)),
            // Page counter — slides in/out from the bottom edge.
            Positioned(
                bottom: 0, left: 0, right: 0, child: _bottomBar(context)),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedSlide(
      duration: const Duration(milliseconds: 200),
      offset: _chromeVisible ? Offset.zero : const Offset(0, -1),
      child: IgnorePointer(
        ignoring: !_chromeVisible,
        child: Material(
          color: scheme.surface,
          elevation: 3,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: kToolbarHeight,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _saveAndLeave,
                  ),
                  Expanded(
                    child: Text(
                      widget.book.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Smaller text',
                    icon: const Text('A', style: TextStyle(fontSize: 16)),
                    onPressed: () => _changeFont(-2),
                  ),
                  IconButton(
                    tooltip: 'Larger text',
                    icon: const Text('A', style: TextStyle(fontSize: 22)),
                    onPressed: () => _changeFont(2),
                  ),
                  PopupMenuButton<ReadingTheme>(
                    tooltip: 'Reading theme',
                    icon: const Icon(Icons.palette_outlined),
                    initialValue: _theme,
                    onSelected: _setTheme,
                    itemBuilder: (_) => [
                      for (final t in ReadingTheme.values)
                        PopupMenuItem(
                          value: t,
                          child: Row(
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: t.background,
                                  border: Border.all(color: Colors.grey),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(t.label),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 200),
      offset: _chromeVisible ? Offset.zero : const Offset(0, 1),
      child: IgnorePointer(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _pages.isEmpty ? '' : '${_currentPage + 1} / ${_pages.length}',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: _theme.text.withValues(alpha: 0.6)),
            ),
          ),
        ),
      ),
    );
  }
}
