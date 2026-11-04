import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../ui/theme.dart';
import '../../ui/vinyl.dart';
import '../settings/settings_screen.dart' show meProvider;
import 'album_card.dart';
import 'album_details_sheet.dart';
import 'recommendations_controller.dart';

/// Marks an album and offers an undo snackbar.
Future<void> markWithUndo(
  BuildContext context,
  WidgetRef ref,
  Recommendation r,
  MarkKind kind,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(recommendationsProvider.notifier);
  try {
    await controller.mark(r, kind);
    messenger.showSnackBar(
      SnackBar(
        content: Text(kind == MarkKind.owned ? 'Marked "${r.title}" as owned' : 'Hid "${r.title}"'),
        action: SnackBarAction(label: 'Undo', onPressed: () => controller.unmark(r)),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(describeError(e))));
  }
}

/// Home: one horizontal shelf per recommendation section.
class RecommendationsScreen extends ConsumerWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recommendationsProvider);
    final snapshot = async.value;
    final sections = snapshot?.sections ?? const <RecommendationSection>[];
    void onMark(Recommendation r, MarkKind kind) => markWithUndo(context, ref, r, kind);

    final Widget? fill = switch (async) {
      AsyncError(:final error) when snapshot == null => VinylMessage(
        icon: Icons.cloud_off,
        text: describeError(error),
        action: OutlinedButton(
          onPressed: () => ref.invalidate(recommendationsProvider),
          child: const Text('Retry'),
        ),
      ),
      _ when snapshot == null => const LoadingRecord(),
      _ when sections.isEmpty && !snapshot.isWorking && snapshot.generatedAt != null =>
        VinylMessage(
          icon: Icons.tune,
          text: 'All recommendation types are turned off.',
          action: OutlinedButton(
            onPressed: () => context.go('/settings'),
            child: const Text('Open settings'),
          ),
        ),
      _ when sections.isEmpty => const VinylMessage(
        icon: Icons.hourglass_top,
        spinning: true,
        text: 'Digging through the crates…',
        detail:
            'Matching your listening to records on Discogs. '
            'The first run takes a minute or two.',
      ),
      _ => null,
    };

    return Scaffold(
      body: RefreshIndicator(
        color: Palette.accent,
        backgroundColor: Palette.elevated,
        onRefresh: () => ref.read(recommendationsProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                canRefresh: !(snapshot?.isWorking ?? true),
                onRefresh: () => ref.read(recommendationsProvider.notifier).refresh(),
              ),
            ),
            for (final w in snapshot?.warnings ?? const <String>[])
              SliverToBoxAdapter(child: _Note(text: w)),
            if (fill != null)
              SliverFillRemaining(hasScrollBody: false, child: fill)
            else ...[
              for (final s in sections)
                SliverToBoxAdapter(
                  child: Shelf(
                    section: s,
                    onMark: onMark,
                    onShowAll: () => context.go('/section/${s.id}'),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.canRefresh, required this.onRefresh});

  final bool canRefresh;
  final VoidCallback onRefresh;

  static String greeting(DateTime now) => switch (now.hour) {
    < 5 => 'Late-night listening',
    < 12 => 'Good morning',
    < 18 => 'Good afternoon',
    _ => 'Good evening',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).value;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Palette.accentDeep.withValues(alpha: 0.55), Palette.background],
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 24, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              greeting(DateTime.now()),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          IconButton(
            tooltip: 'Refresh recommendations',
            icon: const Icon(Icons.refresh),
            onPressed: canRefresh ? onRefresh : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Tooltip(
              message: me?.displayName ?? 'Account',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.go('/settings'),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Palette.accent,
                  foregroundColor: Palette.onAccent,
                  backgroundImage: me?.avatarUrl == null ? null : NetworkImage(me!.avatarUrl!),
                  child: me?.avatarUrl == null
                      ? Text(
                          (me?.displayName.isNotEmpty ?? false)
                              ? me!.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled, horizontally scrolling row of album cards.
///
/// Pointer devices can't swipe sideways, so they get previous/next buttons in the header.
class Shelf extends StatefulWidget {
  const Shelf({super.key, required this.section, required this.onMark, required this.onShowAll});

  static const cardWidth = 172.0;

  final RecommendationSection section;
  final MarkCallback onMark;
  final VoidCallback onShowAll;

  @override
  State<Shelf> createState() => _ShelfState();
}

class _ShelfState extends State<Shelf> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _page(int direction) {
    final p = _scroll.position;
    final target = (p.pixels + direction * (p.viewportDimension - Shelf.cardWidth)).clamp(
      p.minScrollExtent,
      p.maxScrollExtent,
    );
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final text = Theme.of(context).textTheme;
    final pointer = switch (Theme.of(context).platform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia => false,
      _ => true,
    };

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(section.title, style: text.titleLarge),
                      const SizedBox(height: 2),
                      Text(
                        section.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (section.items.isNotEmpty) ...[
                  TextButton(
                    onPressed: widget.onShowAll,
                    style: TextButton.styleFrom(foregroundColor: Palette.subtext),
                    child: const Text('Show all'),
                  ),
                  if (pointer)
                    ListenableBuilder(
                      listenable: _scroll,
                      builder: (context, _) {
                        final p = _scroll.hasClients && _scroll.position.hasContentDimensions
                            ? _scroll.position
                            : null;
                        if (p == null || p.maxScrollExtent <= 0) return const SizedBox.shrink();
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Previous',
                              icon: const Icon(Icons.chevron_left),
                              onPressed: p.pixels > p.minScrollExtent ? () => _page(-1) : null,
                            ),
                            IconButton(
                              tooltip: 'Next',
                              icon: const Icon(Icons.chevron_right),
                              onPressed: p.pixels < p.maxScrollExtent ? () => _page(1) : null,
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ],
            ),
          ),
          if (section.items.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text('Nothing here yet. Try loosening the filters in settings.'),
            )
          else
            SizedBox(
              height: AlbumCard.heightFor(Shelf.cardWidth),
              // Shows the paging buttons once the row knows whether it overflows.
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  if (pointer) setState(() {});
                  return false;
                },
                child: ListView.separated(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: section.items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 4),
                  itemBuilder: (context, i) {
                    final item = section.items[i];
                    return SizedBox(
                      width: Shelf.cardWidth,
                      child: AlbumCard(
                        item: item,
                        onMark: widget.onMark,
                        onTap: () => showAlbumDetails(context, item, widget.onMark),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    child: Row(
      children: [
        const Icon(Icons.info_outline, size: 16, color: Palette.muted),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
      ],
    ),
  );
}
