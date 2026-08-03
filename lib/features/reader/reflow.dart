/// The reflow pipeline: plain extracted text → classified [Block]s → a
/// [PagedBody] of screen-sized, horizontally swiped pages measured against the
/// real box. Shared by the Reader (a book's extracted text) and the Notes
/// screen (a book's notebook), so both read identically.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ember/features/reader/reader_settings.dart';

/// A run of text to paint with a highlight background.
typedef Mark = ({String text, Color color});

/// A reflow block: a justified body paragraph, or a centered bold heading in
/// one of two tiers — a [title] (chapter/section) or a smaller [subtitle].
enum BlockKind { title, subtitle, body }

/// The heading tier a single line is classified as (or [none] for body).
enum _HeadingLevel { title, subtitle, none }

class Block {
  const Block(this.kind, this.text);
  final BlockKind kind;
  final String text;
}

/// A slice of a [Block] that lands on a single page.
class _Frag {
  const _Frag({
    required this.kind,
    required this.text,
    required this.isFirst,
    required this.isLast,
  });
  final BlockKind kind;
  final String text;

  /// First slice of its block (apply the indent / heading top-gap).
  final bool isFirst;

  /// Last slice of its block (the paragraph ends here, not split further).
  final bool isLast;
}

/// First-line indent prepended to body paragraphs (two em-spaces).
const String kIndent = '  ';

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

/// Turns extracted text into [Block]s. Works line-by-line within blank-line
/// groups so a heading line is split off from the body that follows it (even
/// with no blank line between); wrapped body lines are re-joined into
/// paragraphs carrying a first-line indent (so layout == render).
List<Block> toBlocks(String text) {
  final result = <Block>[];
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
        result.add(Block(BlockKind.body, '$kIndent${buffer.join(' ')}'));
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
          result.add(Block(BlockKind.title, line));
          prevHeading = true;
        case _HeadingLevel.subtitle:
          flushBody();
          result.add(Block(BlockKind.subtitle, line));
          prevHeading = true;
        case _HeadingLevel.none:
          buffer.add(line);
          prevHeading = false;
      }
    }
    flushBody();
  }

  if (result.isEmpty) result.add(Block(BlockKind.body, text));
  return result;
}
/// The horizontally-swiped reading view. Reflows [body] into screen-sized pages
/// (one per swipe, no inner scroll) by measuring the text against the available
/// box, then re-measures whenever the box or the reader [settings] change.
class PagedBody extends StatefulWidget {
  const PagedBody({
    super.key,
    required this.controller,
    required this.settings,
    required this.blocks,
    required this.marks,
    required this.onPaginated,
    required this.onPageChanged,
  });

  final PageController controller;
  final ReaderSettings settings;
  final List<Block> blocks;
  final List<Mark> marks;

  /// Reports the number of reflowed pages after (re)pagination, so the parent
  /// can drive its page counter and restore the reading position.
  final ValueChanged<int> onPaginated;
  final ValueChanged<int> onPageChanged;

  @override
  State<PagedBody> createState() => _PagedBodyState();
}

class _PagedBodyState extends State<PagedBody> {
  static const _pad = EdgeInsets.fromLTRB(26, 14, 26, 24);

  /// Heading top/bottom margins as a multiple of the font size, per tier.
  static const _titleTop = 0.9;
  static const _titleBottom = 0.4;
  static const _subTop = 0.25;
  static const _subBottom = 0.5;

  List<List<_Frag>> _pages = const [[]];

  /// Memo key: re-_paginate only when the box size, the text, or a layout-
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
          // Report the new page count to the parent after this frame.
          final count = _pages.length;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onPaginated(count);
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
    if (f.kind != BlockKind.body) {
      final isTitle = f.kind == BlockKind.title;
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
    return Paragraph(
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
    List<Block> blocks,
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
      final isBody = block.kind == BlockKind.body;
      final isTitle = block.kind == BlockKind.title;
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
            kind: BlockKind.body,
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
class Paragraph extends StatelessWidget {
  const Paragraph({
    super.key,
    required this.text,
    required this.settings,
    this.marks = const [],
    this.align = TextAlign.start,
  });

  final String text;
  final ReaderSettings settings;
  final List<Mark> marks;
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
