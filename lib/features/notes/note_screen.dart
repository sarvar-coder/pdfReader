import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ember/features/reader/reader_settings.dart';
import 'package:ember/features/reader/reflow.dart';
import 'package:ember/features/reader/widgets/icon_btn.dart';
import 'package:ember/providers/reader_provider.dart';
import 'package:ember/providers/storage_provider.dart';
import 'package:ember/theme/app_colors.dart';

/// A book's notebook: one continuous text the reader writes in their own words
/// while reading, stored at `<docs>/books/<id>.note.txt`.
///
/// Two modes, toggled by the book icon in the top bar:
/// * **writing** — one full-height [TextField], vertical scroll, autosaved;
/// * **reading** — the same text run through the reader's reflow pipeline, so
///   notes are swiped page-by-page exactly like a book.
///
/// Both modes render with the live [ReaderSettings], so notes inherit the
/// theme, size, typeface and spacing chosen in the reader's "Aa" sheet.
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

  static const _pad = EdgeInsets.fromLTRB(26, 14, 26, 24);

  final TextEditingController _controller = TextEditingController();
  final PageController _pageController = PageController();

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
    final text = await ref.read(storageServiceProvider).readNote(widget.bookId);
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
    await ref.read(storageServiceProvider).writeNote(widget.bookId, text);
  }

  void _onChanged(String _) {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounce, _save);
  }

  /// Book icon: flips between writing and reading mode, saving and re-flowing on
  /// the way in so reading mode always shows what was just typed.
  void _toggleMode() {
    _saveTimer?.cancel();
    unawaited(_save());
    FocusScope.of(context).unfocus();
    setState(() {
      _reading = !_reading;
      if (_reading) _blocks = toBlocks(_controller.text.trim());
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
        // 1.0, and the in-app "Aa" size is the only size control.
        child: MediaQuery.withNoTextScaling(
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
              if (_reading && _blocks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '${_page + 1}/$_pageCount',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: theme.ink.withValues(alpha: 0.75),
                    ),
                  ),
                ),
            ],
          ),
        ),
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
          padding: _pad,
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

    return Padding(
      padding: _pad,
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        autofocus: true,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
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
    );
  }
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
