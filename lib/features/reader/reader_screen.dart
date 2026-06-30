import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ember/features/library/dummy_data.dart';
import 'package:ember/features/reader/reader_settings.dart';
import 'package:ember/features/reader/widgets/selection_toolbar.dart';
import 'package:ember/features/reader/widgets/settings_sheet.dart';
import 'package:ember/theme/app_colors.dart';

/// The Reader screen (static text for Phase 1). Top/bottom chrome that hides on
/// a page tap, sample paragraphs in the chosen typeface with one highlighted
/// sentence, an "Aa" settings sheet that live-updates the text, and a visual
/// selection toolbar on long-press.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, this.onBack});

  /// Returns to the Library (the top-chrome back button).
  final VoidCallback? onBack;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  ReaderSettings _settings = const ReaderSettings();
  bool _chromeVisible = true;
  bool _sheetOpen = false;
  bool _selectionVisible = false;

  DummyBook get _book => DummyData.continueReading;

  void _onPageTap() {
    setState(() {
      if (_selectionVisible) {
        _selectionVisible = false;
      } else {
        _chromeVisible = !_chromeVisible;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = _settings.theme;
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
                    title: '${_book.title} · Chapter 6',
                    inkColor: theme.ink,
                    onBack: widget.onBack,
                    onBookmark: () => ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(
                            content: Text('Bookmarked page 184'))),
                    onSettings: () => setState(() => _sheetOpen = true),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _onPageTap,
                      onLongPress: () =>
                          setState(() => _selectionVisible = true),
                      behavior: HitTestBehavior.opaque,
                      child: _PageBody(settings: _settings),
                    ),
                  ),
                  _BottomChrome(
                    visible: _chromeVisible,
                    progress: _book.progress,
                    inkColor: theme.ink,
                    pageLabel: 'Page ${_book.currentPage} of ${_book.totalPages}',
                  ),
                ],
              ),
            ),
          ),

          // ── Selection toolbar (visual only) ────────────────────────────
          if (_selectionVisible)
            Positioned(
              top: 130,
              left: 0,
              right: 0,
              child: Center(
                child: SelectionToolbar(
                  onDismiss: () => setState(() => _selectionVisible = false),
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

/// The scrollable reading page: a chapter heading and sample paragraphs in the
/// chosen typeface, with one highlighted sentence.
class _PageBody extends StatelessWidget {
  const _PageBody({required this.settings});

  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) {
    final ink = settings.theme.ink;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 14, 26, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Roots',
            style: GoogleFonts.fraunces(
              fontSize: 23,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
          const SizedBox(height: 14),
          for (final paragraph in DummyData.sampleParagraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _Paragraph(text: paragraph, settings: settings),
            ),
        ],
      ),
    );
  }
}

/// Renders one paragraph, wrapping [DummyData.highlightedSentence] (if present)
/// in a gold highlight.
class _Paragraph extends StatelessWidget {
  const _Paragraph({required this.text, required this.settings});

  final String text;
  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) {
    final base = settings.bodyStyle();
    const target = DummyData.highlightedSentence;
    final start = text.indexOf(target);

    if (start < 0) {
      return Text(text, style: base);
    }

    final end = start + target.length;
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          if (start > 0) TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: target,
            style: TextStyle(
              backgroundColor: AppColors.gold.withValues(alpha: 0.45),
            ),
          ),
          if (end < text.length) TextSpan(text: text.substring(end)),
        ],
      ),
    );
  }
}
