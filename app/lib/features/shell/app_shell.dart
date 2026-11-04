import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/models.dart';
import '../../auth/auth_controller.dart';
import '../../ui/theme.dart';
import '../../ui/vinyl.dart';
import '../recommendations/recommendations_controller.dart';

const _destinations = [
  (icon: Icons.home_outlined, selected: Icons.home_rounded, label: 'Home'),
  (icon: Icons.library_music_outlined, selected: Icons.library_music, label: 'Library'),
  (icon: Icons.tune_outlined, selected: Icons.tune, label: 'Settings'),
];

/// Bottom navigation on narrow screens, a sidebar rail on wide ones, and the
/// "now spinning" bar while recommendations are being generated.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  static const wideBreakpoint = 800.0;

  final StatefulNavigationShell shell;

  void _go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    final content = Column(children: [
      Expanded(child: shell),
      NowSpinningBar(onHome: shell.currentIndex == 0),
    ]);

    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: _go,
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.only(top: 16, bottom: 24),
              child: VinylDisc(size: 40, labelText: 'V'),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selected),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1, color: Palette.surface),
          Expanded(child: SafeArea(left: false, child: content)),
        ]),
      );
    }

    return Scaffold(
      body: SafeArea(bottom: false, child: content),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _go,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selected),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

/// Mini "player" bar: a record spins while the backend digs, or shows why the last run failed.
class NowSpinningBar extends ConsumerWidget {
  const NowSpinningBar({super.key, this.onHome = false});

  /// On the first run home already shows the spinning record full-size, so the bar stays hidden.
  final bool onHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(recommendationsProvider).value;
    Widget? bar;
    if ((snapshot?.isWorking ?? false) && !(onHome && snapshot!.sections.isEmpty)) {
      bar = _Bar(
        key: const ValueKey('working'),
        leading: const SpinningRecord(size: 40, tonearm: false),
        title: 'Digging through the crates…',
        subtitle: 'Matching your listening to records',
        progress: true,
      );
    } else if (snapshot?.status == SnapshotStatus.failed) {
      final authExpired = snapshot!.error == 'spotify_auth_expired';
      bar = _Bar(
        key: const ValueKey('failed'),
        leading: const VinylDisc(size: 40, labelIcon: Icons.priority_high),
        title: authExpired ? 'Spotify access expired' : 'The needle skipped',
        subtitle: authExpired ? 'Log out and in again.' : 'Last refresh failed: ${snapshot.error}',
        action: authExpired
            ? TextButton(
                onPressed: () => ref.read(authProvider.notifier).logout(),
                child: const Text('Log out'),
              )
            : TextButton(
                onPressed: () => ref.read(recommendationsProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: bar ?? const SizedBox(width: double.infinity),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.action,
    this.progress = false,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? action;
  final bool progress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF4A2A10), Palette.elevated]),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
                  ]),
                ),
                ?action,
              ]),
            ),
            if (progress)
              const LinearProgressIndicator(
                minHeight: 2,
                color: Palette.text,
                backgroundColor: Color(0x33FFFFFF),
              ),
          ]),
        ),
      ),
    );
  }
}
