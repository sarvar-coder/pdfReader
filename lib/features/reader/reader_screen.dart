import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ember/features/notes/note_screen.dart';
import 'package:ember/features/reader/reader_settings.dart';
import 'package:ember/features/reader/reflow.dart';
import 'package:ember/features/reader/widgets/icon_btn.dart';
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

  /// Reflow blocks for the open book, rebuilt only when the book changes (so
  /// their cached string hashCodes keep the pagination memo cheap).
  List<Block> _blocks = const [];
  String? _blocksBookId;

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

  /// Called by the paged body whenever it (re)paginates with the new number of
  /// reflowed pages (which drives the bottom counter + slider).
  /// Jumps to the pending restore target on a fresh open / bookmark tap, or
  /// realigns to the current fraction when a font/size change re-flowed pages.
  void _onPaginated(int pageCount) {
    setState(() {
      _pageCount = pageCount;
      _currentPage = _pageForFraction(_currentFraction);
    });
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

  /// Opens the open book's notebook as a full-screen route.
  void _openNotes(Book book) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteScreen(bookId: book.id, title: book.title),
      ),
    );
  }

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
    List<Mark> marks,
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
          _blocks = toBlocks(text);
          _blocksBookId = _positionBookId;
        }
        return PagedBody(
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
    final marks = <Mark>[
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
                    onNote: () => _openNotes(book),
                    onBookmark: _addBookmark,
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
                    visible: _chromeVisible,
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

/// Back · centered title · note · bookmark · Aa. Fades/slides out when hidden.
class _TopChrome extends StatelessWidget {
  const _TopChrome({
    required this.visible,
    required this.title,
    required this.inkColor,
    this.onBack,
    this.onNote,
    this.onBookmark,
    this.onSettings,
  });

  final bool visible;
  final String title;
  final Color inkColor;
  final VoidCallback? onBack;
  final VoidCallback? onNote;
  final VoidCallback? onBookmark;
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
            IconBtn(
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
            IconBtn(
              onTap: onNote,
              child: Icon(Icons.edit_note, size: 23, color: inkColor),
            ),
            IconBtn(
              onTap: onBookmark,
              child: Icon(Icons.bookmark_border, size: 20, color: inkColor),
            ),
            IconBtn(
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
                IconBtn(
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
                child: Paragraph(
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
