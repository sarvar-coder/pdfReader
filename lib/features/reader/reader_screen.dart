import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ember/features/library/dummy_data.dart';
import 'package:ember/features/reader/reader_settings.dart';
import 'package:ember/features/reader/widgets/selection_toolbar.dart';
import 'package:ember/features/reader/widgets/settings_sheet.dart';
import 'package:ember/models/bookmark.dart';
import 'package:ember/models/highlight.dart';
import 'package:ember/providers/bookmarks_provider.dart';
import 'package:ember/providers/highlights_provider.dart';
import 'package:ember/providers/library_provider.dart';
import 'package:ember/providers/reader_provider.dart';
import 'package:ember/services/pdf_service.dart';
import 'package:ember/theme/app_colors.dart';

/// A run of text to paint with a highlight background.
typedef _Mark = ({String text, Color color});

/// The Reader screen (sample text until Phase 3). Top/bottom chrome that hides on
/// a page tap, sample paragraphs in the chosen typeface with one highlighted
/// sentence, an "Aa" settings sheet that live-updates the text, and a visual
/// selection toolbar on long-press. Book metadata comes from the library
/// providers; the prose is still [DummyData].
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, this.onBack});

  /// Returns to the Library (the top-chrome back button).
  final VoidCallback? onBack;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  ReaderSettings _settings = const ReaderSettings();
  bool _chromeVisible = true;
  bool _sheetOpen = false;

  /// The latest selected text, captured from the [SelectionArea].
  String? _selectedText;

  // ── Reading-position tracking ───────────────────────────────────────────
  final ScrollController _scroll = ScrollController();
  Timer? _saveTimer;

  /// Id of the book we're currently tracking position for.
  String? _positionBookId;

  /// Id we've already restored the scroll position for (so we restore once).
  String? _restoredBookId;
  double _pendingRestoreFraction = 0;

  /// True while a restore is pending, to suppress saves that would clobber it.
  bool _needsRestore = false;

  /// Whether the open book has a real PDF (only those track/restore position).
  bool _hasPdf = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasPdf || _needsRestore || !_scroll.hasClients) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), _savePosition);
  }

  void _savePosition() {
    final id = _positionBookId;
    if (!_hasPdf || id == null || !_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final fraction = max <= 0 ? 0.0 : (_scroll.offset / max).clamp(0.0, 1.0);
    ref.read(libraryProvider.notifier).updateReadingPosition(id, fraction);
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

  /// Chooses what the page shows: a spinner while parsing, the demo prose when
  /// the book has no PDF (seeded books), an empty-text notice for scanned PDFs,
  /// or the reflowed extracted text.
  Widget _buildPage(
    AsyncValue<PdfContent?> contentAsync,
    Color ink,
    List<_Mark> marks,
  ) {
    return contentAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: ink.withValues(alpha: 0.5)),
      ),
      error: (e, _) => _PageBody(
        controller: _scroll,
        settings: _settings,
        paragraphs: ['Couldn’t read this PDF.', '$e'],
      ),
      data: (content) {
        if (content == null) {
          // Seeded demo book → sample prose with the highlighted sentence.
          return _PageBody(
            controller: _scroll,
            settings: _settings,
            heading: 'Roots',
            paragraphs: DummyData.sampleParagraphs,
            marks: [
              (
                text: DummyData.highlightedSentence,
                color: AppColors.gold.withValues(alpha: 0.45),
              ),
            ],
          );
        }
        final text = content.fullText.trim();
        if (text.isEmpty) {
          return _PageBody(
            controller: _scroll,
            settings: _settings,
            paragraphs: const [
              'No selectable text found in this PDF. '
                  'It may be made of scanned images.',
            ],
          );
        }
        // Real content is laid out — restore the saved position once.
        _scheduleRestoreIfNeeded();
        return _PageBody(
          controller: _scroll,
          settings: _settings,
          paragraphs: _toParagraphs(text),
          marks: marks,
        );
      },
    );
  }

  /// After the extracted text is laid out, jump to the saved reading fraction
  /// (once per book open).
  void _scheduleRestoreIfNeeded() {
    if (!_hasPdf || !_needsRestore || _restoredBookId == _positionBookId) {
      return;
    }
    final fraction = _pendingRestoreFraction;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      _scroll.jumpTo((fraction.clamp(0.0, 1.0)) * max);
      _restoredBookId = _positionBookId;
      _needsRestore = false;
      // Consume a one-shot bookmark jump, if any.
      if (ref.read(pendingJumpProvider) != null) {
        ref.read(pendingJumpProvider.notifier).clear();
      }
    });
  }

  /// Splits extracted text into reflowable paragraphs: break on blank lines,
  /// then collapse the remaining single line breaks into spaces.
  static List<String> _toParagraphs(String text) {
    final blocks = text.split(RegExp(r'\n[ \t]*\n'));
    final paragraphs = <String>[
      for (final block in blocks)
        if (block.trim().isNotEmpty)
          block.trim().replaceAll(RegExp(r'\s*\n\s*'), ' '),
    ];
    return paragraphs.isEmpty ? [text] : paragraphs;
  }

  @override
  Widget build(BuildContext context) {
    final theme = _settings.theme;
    final book = ref.watch(currentBookProvider);
    final contentAsync = ref.watch(readerContentProvider);
    _hasPdf = ref.watch(currentPdfPathProvider) != null;

    // Saved highlights for the open book, painted onto the extracted text.
    final marks = <_Mark>[
      for (final h in ref.watch(highlightsProvider))
        if (book != null && h.bookId == book.id)
          (text: h.quote, color: h.color.withValues(alpha: 0.4)),
    ];

    // A different book is open → set up to restore its saved position.
    if (book?.id != _positionBookId) {
      _positionBookId = book?.id;
      _pendingRestoreFraction = book?.readingFraction ?? 0;
      _restoredBookId = null;
      _needsRestore = _hasPdf;
    }

    // A bookmark/highlight tap requested a jump → override the restore target.
    final pendingJump = ref.watch(pendingJumpProvider);
    if (pendingJump != null && _hasPdf) {
      _pendingRestoreFraction = pendingJump;
      _restoredBookId = null;
      _needsRestore = true;
    } else if (pendingJump != null) {
      // Target book has no scrollable PDF (e.g. the demo book) — drop it so it
      // can't leak onto the next real book opened.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(pendingJumpProvider.notifier).clear();
      });
    }

    final title = book?.title ?? 'Untitled';
    final currentPage = book?.currentPage ?? 0;
    final totalPages = book?.totalPages ?? 0;
    final progress = book?.progress ?? 0;
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
                    title: '$title · Chapter 6',
                    inkColor: theme.ink,
                    onBack: () {
                      _savePosition();
                      widget.onBack?.call();
                    },
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
                        child: _buildPage(contentAsync, theme.ink, marks),
                      ),
                    ),
                  ),
                  _BottomChrome(
                    visible: _chromeVisible,
                    progress: progress,
                    inkColor: theme.ink,
                    pageLabel: 'Page $currentPage of $totalPages',
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
                settings: _settings,
                onChanged: (s) => setState(() => _settings = s),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Back · centered title · bookmark · Aa. Fades/slides out when chrome hides.
class _TopChrome extends StatelessWidget {
  const _TopChrome({
    required this.visible,
    required this.title,
    required this.inkColor,
    this.onBack,
    this.onBookmark,
    this.onSettings,
  });

  final bool visible;
  final String title;
  final Color inkColor;
  final VoidCallback? onBack;
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

/// Thin progress bar + page/time info. Fades/slides out when chrome hides.
class _BottomChrome extends StatelessWidget {
  const _BottomChrome({
    required this.visible,
    required this.progress,
    required this.inkColor,
    required this.pageLabel,
  });

  final bool visible;
  final double progress;
  final Color inkColor;
  final String pageLabel;

  @override
  Widget build(BuildContext context) {
    final infoStyle = GoogleFonts.inter(
      fontSize: 11.5,
      color: inkColor.withValues(alpha: 0.65),
    );
    return _ChromeAnimator(
      visible: visible,
      slideUp: false,
      child: Padding(
        // Extra bottom padding clears the floating nav bar.
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 90),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: 4,
                color: inkColor.withValues(alpha: 0.12),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: const ColoredBox(color: AppColors.ember),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(pageLabel, style: infoStyle),
                Text('18 min left in chapter', style: infoStyle),
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

/// The scrollable reading page: an optional heading and the reflowed paragraphs
/// in the chosen typeface, painting any highlight [marks] over matching text.
class _PageBody extends StatelessWidget {
  const _PageBody({
    required this.controller,
    required this.settings,
    required this.paragraphs,
    this.heading,
    this.marks = const [],
  });

  final ScrollController controller;
  final ReaderSettings settings;
  final List<String> paragraphs;
  final String? heading;
  final List<_Mark> marks;

  @override
  Widget build(BuildContext context) {
    final ink = settings.theme.ink;
    return SingleChildScrollView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(26, 14, 26, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (heading != null) ...[
            Text(
              heading!,
              style: GoogleFonts.fraunces(
                fontSize: 23,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
            const SizedBox(height: 14),
          ],
          for (final paragraph in paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _Paragraph(
                text: paragraph,
                settings: settings,
                marks: marks,
              ),
            ),
        ],
      ),
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
  });

  final String text;
  final ReaderSettings settings;
  final List<_Mark> marks;

  @override
  Widget build(BuildContext context) {
    final base = settings.bodyStyle();
    if (marks.isEmpty) return Text(text, style: base);

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
    if (ranges.isEmpty) return Text(text, style: base);
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
    return Text.rich(TextSpan(style: base, children: spans));
  }
}
