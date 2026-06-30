import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ember/features/library/widgets/continue_card.dart';
import 'package:ember/features/library/widgets/shelf_grid.dart';
import 'package:ember/features/library/widgets/streak_card.dart';
import 'package:ember/providers/library_provider.dart';
import 'package:ember/providers/reader_provider.dart';
import 'package:ember/theme/app_colors.dart';

/// The Library screen: greeting header, streak card, continue-reading card,
/// and the shelf grid. Reads its content from the library providers.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key, this.onOpenReader, this.onOpenStats});

  /// Opens the Reader (continue card / shelf book tap).
  final VoidCallback? onOpenReader;

  /// Opens the Stats screen (streak card tap).
  final VoidCallback? onOpenStats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(libraryProvider);
    final featured = ref.watch(continueReadingProvider);
    final shelf = ref.watch(shelfProvider);
    final inProgress = ref.watch(inProgressCountProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 96),
        children: [
          _Header(inProgress: inProgress, total: books.length),
          StreakCard(onTap: onOpenStats),
          if (featured != null) ...[
            const _SectionHeader(title: 'Continue reading'),
            ContinueCard(
              book: featured,
              onTap: () {
                ref.read(currentBookIdProvider.notifier).open(featured.id);
                onOpenReader?.call();
              },
            ),
          ],
          const _SectionHeader(title: 'On the shelf', action: 'Sort'),
          ShelfGrid(
            books: shelf,
            onOpenBook: (book) {
              ref.read(currentBookIdProvider.notifier).open(book.id);
              onOpenReader?.call();
            },
            onAddPdf: () => _pickAndImportPdf(context, ref),
          ),
        ],
      ),
    );
  }
}

/// Opens the system file picker for a PDF, copies it into app storage, and adds
/// a [Book] record. Page count is filled in later (step 3.4).
Future<void> _pickAndImportPdf(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return; // cancelled, or no readable path

    final name = result!.files.single.name;
    final title = name.toLowerCase().endsWith('.pdf')
        ? name.substring(0, name.length - 4)
        : name;

    final book = await ref
        .read(libraryProvider.notifier)
        .importPdf(sourcePath: path, title: title);

    messenger.showSnackBar(
      SnackBar(content: Text('Added “${book.title}”')),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Couldn’t import PDF: $e')),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.inProgress, required this.total});

  final int inProgress;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good evening, reader',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.18 * 11,
              color: AppColors.inkFaint,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your shelf',
            style: GoogleFonts.fraunces(
              fontSize: 30,
              height: 1.05,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$inProgress in progress · $total on the shelf',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final String? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 26, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.fraunces(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          if (action != null)
            Text(
              action!,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.emberDeep,
              ),
            ),
        ],
      ),
    );
  }
}
