import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models.dart';
import '../../ui/theme.dart';
import '../../ui/vinyl.dart';
import 'album_card.dart';
import 'album_details_sheet.dart';
import 'recommendations_controller.dart';
import 'recommendations_screen.dart' show markWithUndo;

/// Every album in one recommendation section, as a grid.
class SectionScreen extends ConsumerWidget {
  const SectionScreen({super.key, required this.sectionId});

  static const maxCardWidth = 200.0;
  static const spacing = 4.0;

  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(recommendationsProvider).value;
    final section = snapshot?.sections.where((s) => s.id == sectionId).firstOrNull;
    void onMark(Recommendation r, MarkKind kind) => markWithUndo(context, ref, r, kind);

    if (section == null) {
      return Scaffold(
        appBar: AppBar(),
        body: snapshot == null || snapshot.isWorking
            ? const LoadingRecord()
            : const VinylMessage(icon: Icons.search_off, text: 'This section is no longer here.'),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        color: Palette.accent,
        backgroundColor: Palette.elevated,
        onRefresh: () => ref.read(recommendationsProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar.medium(
              title: Text(section.title),
              backgroundColor: Palette.background,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              sliver: SliverToBoxAdapter(
                child: Text(
                  '${section.description} · ${section.items.length} '
                  '${section.items.length == 1 ? 'album' : 'albums'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            if (section.items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: VinylMessage(
                  icon: Icons.album_outlined,
                  text: 'Nothing here yet. Try loosening the filters in settings.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                sliver: SliverLayoutBuilder(builder: (context, constraints) {
                  final width = constraints.crossAxisExtent;
                  final columns = ((width + spacing) / (maxCardWidth + spacing)).ceil().clamp(2, 12);
                  final cardWidth = (width - spacing * (columns - 1)) / columns;
                  return SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: AlbumCard.heightFor(cardWidth),
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                    ),
                    itemCount: section.items.length,
                    itemBuilder: (context, i) {
                      final item = section.items[i];
                      return AlbumCard(
                        item: item,
                        onMark: onMark,
                        onTap: () => showAlbumDetails(context, item, onMark),
                      );
                    },
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }
}
