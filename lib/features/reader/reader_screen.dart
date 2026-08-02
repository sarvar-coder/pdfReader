import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ember/features/reader/reader_settings.dart';
import 'package:ember/features/reader/widgets/selection_toolbar.dart';
import 'package:ember/features/reader/widgets/settings_sheet.dart';
import 'package:ember/models/book.dart';
import 'package:ember/models/bookmark.dart';
import 'package:ember/models/highlight.dart';
import 'package:ember/models/reading_session.dart';
import 'package:ember/providers/bookmarks_provider.dart';
import 'package:ember/providers/highlights_provider.dart';
import 'package:ember/providers/library_provider.dart';
import 'package:ember/providers/reader_provider.dart';
import 'package:ember/providers/sessions_provider.dart';
import 'package:ember/services/pdf_service.dart';
import 'package:ember/theme/app_colors.dart';
import 'package:ember/widgets/empty_state.dart';

/// A run of text to paint with a highlight background.
typedef _Mark = ({String text, Color color});

/// A reflow block: a justified body paragraph, or a centered bold heading in
/// one of two tiers — a [title] (chapter/section) or a smaller [subtitle].
enum _BlockKind { title, subtitle, body }

/// The heading tier a single line is classified as (or [none] for body).
enum _HeadingLevel { title, subtitle, none }

class _Block {
  const _Block(this.kind, this.text);
  final _BlockKind kind;
  final String text;
}

/// A slice of a [_Block] that lands on a single page.
class _Frag {
  const _Frag({
    required this.kind,
    required this.text,
    required this.isFirst,
    required this.isLast,
  });
  final _BlockKind kind;
  final String text;

  /// First slice of its block (apply the indent / heading top-gap).
  final bool isFirst;

  /// Last slice of its block (the paragraph ends here, not split further).
  final bool isLast;
}

/// First-line indent prepended to body paragraphs (two em-spaces).
const String _kIndent = '  ';

/// Title style: the body style, bold and noticeably larger.
TextStyle _titleStyle(ReaderSettings s) => s.bodyStyle().copyWith(
      fontWeight: FontWeight.w700,
      fontSize: s.fontSize * 1.25,
      height: 1.3,
    );

/// Subtitle style: bold and only a touch larger than body.
TextStyle _subtitleStyle(ReaderSettings s) => s.bodyStyle().copyWith(
      fontWeight: FontWeight.w600,
      fontSize: s.fontSize * 1.08,
      height: 1.3,
    );

/// Section keywords that mark a title line (case-insensitive, at line start).
final RegExp _kTitleKeyword = RegExp(
  r'^(chapter|part|book|volume|section|prologue|epilogue|introduction|'
  r'foreword|preface|afterword|appendix|contents|conclusion|dedication|'
  r'acknowledg)',
  caseSensitive: false,
);
final RegExp _kRomanOnly = RegExp(r'^[IVXLCDM]{1,7}\.?$');
final RegExp _kNumberOnly = RegExp(r'^\d{1,4}\.?$');
final RegExp _kNumberedSection =
    RegExp(r'^\d+([.)]\d+)+[.)]?(\s.{0,50})?$|^\d+[.)]\s+\S.{0,48}$');

/// Fraction of cased letters that are uppercase (0 when there are none).
double _upperRatio(String t) {
  var cased = 0;
  var upper = 0;
  for (final ch in t.split('')) {
    final lo = ch.toLowerCase();
    final up = ch.toUpperCase();
    if (lo == up) continue; // not a cased letter
    cased++;
    if (ch == up) upper++;
  }
  return cased < 2 ? 0 : upper / cased;
}

/// True when most words in [t] start with an uppercase letter (Title Case).
bool _isTitleCase(String t) {
  final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return false;
  var caps = 0;
  for (final w in words) {
    final c = w[0];
    if (c.toUpperCase() == c && c.toLowerCase() != c) caps++;
  }
  return caps / words.length >= 0.6;
}

/// Classifies a single [line] as a heading tier (or [none] for body). When
/// [allowTitleCase] is false, a plain Title-Case line is treated as body (only
/// applied for standalone lines or lines right under another heading).
_HeadingLevel _classifyLine(String line, {required bool allowTitleCase}) {
  final t = line.trim();
  if (t.isEmpty || t.length > 64) return _HeadingLevel.none;
  final endsSentence = RegExp(r'[.!?]$').hasMatch(t);

  // Titles: a lone roman/number marker; a short section-keyword line (guarded
  // by length + punctuation so a body line like "Part of the reason…" is not
  // caught); or an all-caps line.
  if (_kRomanOnly.hasMatch(t) ||
      _kNumberOnly.hasMatch(t) ||
      (_kTitleKeyword.hasMatch(t) && t.length <= 30 && !endsSentence) ||
      (_upperRatio(t) >= 0.8 && !endsSentence)) {
    return _HeadingLevel.title;
  }

  // Subtitles: numbered sections, or (when allowed) short Title-Case lines.
  if (_kNumberedSection.hasMatch(t) && !RegExp(r'[.!?]$').hasMatch(t)) {
    return _HeadingLevel.subtitle;
  }
  if (allowTitleCase &&
      t.length <= 48 &&
      !RegExp(r'[.!?:;,]$').hasMatch(t) &&
      _isTitleCase(t)) {
    return _HeadingLevel.subtitle;
  }
  return _HeadingLevel.none;
}

/// Turns extracted text into [_Block]s. Works line-by-line within blank-line
/// groups so a heading line is split off from the body that follows it (even
/// with no blank line between); wrapped body lines are re-joined into
/// paragraphs carrying a first-line indent (so layout == render).
List<_Block> _toBlocks(String text) {
  final result = <_Block>[];
  final groups = text.split(RegExp(r'\n[ \t]*\n'));

  for (final group in groups) {
    final lines = [
      for (final l in group.split('\n'))
        if (l.trim().isNotEmpty) l.trim(),
    ];
    if (lines.isEmpty) continue;
    final standalone = lines.length == 1;

    var buffer = <String>[];
    void flushBody() {
      if (buffer.isNotEmpty) {
        result.add(_Block(_BlockKind.body, '$_kIndent${buffer.join(' ')}'));
        buffer = <String>[];
      }
    }

    var prevHeading = false;
    for (final line in lines) {
      final level = _classifyLine(
        line,
        allowTitleCase: standalone || prevHeading,
      );
      switch (level) {
        case _HeadingLevel.title:
          flushBody();
          result.add(_Block(_BlockKind.title, line));
          prevHeading = true;
        case _HeadingLevel.subtitle:
          flushBody();
          result.add(_Block(_BlockKind.subtitle, line));
          prevHeading = true;
        case _HeadingLevel.none:
          buffer.add(line);
          prevHeading = false;
      }
    }
    flushBody();
  }

  if (result.isEmpty) result.add(_Block(_BlockKind.body, text));
  return result;
}

/// The Reader screen. Top/bottom chrome that hides on a page tap, the imported
/// PDF's extracted text reflowed in the chosen typeface, an "Aa" settings sheet
/// that live-updates the text, and a visual selection toolbar on long-press.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, this.onBack});

  /// Returns to the Library (the top-chrome back button).
  final VoidCallback? onBack;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  bool _chromeVisible = true;
  bool _sheetOpen = false;

  /// The latest selected text, captured from the [SelectionArea].
  String? _selectedText;

  // ── Reading-session recording ───────────────────────────────────────────
  String? _sessionBookId;
  DateTime? _sessionStart;
  int _sessionStartPage = 0;

  // ── Reading-position tracking (horizontal page paging) ──────────────────
  final PageController _pageController = PageController();

  /// Number of reflowed, screen-sized pages in the open book (set by the body
  /// once it paginates). 1 until the first pagination.
  int _pageCount = 1;

  /// The live reading position as a 0.0–1.0 fraction (font-independent), kept in
  /// sync as the user swipes so a re-pagination (font/size change) can realign.
  double _currentFraction = 0;

  /// Id of the book we're currently tracking position for.
  String? _positionBookId;

  /// Target fraction to jump to once the pages are laid out (book open / a
  /// bookmark tap), and a flag so we only consume it once.
  double _pendingRestoreFraction = 0;
  bool _needsRestore = false;

  /// Whether the open book has a real PDF (only those track/restore position).
  bool _hasPdf = false;

  /// Current reflowed page index (drives the bottom counter + slider).
  int _currentPage = 0;

  /// Plain text of each reflowed page, for the slider count and in-book search.
  List<String> _pageTexts = const [];

  /// Reflow blocks for the open book, rebuilt only when the book changes (so
  /// their cached string hashCodes keep the pagination memo cheap).
  List<_Block> _blocks = const [];
  String? _blocksBookId;

  // ── In-book search ──────────────────────────────────────────────────────
  bool _searchOpen = false;
  String _query = '';
  List<int> _matches = const [];
  int _matchPos = 0;
  final TextEditingController _searchCtl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _endSession();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _searchCtl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _endSession();
    } else if (state == AppLifecycleState.resumed && _sessionBookId == null) {
      final book = ref.read(currentBookProvider);
      if (book != null && ref.read(currentPdfPathProvider) != null) {
        _startSession(book);
      }
    }
  }

  /// Begins timing a reading session for [book] (real PDFs only).
  void _startSession(Book book) {
    _sessionBookId = book.id;
    _sessionStart = DateTime.now();
    _sessionStartPage = book.currentPage;
  }

  /// Persists the active session (minutes read + pages advanced), if any.
  void _endSession() {
    final id = _sessionBookId;
    final start = _sessionStart;
    _sessionBookId = null;
    _sessionStart = null;
    if (id == null || start == null) return;

    final now = DateTime.now();
    final minutes = now.difference(start).inMinutes;
    var endPage = _sessionStartPage;
    for (final b in ref.read(libraryProvider)) {
      if (b.id == id) {
        endPage = b.currentPage;
        break;
      }
    }
    final pagesRead = (endPage - _sessionStartPage).clamp(0, 1 << 30);
    if (minutes <= 0 && pagesRead <= 0) return; // ignore trivial opens

    ref.read(readingSessionsProvider.notifier).add(
          ReadingSession(
            id: 'rs-${now.microsecondsSinceEpoch}',
            bookId: id,
            startedAt: start,
            endedAt: now,
            pagesRead: pagesRead,
            minutes: minutes,
          ),
        );
  }

  /// Called by the paged body when a swipe settles on [index]. Persists the
  /// position as a font-independent fraction (unless we're mid-restore).
  void _onPageChanged(int index) {
    final frac =
        _pageCount <= 1 ? 0.0 : (index / (_pageCount - 1)).clamp(0.0, 1.0);
    _currentFraction = frac;
    if (mounted) setState(() => _currentPage = index);
    final id = _positionBookId;
    if (!_hasPdf || id == null || _needsRestore) return;
    ref.read(libraryProvider.notifier).updateReadingPosition(id, frac);
  }

  /// Slider seek → jump to [page]; [_onPageChanged] then updates state + saves.
  void _seekTo(int page) {
    if (_pageCount <= 1 || !_pageController.hasClients) return;
    _pageController.jumpToPage(page.clamp(0, _pageCount - 1));
  }

  /// Persists the current position immediately (used when leaving the reader).
  void _savePosition() {
    final id = _positionBookId;
    if (!_hasPdf || id == null) return;
    ref.read(libraryProvider.notifier).updateReadingPosition(id, _currentFraction);
  }

  /// Called by the paged body whenever it (re)paginates. [pageTexts] is the
  /// plain text of each reflowed page (used by the slider count + search).
  /// Jumps to the pending restore target on a fresh open / bookmark tap, or
  /// realigns to the current fraction when a font/size change re-flowed pages.
  void _onPaginated(List<String> pageTexts) {
    setState(() {
      _pageTexts = pageTexts;
      _pageCount = pageTexts.length;
      _currentPage = _pageForFraction(_currentFraction);
    });
    if (_searchOpen) _computeMatches();
    if (_needsRestore) {
      _scheduleJumpIfNeeded();
    } else {
      _jumpToFraction(_currentFraction);
    }
  }

  /// Jumps to [fraction]'s page once the pages are laid out (book open / a
  /// bookmark tap), consuming the one-shot restore.
  void _scheduleJumpIfNeeded() {
    if (!_hasPdf || !_needsRestore) return;
    final frac = _pendingRestoreFraction;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_needsRestore || !_pageController.hasClients) return;
      final target = _pageForFraction(frac);
      _pageController.jumpToPage(target);
      _currentFraction = frac;
      _needsRestore = false;
      setState(() => _currentPage = target);
      // Consume a one-shot bookmark jump, if any.
      if (ref.read(pendingJumpProvider) != null) {
        ref.read(pendingJumpProvider.notifier).clear();
      }
    });
  }

  /// Realigns the controller to [fraction] without consuming a restore (used
  /// after a re-pagination so the reader stays put across font/size changes).
  void _jumpToFraction(double fraction) {
    final target = _pageForFraction(fraction);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      if (_pageController.page?.round() != target) {
        _pageController.jumpToPage(target);
      }
      if (_currentPage != target) setState(() => _currentPage = target);
    });
  }

  /// Maps a 0.0–1.0 reading [fraction] to a page index in `[0, _pageCount)`.
  int _pageForFraction(double fraction) {
    if (_pageCount <= 1) return 0;
    return (fraction.clamp(0.0, 1.0) * (_pageCount - 1))
        .round()
        .clamp(0, _pageCount - 1);
  }

  // ── In-book search ──────────────────────────────────────────────────────
  void _openSearch() {
    setState(() => _searchOpen = true);
    _searchFocus.requestFocus();
  }

  void _closeSearch() {
    _searchFocus.unfocus();
    setState(() {
      _searchOpen = false;
      _query = '';
      _matches = const [];
      _matchPos = 0;
      _searchCtl.clear();
    });
  }

  /// Recomputes the list of page indices whose text contains the query.
  void _computeMatches() {
    final q = _query.trim().toLowerCase();
    _matches = q.isEmpty
        ? const []
        : [
            for (var i = 0; i < _pageTexts.length; i++)
              if (_pageTexts[i].toLowerCase().contains(q)) i,
          ];
  }

  void _onSearchChanged(String value) {
    setState(() {
      _query = value;
      _computeMatches();
    });
    if (_matches.isEmpty) return;
    // Jump to the match nearest the current page.
    var best = 0;
    var bestDist = 1 << 30;
    for (var i = 0; i < _matches.length; i++) {
      final d = (_matches[i] - _currentPage).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    setState(() => _matchPos = best);
    _seekTo(_matches[best]);
  }

  void _stepMatch(int dir) {
    if (_matches.isEmpty) return;
    setState(() => _matchPos = (_matchPos + dir) % _matches.length);
    if (_matchPos < 0) setState(() => _matchPos += _matches.length);
    _seekTo(_matches[_matchPos]);
  }

  /// Opens a sheet of the open book's bookmarks and highlights; tapping any of
  /// them jumps to its page.
  void _openContents(Book book) {
    final marks = ref
        .read(bookmarksProvider)
        .where((b) => b.bookId == book.id)
        .toList()
      ..sort((a, b) => a.page.compareTo(b.page));
    final highlights = ref
        .read(highlightsProvider)
        .where((h) => h.bookId == book.id)
        .toList()
      ..sort((a, b) => a.page.compareTo(b.page));
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ContentsSheet(
        bookmarks: marks,
        highlights: highlights,
        onJump: (page) {
          if (book.totalPages > 0) {
            ref.read(pendingJumpProvider.notifier).to(page / book.totalPages);
          }
          Navigator.pop(sheetContext);
        },
      ),
    );
  }

  void _onPageTap() => setState(() => _chromeVisible = !_chromeVisible);

  /// Saves a bookmark at the current page of the open book.
  void _addBookmark() {
    final book = ref.read(currentBookProvider);
    if (book == null) return;
    ref.read(bookmarksProvider.notifier).add(
          Bookmark(
            id: 'bm-${DateTime.now().microsecondsSinceEpoch}',
            bookId: book.id,
            page: book.currentPage,
            chapter: book.chapter ?? 'Page ${book.currentPage}',
            note: book.title,
          ),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bookmarked page ${book.currentPage}')),
    );
  }

  /// Saves the current text selection as a highlight in [color].
  void _saveHighlight(Color color) {
    final raw = _selectedText?.trim();
    final book = ref.read(currentBookProvider);
    if (raw == null || raw.isEmpty || book == null) return;
    // Collapse whitespace so the quote matches the reflowed page text.
    final quote = raw.replaceAll(RegExp(r'\s+'), ' ');

    ref.read(highlightsProvider.notifier).add(
          Highlight(
            id: 'hl-${DateTime.now().microsecondsSinceEpoch}',
            bookId: book.id,
            quote: quote,
            colorValue: color.toARGB32(),
            page: book.currentPage,
            chapter: book.chapter ?? '',
          ),
        );
    _selectedText = null;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Highlight saved')),
    );
  }

  /// Custom selection menu: the four color swatches, anchored above the
  /// selection.
  Widget _buildHighlightMenu(
    BuildContext context,
    SelectableRegionState selState,
  ) {
    final anchor = selState.contextMenuAnchors.primaryAnchor;
    final width = MediaQuery.sizeOf(context).width;
    final topInset = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        Positioned(
          left: (anchor.dx - 110).clamp(8.0, math.max(8.0, width - 228)),
          top: math.max(anchor.dy - 56, topInset + 8),
          child: SelectionToolbar(
            onPick: (color) {
              _saveHighlight(color);
              selState.hideToolbar();
              selState.clearSelection();
            },
            onDismiss: () {
              selState.hideToolbar();
              selState.clearSelection();
            },
          ),
        ),
      ],
    );
  }

  /// Chooses what the page shows: a spinner while parsing, a notice when the
  /// book's PDF is missing, an empty-text notice for scanned PDFs, or the
  /// reflowed extracted text.
  Widget _buildPage(
    AsyncValue<PdfContent?> contentAsync,
    ReaderSettings settings,
    Color ink,
    List<_Mark> marks,
  ) {
    return contentAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: ink.withValues(alpha: 0.5)),
      ),
      error: (e, _) => _PageBody(
        settings: settings,
        paragraphs: ['Couldn’t read this PDF.', '$e'],
      ),
      data: (content) {
        if (content == null) {
          // Book row exists but its PDF file is missing on disk.
          return _PageBody(
            settings: settings,
            paragraphs: const [
              'This book’s PDF is missing. Re-import it from your shelf.',
            ],
          );
        }
        final text = content.fullText.trim();
        if (text.isEmpty) {
          return _PageBody(
            settings: settings,
            paragraphs: const [
              'No selectable text found in this PDF. '
                  'It may be made of scanned images.',
            ],
          );
        }
        // Real content → reflow into justified, screen-sized pages. Blocks are
        // rebuilt only when the book changes (stable instances keep the
        // pagination memo cheap across swipes/setStates).
        if (_blocksBookId != _positionBookId) {
          _blocks = _toBlocks(text);
          _blocksBookId = _positionBookId;
        }
        return _PagedBody(
          controller: _pageController,
          settings: settings,
          blocks: _blocks,
          marks: marks,
          onPaginated: _onPaginated,
          onPageChanged: _onPageChanged,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final theme = settings.theme;
    final book = ref.watch(currentBookProvider);

    // No book in the library (e.g. after deleting everything) → show an empty
    // reader with an import prompt.
    if (book == null) {
      _positionBookId = null;
      return Scaffold(
        backgroundColor: theme.bg,
        body: const SafeArea(
          child: Center(
            child: EmptyState(
              icon: Icons.auto_stories_outlined,
              title: 'Nothing open yet',
              subtitle: 'Import a PDF from your shelf to start reading. '
                  'Your place is saved automatically.',
            ),
          ),
        ),
      );
    }

    final contentAsync = ref.watch(readerContentProvider);
    _hasPdf = ref.watch(currentPdfPathProvider) != null;

    // Saved highlights for the open book, painted onto the extracted text.
    final marks = <_Mark>[
      for (final h in ref.watch(highlightsProvider))
        if (h.bookId == book.id)
          (text: h.quote, color: h.color.withValues(alpha: 0.4)),
    ];

    // A different book is open → set up to restore its saved position and start
    // a fresh reading session (ending the previous one).
    if (book.id != _positionBookId) {
      _positionBookId = book.id;
      _pendingRestoreFraction = book.readingFraction;
      _currentFraction = book.readingFraction;
      _needsRestore = _hasPdf;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _endSession();
        final b = ref.read(currentBookProvider);
        if (b != null && ref.read(currentPdfPathProvider) != null) {
          _startSession(b);
        }
      });
    }

    // A bookmark/highlight tap requested a jump → override the restore target.
    final pendingJump = ref.watch(pendingJumpProvider);
    if (pendingJump != null && _hasPdf) {
      _pendingRestoreFraction = pendingJump;
      _needsRestore = true;
    } else if (pendingJump != null) {
      // Target book has no scrollable PDF (missing file) — drop it so it
      // can't leak onto the next real book opened.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(pendingJumpProvider.notifier).clear();
      });
    }

    // If the pages are already laid out (e.g. a bookmark tap on the open book),
    // jump now; a fresh open is handled later by [_onPaginated].
    _scheduleJumpIfNeeded();

    final title = book.title;
    return Scaffold(
      backgroundColor: theme.bg,
      body: Stack(
        children: [
          // ── Page + chrome ──────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            color: theme.bg,
            child: SafeArea(
              child: Column(
                children: [
                  _TopChrome(
                    visible: _chromeVisible,
                    title: title,
                    inkColor: theme.ink,
                    onBack: () {
                      _savePosition();
                      widget.onBack?.call();
                    },
                    onBookmark: _addBookmark,
                    onSearch: _openSearch,
                    onSettings: () => setState(() => _sheetOpen = true),
                  ),
                  Expanded(
                    child: SelectionArea(
                      onSelectionChanged: (value) =>
                          _selectedText = value?.plainText,
                      contextMenuBuilder: _buildHighlightMenu,
                      child: GestureDetector(
                        onTap: _onPageTap,
                        behavior: HitTestBehavior.deferToChild,
                        child: _buildPage(contentAsync, settings, theme.ink, marks),
                      ),
                    ),
                  ),
                  _BottomChrome(
                    visible: _chromeVisible && !_searchOpen,
                    inkColor: theme.ink,
                    pageIndex: _currentPage,
                    pageCount: _pageCount,
                    // Label shows real PDF pages; slider stays in reflow pages.
                    labelTotal: book.totalPages > 0 ? book.totalPages : _pageCount,
                    labelPage: book.totalPages > 0
                        ? (_currentFraction * (book.totalPages - 1)).round() + 1
                        : _currentPage + 1,
                    onSeek: _seekTo,
                    onContents: () => _openContents(book),
                  ),
                ],
              ),
            ),
          ),

          // ── Search bar (slides in from the top) ────────────────────────
          Align(
            alignment: Alignment.topCenter,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              offset: _searchOpen ? Offset.zero : const Offset(0, -1),
              child: SafeArea(
                bottom: false,
                child: _SearchBar(
                  controller: _searchCtl,
                  focusNode: _searchFocus,
                  inkColor: theme.ink,
                  background: theme.bg,
                  matchPos: _matches.isEmpty ? 0 : _matchPos + 1,
                  matchCount: _matches.length,
                  onChanged: _onSearchChanged,
                  onPrev: () => _stepMatch(-1),
                  onNext: () => _stepMatch(1),
                  onClose: _closeSearch,
                ),
              ),
            ),
          ),

          // ── Settings sheet + scrim ─────────────────────────────────────
          IgnorePointer(
            ignoring: !_sheetOpen,
            child: GestureDetector(
              onTap: () => setState(() => _sheetOpen = false),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _sheetOpen ? 1 : 0,
                child: const ColoredBox(
                  color: Color(0x661C140C),
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 340),
              curve: Curves.easeOutCubic,
              offset: _sheetOpen ? Offset.zero : const Offset(0, 1),
              child: SettingsSheet(
                settings: settings,
                onChanged: (s) =>
                    ref.read(readerSettingsProvider.notifier).update(s),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Back · centered title · bookmark · search · Aa. Fades/slides out when hidden.
class _TopChrome extends StatelessWidget {
  const _TopChrome({
    required this.visible,
    required this.title,
    required this.inkColor,
    this.onBack,
    this.onBookmark,
    this.onSearch,
    this.onSettings,
  });

  final bool visible;
  final String title;
  final Color inkColor;
  final VoidCallback? onBack;
  final VoidCallback? onBookmark;
  final VoidCallback? onSearch;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    return _ChromeAnimator(
      visible: visible,
      slideUp: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
        child: Row(
          children: [
            _IconBtn(
              onTap: onBack,
              child: Icon(Icons.chevron_left, size: 24, color: inkColor),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: inkColor.withValues(alpha: 0.7),
                ),
              ),
            ),
            _IconBtn(
              onTap: onBookmark,
              child: Icon(Icons.bookmark_border, size: 20, color: inkColor),
            ),
            _IconBtn(
              onTap: onSearch,
              child: Icon(Icons.search, size: 21, color: inkColor),
            ),
            _IconBtn(
              onTap: onSettings,
              child: Text(
                'Aa',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: inkColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page counter (`current/total`) + a draggable seek slider + a contents
/// button. Fades/slides out when chrome hides.
class _BottomChrome extends StatelessWidget {
  const _BottomChrome({
    required this.visible,
    required this.inkColor,
    required this.pageIndex,
    required this.pageCount,
    required this.labelPage,
    required this.labelTotal,
    required this.onSeek,
    required this.onContents,
  });

  final bool visible;
  final Color inkColor;
  final int pageIndex;
  final int pageCount;

  /// Real PDF page number / total for the counter label (the slider still runs
  /// on the reflow-page [pageIndex]/[pageCount]).
  final int labelPage;
  final int labelTotal;
  final ValueChanged<int> onSeek;
  final VoidCallback onContents;

  @override
  Widget build(BuildContext context) {
    final hasPages = pageCount > 1;
    final maxV = hasPages ? (pageCount - 1).toDouble() : 1.0;
    final value = pageIndex.toDouble().clamp(0.0, maxV);
    final label = labelTotal > 0 ? '$labelPage/$labelTotal' : '';
    return _ChromeAnimator(
      visible: visible,
      slideUp: false,
      child: Padding(
        // Reader is a full-screen route (no nav bar); the body SafeArea already
        // clears the system inset, so only a small bottom pad is needed.
        padding: const EdgeInsets.fromLTRB(18, 4, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: inkColor.withValues(alpha: 0.75),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      activeTrackColor: AppColors.ember,
                      inactiveTrackColor: inkColor.withValues(alpha: 0.15),
                      thumbColor: AppColors.ember,
                      overlayColor: AppColors.ember.withValues(alpha: 0.15),
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 15),
                    ),
                    child: Slider(
                      value: value,
                      max: maxV,
                      onChanged:
                          hasPages ? (v) => onSeek(v.round()) : null,
                    ),
                  ),
                ),
                _IconBtn(
                  onTap: onContents,
                  child: Icon(
                    Icons.format_list_bulleted,
                    size: 20,
                    color: inkColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Animates chrome opacity + a small slide, and disables hit-testing when hidden.
class _ChromeAnimator extends StatelessWidget {
  const _ChromeAnimator({
    required this.visible,
    required this.slideUp,
    required this.child,
  });

  final bool visible;
  final bool slideUp;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hiddenOffset = slideUp ? const Offset(0, -8) : const Offset(0, 8);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        offset: visible ? Offset.zero : hiddenOffset / 38,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: visible ? 1 : 0,
          child: child,
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 38,
        height: 38,
        child: Center(child: child),
      ),
    );
  }
}

/// A simple scrollable reading page for the short, non-paged cases (the "no
/// selectable text" notice, missing-PDF and parse errors): the reflowed
/// paragraphs.
class _PageBody extends StatelessWidget {
  const _PageBody({
    required this.settings,
    required this.paragraphs,
  });

  final ReaderSettings settings;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withNoTextScaling(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 14, 26, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final paragraph in paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _Paragraph(
                  text: paragraph,
                  settings: settings,
                  align: TextAlign.justify,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The horizontally-swiped reading view. Reflows [body] into screen-sized pages
/// (one per swipe, no inner scroll) by measuring the text against the available
/// box, then re-measures whenever the box or the reader [settings] change.
class _PagedBody extends StatefulWidget {
  const _PagedBody({
    required this.controller,
    required this.settings,
    required this.blocks,
    required this.marks,
    required this.onPaginated,
    required this.onPageChanged,
  });

  final PageController controller;
  final ReaderSettings settings;
  final List<_Block> blocks;
  final List<_Mark> marks;

  /// Reports each reflowed page's plain text after (re)pagination, so the
  /// parent can drive the slider count + search and restore the position.
  final ValueChanged<List<String>> onPaginated;
  final ValueChanged<int> onPageChanged;

  @override
  State<_PagedBody> createState() => _PagedBodyState();
}

class _PagedBodyState extends State<_PagedBody> {
  static const _pad = EdgeInsets.fromLTRB(26, 14, 26, 24);

  /// Heading top/bottom margins as a multiple of the font size, per tier.
  static const _titleTop = 0.9;
  static const _titleBottom = 0.4;
  static const _subTop = 0.25;
  static const _subBottom = 0.5;

  List<List<_Frag>> _pages = const [[]];

  /// Memo key: re-paginate only when the box size, the text, or a layout-
  /// affecting setting actually changes (marks/theme color don't affect layout).
  Object? _key;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - _pad.horizontal;
        // Shave ~half a line of slack: continuation slices can re-wrap to one
        // extra line vs what _paginate measured, so leave headroom (the inner
        // scroll view below catches any remainder without an overflow stripe).
        final slack = widget.settings.fontSize * widget.settings.lineSpacing * 0.5;
        final height =
            math.max(1.0, constraints.maxHeight - _pad.vertical - slack);
        final key = Object.hashAll([
          width,
          height,
          widget.settings.fontSize,
          widget.settings.lineSpacing,
          widget.settings.typeface,
          for (final b in widget.blocks) b.text,
        ]);
        if (key != _key) {
          _key = key;
          _pages = _paginate(widget.settings, widget.blocks, width, height);
          // Report each page's plain text to the parent after this frame.
          final texts = [
            for (final frags in _pages) frags.map((f) => f.text).join(' '),
          ];
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onPaginated(texts);
          });
        }

        // Render at scale 1.0 to match [_paginate]'s TextPainter (which has no
        // scaler); the OS font scale would otherwise make text taller than
        // measured and overflow the page. The in-app "Aa" size is the control.
        return MediaQuery.withNoTextScaling(
          child: PageView.builder(
            controller: widget.controller,
            scrollDirection: Axis.horizontal,
            itemCount: _pages.length,
            onPageChanged: widget.onPageChanged,
            itemBuilder: (context, i) => Padding(
              padding: _pad,
              // Vertical scroll catches the rare few-px re-wrap overflow; the
              // horizontal PageView still owns the swipe (opposite axis).
              child: _ReaderPage(
                key: ValueKey('page-$i-${_pages.length}'),
                frags: _pages[i],
                background: widget.settings.theme.bg,
                ink: widget.settings.theme.ink,
                buildFrag: _buildFrag,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFrag(_Frag f) {
    final size = widget.settings.fontSize;
    if (f.kind != _BlockKind.body) {
      final isTitle = f.kind == _BlockKind.title;
      return Padding(
        padding: EdgeInsets.only(
          top: f.isFirst ? size * (isTitle ? _titleTop : _subTop) : 0,
          bottom: size * (isTitle ? _titleBottom : _subBottom),
        ),
        child: Text(
          f.text,
          textAlign: TextAlign.center,
          style: isTitle
              ? _titleStyle(widget.settings)
              : _subtitleStyle(widget.settings),
        ),
      );
    }
    return _Paragraph(
      text: f.text,
      settings: widget.settings,
      marks: widget.marks,
      align: TextAlign.justify,
    );
  }

  /// Lays out [blocks] into pages of [_Frag]s that each fill at most [height]
  /// at [width]. Body paragraphs split at line boundaries across pages; headings
  /// stay whole. No line is ever clipped.
  static List<List<_Frag>> _paginate(
    ReaderSettings settings,
    List<_Block> blocks,
    double width,
    double height,
  ) {
    final bodyStyle = settings.bodyStyle();
    final titleStyle = _titleStyle(settings);
    final subtitleStyle = _subtitleStyle(settings);
    final size = settings.fontSize;

    if (width <= 0 || height <= 0) {
      return [
        [
          for (final b in blocks)
            _Frag(kind: b.kind, text: b.text, isFirst: true, isLast: true),
        ],
      ];
    }

    final pages = <List<_Frag>>[];
    var current = <_Frag>[];
    var used = 0.0;

    void flush() {
      if (current.isNotEmpty) {
        pages.add(current);
        current = <_Frag>[];
        used = 0;
      }
    }

    for (final block in blocks) {
      final isBody = block.kind == _BlockKind.body;
      final isTitle = block.kind == _BlockKind.title;
      final style = isBody
          ? bodyStyle
          : isTitle
              ? titleStyle
              : subtitleStyle;
      final painter = TextPainter(
        text: TextSpan(text: block.text, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width);
      try {
        if (!isBody) {
          final topGap = size * (isTitle ? _titleTop : _subTop);
          final bottomGap = size * (isTitle ? _titleBottom : _subBottom);
          final blockHeight = topGap + painter.height + bottomGap;
          if (used > 0 && used + blockHeight > height) flush();
          current.add(_Frag(
            kind: block.kind,
            text: block.text,
            isFirst: true,
            isLast: true,
          ));
          used += blockHeight;
          continue;
        }

        final lines = painter.computeLineMetrics();
        if (lines.isEmpty) continue;

        // Char offset at the start of each line (line 0 starts at 0).
        final lineStart = <int>[0];
        var cum = 0.0;
        final lineTop = <double>[];
        for (final m in lines) {
          lineTop.add(cum);
          cum += m.height;
        }
        for (var i = 1; i < lines.length; i++) {
          lineStart.add(
            painter
                .getPositionForOffset(Offset(0, lineTop[i] + lines[i].height / 2))
                .offset,
          );
        }
        lineStart.add(block.text.length); // sentinel end

        var lineIdx = 0;
        var first = true;
        while (lineIdx < lines.length) {
          final remaining = height - used;
          var consumed = 0;
          var accH = 0.0;
          while (lineIdx + consumed < lines.length) {
            final lh = lines[lineIdx + consumed].height;
            if (accH + lh > remaining && (consumed > 0 || used > 0)) break;
            accH += lh;
            consumed++;
          }
          if (consumed == 0) {
            flush(); // nothing fits on this partial page → start fresh
            continue;
          }
          final start = lineStart[lineIdx];
          final end = lineStart[lineIdx + consumed];
          final isLast = lineIdx + consumed >= lines.length;
          var text = block.text.substring(start, end);
          if (!first) text = text.trimLeft(); // no indent on continuations
          current.add(_Frag(
            kind: _BlockKind.body,
            text: text,
            isFirst: first,
            isLast: isLast,
          ));
          used += accH;
          lineIdx += consumed;
          first = false;
          if (lineIdx < lines.length) flush(); // remainder goes to next page
        }
      } finally {
        painter.dispose();
      }
    }
    flush();
    return pages.isEmpty ? const [[]] : pages;
  }
}

/// One swipeable reading page. Vertically scrollable to absorb the occasional
/// re-wrap overflow, and shows a bottom fade + down-chevron cue while there is
/// still content below the fold (so the last line is never silently cut off).
class _ReaderPage extends StatefulWidget {
  const _ReaderPage({
    super.key,
    required this.frags,
    required this.background,
    required this.ink,
    required this.buildFrag,
  });

  final List<_Frag> frags;
  final Color background;
  final Color ink;
  final Widget Function(_Frag) buildFrag;

  @override
  State<_ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<_ReaderPage> {
  final ScrollController _controller = ScrollController();
  bool _more = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// True while the page can still scroll down (content below the fold).
  void _sync() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    final more = pos.maxScrollExtent - pos.pixels > 1;
    if (more != _more && mounted) setState(() => _more = more);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (_) {
            _sync();
            return false;
          },
          child: SingleChildScrollView(
            controller: _controller,
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final f in widget.frags) widget.buildFrag(f),
              ],
            ),
          ),
        ),
        if (_more)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 30,
                alignment: Alignment.bottomCenter,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      widget.background.withValues(alpha: 0),
                      widget.background,
                    ],
                  ),
                ),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 20,
                  color: widget.ink.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Renders one paragraph, painting a background behind any [marks] whose text
/// occurs in it. Applies the live font/typeface/spacing via [ReaderSettings].
class _Paragraph extends StatelessWidget {
  const _Paragraph({
    required this.text,
    required this.settings,
    this.marks = const [],
    this.align = TextAlign.start,
  });

  final String text;
  final ReaderSettings settings;
  final List<_Mark> marks;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final base = settings.bodyStyle();
    if (marks.isEmpty) return Text(text, style: base, textAlign: align);

    // Collect every (start, end, color) range, then drop overlaps left-to-right.
    final ranges = <({int start, int end, Color color})>[];
    for (final mark in marks) {
      if (mark.text.isEmpty) continue;
      var idx = text.indexOf(mark.text);
      while (idx >= 0) {
        ranges.add((start: idx, end: idx + mark.text.length, color: mark.color));
        idx = text.indexOf(mark.text, idx + mark.text.length);
      }
    }
    if (ranges.isEmpty) return Text(text, style: base, textAlign: align);
    ranges.sort((a, b) => a.start.compareTo(b.start));

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final r in ranges) {
      if (r.start < cursor) continue; // overlaps an earlier mark
      if (r.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, r.start)));
      }
      spans.add(TextSpan(
        text: text.substring(r.start, r.end),
        style: TextStyle(backgroundColor: r.color),
      ));
      cursor = r.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return Text.rich(TextSpan(style: base, children: spans), textAlign: align);
  }
}

/// The in-book search bar: a query field, an `x/y` match counter, and up/down
/// chevrons to step through the pages that contain the query.
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.inkColor,
    required this.background,
    required this.matchPos,
    required this.matchCount,
    required this.onChanged,
    required this.onPrev,
    required this.onNext,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Color inkColor;
  final Color background;
  final int matchPos;
  final int matchCount;
  final ValueChanged<String> onChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final hint = inkColor.withValues(alpha: 0.5);
    final hasQuery = controller.text.trim().isNotEmpty;
    return Material(
      color: background,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
        child: Row(
          children: [
            _IconBtn(
              onTap: onClose,
              child: Icon(Icons.arrow_back, size: 21, color: inkColor),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                style: GoogleFonts.inter(fontSize: 15, color: inkColor),
                cursorColor: AppColors.ember,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search in book',
                  hintStyle: GoogleFonts.inter(fontSize: 15, color: hint),
                ),
              ),
            ),
            if (hasQuery)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '$matchPos/$matchCount',
                  style: GoogleFonts.inter(fontSize: 12.5, color: hint),
                ),
              ),
            _IconBtn(
              onTap: matchCount == 0 ? null : onPrev,
              child: Icon(Icons.keyboard_arrow_up, size: 22, color: inkColor),
            ),
            _IconBtn(
              onTap: matchCount == 0 ? null : onNext,
              child: Icon(Icons.keyboard_arrow_down, size: 22, color: inkColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "contents" bottom sheet: the open book's bookmarks and highlights,
/// tappable to jump to their page.
class _ContentsSheet extends StatelessWidget {
  const _ContentsSheet({
    required this.bookmarks,
    required this.highlights,
    required this.onJump,
  });

  final List<Bookmark> bookmarks;
  final List<Highlight> highlights;

  /// Called with the target page number when a row is tapped.
  final ValueChanged<int> onJump;

  @override
  Widget build(BuildContext context) {
    final empty = bookmarks.isEmpty && highlights.isEmpty;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        10,
        22,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              margin: const EdgeInsets.only(top: 4, bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          if (empty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Nothing saved yet. Tap the bookmark icon, or select text and '
                'pick a color, while reading.',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  height: 1.4,
                  color: AppColors.inkSoft,
                ),
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (highlights.isNotEmpty) ...[
                    const _SheetSectionTitle('Highlights'),
                    for (final h in highlights)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => onJump(h.page),
                        leading: Icon(Icons.circle, color: h.color, size: 16),
                        title: Text(
                          h.quote,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            height: 1.35,
                            color: AppColors.ink,
                          ),
                        ),
                        trailing: Text(
                          'p.${h.page}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.inkFaint,
                          ),
                        ),
                      ),
                  ],
                  if (bookmarks.isNotEmpty) ...[
                    const _SheetSectionTitle('Bookmarks'),
                    for (final bm in bookmarks)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => onJump(bm.page),
                        leading: const Icon(
                          Icons.bookmark,
                          color: AppColors.ember,
                          size: 20,
                        ),
                        title: Text(
                          bm.chapter.isEmpty ? 'Page ${bm.page}' : bm.chapter,
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        subtitle: bm.note.isEmpty
                            ? null
                            : Text(
                                bm.note,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                        trailing: Text(
                          'p.${bm.page}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.inkFaint,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A small section header inside the contents sheet.
class _SheetSectionTitle extends StatelessWidget {
  const _SheetSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.fraunces(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
    );
  }
}
