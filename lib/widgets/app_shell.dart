import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:ember/features/library/library_screen.dart';
import 'package:ember/features/reader/reader_screen.dart';
import 'package:ember/features/saved/saved_screen.dart';
import 'package:ember/features/stats/stats_screen.dart';
import 'package:ember/theme/app_colors.dart';

/// The four top-level destinations, in nav order.
enum _Tab {
  library('Library', Icons.menu_book_rounded),
  reading('Reading', Icons.auto_stories_rounded),
  saved('Saved', Icons.bookmark_rounded),
  stats('Stats', Icons.local_fire_department_rounded);

  const _Tab(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Hosts the current screen and a frosted bottom nav bar. The selected tab is
/// kept in local state for now; real screens replace the placeholders in later
/// steps (1.3–1.6).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

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
            onOpenReader: () => setState(() => _index = _Tab.reading.index),
            onOpenStats: () => setState(() => _index = _Tab.stats.index),
          ),
          ReaderScreen(
            onBack: () => setState(() => _index = _Tab.library.index),
          ),
          SavedScreen(
            onOpenReader: () => setState(() => _index = _Tab.reading.index),
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
