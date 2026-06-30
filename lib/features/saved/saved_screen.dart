import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ember/features/saved/widgets/bookmark_tile.dart';
import 'package:ember/features/saved/widgets/highlight_card.dart';
import 'package:ember/providers/bookmarks_provider.dart';
import 'package:ember/providers/highlights_provider.dart';
import 'package:ember/providers/reader_provider.dart';
import 'package:ember/theme/app_colors.dart';

/// The Saved screen: a header and a Highlights / Bookmarks segmented switch,
/// each listing the persisted cards from the providers.
class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key, this.onOpenReader});

  /// Opens the Reader (tapping a highlight or bookmark).
  final VoidCallback? onOpenReader;

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  int _tab = 0; // 0 = Highlights, 1 = Bookmarks

  void _open(String bookId) {
    ref.read(currentBookIdProvider.notifier).open(bookId);
    widget.onOpenReader?.call();
  }

  @override
  Widget build(BuildContext context) {
    final highlights = ref.watch(highlightsProvider);
    final bookmarks = ref.watch(bookmarksProvider);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 96),
        children: [
          const _Header(),
          _TabSwitch(
            index: _tab,
            labels: const ['Highlights', 'Bookmarks'],
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 16),
          if (_tab == 0)
            for (final h in highlights)
              HighlightCard(highlight: h, onTap: () => _open(h.bookId))
          else
            for (final b in bookmarks)
              BookmarkTile(bookmark: b, onTap: () => _open(b.bookId)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The Overstory',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.18 * 11,
              color: AppColors.inkFaint,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Saved',
            style: GoogleFonts.fraunces(
              fontSize: 30,
              height: 1.05,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// A pill segmented control; the selected segment is raised on `card`.
class _TabSwitch extends StatelessWidget {
  const _TabSwitch({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == index ? AppColors.card : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: i == index
                        ? const [
                            BoxShadow(
                              color: Color(0x14281E12),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: i == index ? AppColors.ink : AppColors.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
