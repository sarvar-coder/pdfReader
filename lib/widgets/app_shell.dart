import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'package:ember/features/library/library_screen.dart';
import 'package:ember/features/stats/stats_screen.dart';
import 'package:ember/providers/library_provider.dart';
import 'package:ember/theme/app_colors.dart';

/// The two top-level destinations, in nav order. The reader opens as a
/// full-screen route (no nav bar), so it is not a tab.
enum _Tab {
  library('Library', Icons.menu_book_rounded),
  stats('Stats', Icons.local_fire_department_rounded);

  const _Tab(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Hosts the current screen and a frosted bottom nav bar.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;
  StreamSubscription<List<SharedMediaFile>>? _shareSub;

  @override
  void initState() {
    super.initState();
    // PDFs shared/opened from other apps (Files, Safari, Mail, etc.).
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _importShared(files);
      ReceiveSharingIntent.instance.reset();
    });
    _shareSub =
        ReceiveSharingIntent.instance.getMediaStream().listen(_importShared);
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    super.dispose();
  }

  Future<void> _importShared(List<SharedMediaFile> files) async {
    var importedAny = false;
    for (final file in files) {
      final path = file.path;
      if (!path.toLowerCase().endsWith('.pdf')) continue;
      final name = path.split('/').last;
      final title = name.length > 4 ? name.substring(0, name.length - 4) : name;
      await ref
          .read(libraryProvider.notifier)
          .importPdf(sourcePath: path, title: title);
      importedAny = true;
    }
    if (importedAny && mounted) {
      setState(() => _index = _Tab.library.index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      // Let the screen body extend behind the floating nav bar.
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          LibraryScreen(
            onOpenStats: () => setState(() => _index = _Tab.stats.index),
          ),
          const StatsScreen(),
        ],
      ),
      bottomNavigationBar: _FrostedNav(
        index: _index,
        onSelect: (i) => setState(() => _index = i),
      ),
    );
  }
}

/// A frosted, rounded, floating navigation bar matching the mockup.
class _FrostedNav extends StatelessWidget {
  const _FrostedNav({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              height: 66,
              decoration: BoxDecoration(
                color: AppColors.card.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.line),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A2A241E),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (var i = 0; i < _Tab.values.length; i++)
                    _NavButton(
                      tab: _Tab.values[i],
                      selected: i == index,
                      onTap: () => onSelect(i),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.emberDeep : AppColors.inkFaint;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tab.icon, size: 23, color: color),
            const SizedBox(height: 4),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
