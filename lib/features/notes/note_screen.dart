import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ember/features/reader/reader_settings.dart';
import 'package:ember/features/reader/reflow.dart';
import 'package:ember/features/reader/widgets/icon_btn.dart';
import 'package:ember/providers/reader_provider.dart';
import 'package:ember/providers/storage_provider.dart';
import 'package:ember/services/storage_service.dart';
import 'package:ember/theme/app_colors.dart';

/// A book's notebook: one continuous text the reader writes in their own words
/// while reading, stored at `<docs>/books/<id>.note.txt`.
///
/// Two modes, toggled by the book icon in the top bar:
/// * **writing** — one [TextField] over a line grid, swiped page-by-page;
/// * **reading** — the same text run through the reader's reflow pipeline, so
///   notes are swiped page-by-page exactly like a book.
///
/// Both modes render with the live [ReaderSettings], so notes inherit the
/// theme, size, typeface and spacing chosen in the reader's "Aa" sheet, and
/// both turn pages horizontally — by swipe, or by the chevrons flanking the
/// page counter.
/// The height of one line of [style], measured the way a [TextField] lays it
/// out — its default strut, forced, so every line box is the same height.
///
/// `fontSize * lineSpacing` is the nominal value and it is not close enough:
/// the engine rounds a line box up (30.6 becomes 31.0), and a third of a pixel
/// per line puts a whole-line page grid out by two lines a few pages in.
@visibleForTesting
double measuredLineHeight(TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: ' ', style: style),
    strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
    textDirection: TextDirection.ltr,
  );
  final height = painter.preferredLineHeight;
  painter.dispose();
  return height;
}

/// Writing-mode page geometry for a text box [boxH] tall whose lines are each
/// [lineH] tall: how many whole lines fit, and the scroll offset one page turn
/// moves. Quantizing to whole lines is what stops a line from being sliced in
/// half across a page boundary.
@visibleForTesting
({int lines, double step}) notePageGrid(double boxH, double lineH) {
  if (lineH <= 0) return (lines: 1, step: 0);
  final lines = math.max(1, (boxH / lineH).floor());
  return (lines: lines, step: lines * lineH);
}

/// How many pages a writing body scrolls through. The body carries one full
/// viewport of trailing slack, so [maxScroll] is exactly the text's own height.
@visibleForTesting
int notePageCount(double maxScroll, double step) =>
    step <= 0 ? 1 : math.max(1, (maxScroll / step).ceil());

/// The page a caret reveal left the scroll view on, coming from [fromPage].
///
/// Typing forward stops with the caret's line as the *last* visible one — a
/// line into the next page — so a forward move rounds up; deleting backwards
/// puts that line at the top, so a backward move rounds down. `round()` is
/// wrong in both directions: a one-line forward reveal is far closer to the
/// page it just left than to the one the caret is now on.
@visibleForTesting
int notePageFor(double offset, int fromPage, double step) {
  if (step <= 0) return fromPage;
  final anchor = fromPage * step;
  if ((offset - anchor).abs() < 0.5) return fromPage;
  final page =
      offset > anchor ? (offset / step).ceil() : (offset / step).floor();
  return math.max(0, page);
}

class NoteScreen extends ConsumerStatefulWidget {
  const NoteScreen({super.key, required this.bookId, required this.title});

  final String bookId;
  final String title;

  @override
  ConsumerState<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends ConsumerState<NoteScreen>
    with WidgetsBindingObserver {
  /// How long typing pauses before the notebook is written to disk.
  static const _saveDebounce = Duration(milliseconds: 800);

  /// How long a page turn takes, in either mode.
  static const _turnDuration = Duration(milliseconds: 220);

  /// Captured while the element is still mounted. `ref` throws once it is
  /// defunct, and [dispose] runs the last save — reading the provider there
  /// would drop whatever was typed since the debounce last fired.
  late final StorageService _storage = ref.read(storageServiceProvider);

  final TextEditingController _controller = TextEditingController();
  final PageController _pageController = PageController();

  /// Writing mode's page scroll. Owned here rather than by the [TextField] so
  /// the body can carry a page of trailing slack (see [_buildWriting]).
  final ScrollController _scroll = ScrollController();

  /// False while the notebook is still being read off disk (never seed the
  /// field after the user has started typing).
  bool _loaded = false;

  /// True while reading mode is active (the book icon is lit).
  bool _reading = false;

  Timer? _saveTimer;

  /// The text as last written to disk, so an unchanged notebook never rewrites.
  String _saved = '';

  /// Reflow blocks for reading mode, rebuilt on each mode switch (not on every
  /// build) so swiping does not re-classify the whole notebook.
  List<Block> _blocks = const [];

  int _page = 0;
  int _pageCount = 1;

  /// Writing mode's line grid, recomputed in [_buildWriting] from the real box.
  double _step = 0;
  int _lines = 1;

  /// The first line index shown in writing mode. Re-anchoring by *line* rather
  /// than by page is what keeps the keyboard opening (which shrinks the box and
  /// so the page) from walking the view backwards.
  int _topLine = 0;

  /// Memo key for the writing grid: box size plus the layout-affecting reader
  /// settings. A change means the grid moved and the offset must be re-anchored.
  Object? _gridKey;

  /// [measuredLineHeight], memoized on the settings that affect it.
  double _lineH = 0;
  Object? _lineHKey;

  double _lineHeightFor(ReaderSettings settings) {
    final key = Object.hashAll(
        [settings.fontSize, settings.lineSpacing, settings.typeface]);
    if (key != _lineHKey) {
      _lineHKey = key;
      _lineH = measuredLineHeight(settings.bodyStyle());
    }
    return _lineH;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    unawaited(_save());
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _pageController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _saveTimer?.cancel();
      unawaited(_save());
    }
  }

  Future<void> _load() async {
    final text = await _storage.readNote(widget.bookId);
    if (!mounted) return;
    setState(() {
      _controller.text = text;
      _saved = text;
      _loaded = true;
    });
  }

  /// Writes the notebook to disk, unless nothing changed since the last write.
  Future<void> _save() async {
    if (!_loaded) return; // never overwrite the file with a pre-load empty field
    final text = _controller.text;
    if (text == _saved) return;
    _saved = text;
    await _storage.writeNote(widget.bookId, text);
  }

  void _onChanged(String _) {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounce, _save);
    // Typing in the middle of a note grows the body without ever scrolling it,
    // so the counter would go stale without this.
    WidgetsBinding.instance.addPostFrameCallback((_) => _settle());
  }

  /// Turns to [page] in whichever mode is showing.
  void _turnTo(int page) {
    if (!_reading) return _goTo(page);
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      page.clamp(0, _pageCount - 1),
      duration: _turnDuration,
      curve: Curves.easeOutCubic,
    );
  }

  /// Writing mode: animates the body to [page] on the line grid.
  void _goTo(int page) {
    if (!_scroll.hasClients || _step <= 0) return;
    final position = _scroll.position;
    final target = page.clamp(0, _pageCount - 1);
    if (target == _page && (position.pixels - target * _step).abs() < 0.5) {
      return;
    }
    setState(() {
      _page = target;
      _topLine = target * _lines;
    });
    position.animateTo(
      (target * _step).clamp(0.0, position.maxScrollExtent),
      duration: _turnDuration,
      curve: Curves.easeOutCubic,
    );
  }

  /// Runs after every writing-mode scroll settles: refreshes the page count and
  /// pulls the offset back onto the grid, because the caret reveal that follows
  /// a keystroke scrolls by whatever it takes to show the caret, not by a page.
  void _settle() {
    if (!mounted || _reading || !_scroll.hasClients || _step <= 0) return;
    // Don't yank the view out from under a selection handle drag.
    if (!_controller.selection.isCollapsed) return;
    final position = _scroll.position;
    final count = notePageCount(position.maxScrollExtent, _step);
    if (count != _pageCount) setState(() => _pageCount = count);
    final page = notePageFor(position.pixels, _page, _step);
    // Off the notification's own call stack: starting a scroll activity from
    // inside the one that just ended is what makes ScrollPosition assert.
    if (page != _page) Future.microtask(() => _goTo(page));
  }

  /// The grid moved (keyboard, rotation, re-entering writing mode with a fresh
  /// scroll position): keep the same top line rather than the same page number.
  ///
  /// ponytail: anchors on a line index, which is exact whenever [_step] changes
  /// but the line height doesn't — the keyboard and rotation cases. A font-size
  /// change would drift, and can't happen here: the "Aa" sheet lives in the
  /// reader, not on this screen.
  void _reanchor() {
    if (!mounted || !_scroll.hasClients || _step <= 0) return;
    final position = _scroll.position;
    final count = notePageCount(position.maxScrollExtent, _step);
    final page = (_topLine ~/ _lines).clamp(0, count - 1);
    setState(() {
      _pageCount = count;
      _page = page;
      _topLine = page * _lines;
    });
    position.jumpTo((page * _step).clamp(0.0, position.maxScrollExtent));
  }

  /// Book icon: flips between writing and reading mode, saving and re-flowing on
  /// the way in so reading mode always shows what was just typed.
  void _toggleMode() {
    _saveTimer?.cancel();
    unawaited(_save());
    FocusScope.of(context).unfocus();
    setState(() {
      _reading = !_reading;
      if (_reading) {
        _blocks = toBlocks(_controller.text.trim());
      } else {
        // Writing mode comes back with a fresh ScrollPosition; force a
        // re-anchor onto _topLine instead of inheriting reading mode's page.
        _gridKey = null;
      }
    });
  }

  void _back() {
    _saveTimer?.cancel();
    unawaited(_save());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final theme = settings.theme;

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        // Match the reader: measured layout and rendering both run at scale
        // 1.0, and the in-app "Aa" size is the only size control. The OS
        // text-spacing overrides go too — they would stretch a line past the
        // fontSize * lineSpacing the writing grid counts on.
        child: MediaQuery.withNoTextScaling(
          child: MediaQuery.applyTextStyleOverrides(
            lineHeightScaleFactorOverride: null,
            letterSpacingOverride: null,
            wordSpacingOverride: null,
            paragraphSpacingOverride: null,
            child: Column(
              children: [
                _TopBar(
                  title: widget.title,
                  inkColor: theme.ink,
                  reading: _reading,
                  onBack: _back,
                  onToggleMode: _loaded ? _toggleMode : null,
                ),
                Expanded(child: _buildBody(settings)),
                if (_loaded && !(_reading && _blocks.isEmpty))
                  _buildCounter(theme.ink),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// `‹ 3/12 ›` — the page counter, flanked by the chevrons that turn pages in
  /// both modes (a swipe is invisible affordance inside a text editor).
  Widget _buildCounter(Color ink) {
    Widget chevron(IconData icon, bool enabled, int page) => IconBtn(
          onTap: enabled ? () => _turnTo(page) : null,
          child: Icon(
            icon,
            size: 22,
            color: ink.withValues(alpha: enabled ? 0.75 : 0.2),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          chevron(Icons.chevron_left, _page > 0, _page - 1),
          SizedBox(
            width: 64,
            child: Text(
              '${_page + 1}/$_pageCount',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: ink.withValues(alpha: 0.75),
              ),
            ),
          ),
          chevron(Icons.chevron_right, _page < _pageCount - 1, _page + 1),
        ],
      ),
    );
  }

  Widget _buildBody(ReaderSettings settings) {
    final theme = settings.theme;
    if (!_loaded) {
      return Center(
        child: CircularProgressIndicator(
          color: theme.ink.withValues(alpha: 0.5),
        ),
      );
    }

    if (_reading) {
      if (_blocks.isEmpty) {
        return Padding(
          padding: kPagePadding,
          child: Center(
            child: Text(
              'Nothing written yet. Tap the book icon again and write what you '
              'understood, in your own words.',
              textAlign: TextAlign.center,
              style: settings.bodyStyle().copyWith(
                    color: theme.ink.withValues(alpha: 0.6),
                  ),
            ),
          ),
        );
      }
      return PagedBody(
        controller: _pageController,
        settings: settings,
        blocks: _blocks,
        marks: const [],
        // The controller keeps its offset across mode switches, so re-entering
        // reading mode resumes where it left off — read the page back off it
        // rather than assuming 0, or the counter desyncs from the view.
        onPaginated: (count) => setState(() {
          _pageCount = count;
          final resumed = _pageController.hasClients
              ? (_pageController.page?.round() ?? 0)
              : 0;
          _page = resumed.clamp(0, count - 1);
        }),
        onPageChanged: (i) => setState(() => _page = i),
      );
    }

    return _buildWriting(settings);
  }

  /// Writing mode: one [TextField] laid out at its natural height inside our
  /// own scroll view, whose offset is quantized to whole-line pages — so notes
  /// are written a page at a time and turned horizontally, like reading mode.
  Widget _buildWriting(ReaderSettings settings) {
    final theme = settings.theme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxHeight = constraints.maxHeight - kPagePadding.vertical;
        final grid = notePageGrid(boxHeight, _lineHeightFor(settings));
        _lines = grid.lines;
        _step = grid.step;

        // Keyed on the grid itself, not the raw box: the keyboard animates the
        // height for ~20 frames but only steps the line count a handful of
        // times, and re-anchoring on every frame of that fights the caret
        // reveal running alongside it.
        final key = Object.hashAll([constraints.maxWidth, grid.lines, grid.step]);
        if (key != _gridKey) {
          _gridKey = key;
          WidgetsBinding.instance.addPostFrameCallback((_) => _reanchor());
        }

        return Stack(
          children: [
            Padding(
              padding: kPagePadding,
              child: NotificationListener<ScrollNotification>(
                // depth 0 is this view; the field's own (zero-extent)
                // Scrollable reports depth 1.
                onNotification: (n) {
                  if (n is ScrollEndNotification && n.depth == 0) _settle();
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scroll,
                  physics: const _PagedOnlyScrollPhysics(),
                  child: Column(
                    children: [
                      TextField(
                        controller: _controller,
                        onChanged: _onChanged,
                        autofocus: true,
                        // A page-tall tap target on a short note; the field
                        // must stay natural-height, so no `expands`.
                        minLines: grid.lines,
                        maxLines: null,
                        scrollPadding: EdgeInsets.zero,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: settings.bodyStyle(),
                        cursorColor: AppColors.ember,
                        decoration: InputDecoration.collapsed(
                          hintText: 'Write it in your own words…',
                          hintStyle: settings.bodyStyle().copyWith(
                                color: theme.ink.withValues(alpha: 0.35),
                              ),
                        ),
                      ),
                      // One viewport of trailing slack, so maxScrollExtent is
                      // exactly the text's height and the last page lands on
                      // the grid instead of stopping short and repeating lines.
                      SizedBox(height: math.max(0, boxHeight)),
                    ],
                  ),
                ),
              ),
            ),
            // Topmost + translucent: Stack hit-tests its last child first, so
            // this recognizer is routed before the TextField's own
            // TapAndHorizontalDragGestureRecognizer and wins the arena on
            // Android (an *ancestor* detector loses it). Taps, long-press and
            // the selection handles still reach the field underneath.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  // ponytail: velocity only. Add a distance fallback if slow
                  // drags feel stuck.
                  if (velocity.abs() < 100) return;
                  _goTo(_page + (velocity < 0 ? 1 : -1));
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Blocks the user's own vertical drag while leaving programmatic and
/// caret-reveal scrolling alive. [NeverScrollableScrollPhysics] would not do:
/// it also sets `allowImplicitScrolling: false`, which makes
/// `RenderEditable.showOnScreen` a no-op and strands the caret off-screen.
class _PagedOnlyScrollPhysics extends ScrollPhysics {
  const _PagedOnlyScrollPhysics({super.parent});

  @override
  _PagedOnlyScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _PagedOnlyScrollPhysics(parent: buildParent(ancestor));

  @override
  bool get allowUserScrolling => false;
}

/// Back · the centered book title + "Notes" · the book icon that toggles
/// reading mode (lit while reading mode is on).
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.inkColor,
    required this.reading,
    required this.onBack,
    required this.onToggleMode,
  });

  final String title;
  final Color inkColor;
  final bool reading;
  final VoidCallback onBack;
  final VoidCallback? onToggleMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Row(
        children: [
          IconBtn(
            onTap: onBack,
            child: Icon(Icons.chevron_left, size: 24, color: inkColor),
          ),
          Expanded(
            child: Text(
              '$title · Notes',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: inkColor.withValues(alpha: 0.7),
              ),
            ),
          ),
          IconBtn(
            onTap: onToggleMode,
            child: Icon(
              Icons.menu_book_rounded,
              size: 21,
              color: reading ? AppColors.ember : inkColor,
            ),
          ),
        ],
      ),
    );
  }
}
