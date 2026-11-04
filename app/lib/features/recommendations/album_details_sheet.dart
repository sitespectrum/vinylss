import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/models.dart';
import '../../ui/theme.dart';
import '../../ui/vinyl.dart';
import 'album_card.dart';

void showAlbumDetails(BuildContext context, Recommendation item, MarkCallback onMark) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 1,
      builder: (context, controller) => AlbumDetails(
        item: item,
        scrollController: controller,
        onMark: (r, kind) {
          Navigator.of(context).pop();
          onMark(r, kind);
        },
      ),
    ),
  );
}

class AlbumDetails extends StatefulWidget {
  const AlbumDetails({super.key, required this.item, required this.onMark, this.scrollController});

  final Recommendation item;
  final MarkCallback onMark;
  final ScrollController? scrollController;

  @override
  State<AlbumDetails> createState() => _AlbumDetailsState();
}

class _AlbumDetailsState extends State<AlbumDetails> {
  /// The record slides out of the sleeve once the sheet is open.
  bool _pulled = false;
  late final Timer _pull;

  @override
  void initState() {
    super.initState();
    _pull = Timer(const Duration(milliseconds: 250), () => setState(() => _pulled = true));
  }

  @override
  void dispose() {
    _pull.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final text = Theme.of(context).textTheme;
    final vinyl = item.discogs;

    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.zero,
      children: [
        // Header: gradient wash behind the sleeve, like an album page.
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Palette.accentDeep, Palette.surface],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Column(children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: SizedBox(
                width: 270,
                child: SleeveCover(url: item.coverUrl, pulled: _pulled, radius: 4),
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, style: text.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  [item.artist, if (item.year != null) item.year].join(' · '),
                  style: text.bodyMedium?.copyWith(color: Palette.text, fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              VinylBadge(item: item),
              if (vinyl?.numForSale != null && vinyl!.numForSale! > 0) ...[
                const SizedBox(width: 10),
                Flexible(
                  child: Text('${vinyl.numForSale} copies for sale', style: text.bodySmall),
                ),
              ],
            ]),
            const SizedBox(height: 20),
            Row(children: [
              if (vinyl?.hasVinyl ?? false) ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => openUrl(vinyl!.marketplaceUrl ?? vinyl.url),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('Buy on Discogs', overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (item.spotifyUrl != null)
                OutlinedButton.icon(
                  onPressed: () => openUrl(item.spotifyUrl),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Spotify'),
                ),
            ]),
            const SizedBox(height: 8),
            // Offset by the buttons' own padding so their icons line up with the content edge.
            Transform.translate(
              offset: const Offset(-12, 0),
              child: Wrap(spacing: 4, children: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Palette.subtext),
                onPressed: () => widget.onMark(item, MarkKind.owned),
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: const Text('I own this'),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Palette.subtext),
                onPressed: () => widget.onMark(item, MarkKind.notInterested),
                icon: const Icon(Icons.visibility_off_outlined, size: 20),
                label: const Text('Not interested'),
              ),
              ]),
            ),
            const SizedBox(height: 24),
            _LinerNotes(text: item.reason),
            if (item.matchedTracks.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text('Tracks you play', style: text.titleMedium),
              const SizedBox(height: 4),
              ..._sides(item.matchedTracks, text),
            ],
          ]),
        ),
      ],
    );
  }

  /// Splits the tracks over side A and side B, numbered like a record (A1, A2, B1…).
  static List<Widget> _sides(List<MatchedTrack> tracks, TextTheme text) {
    final sideA = (tracks.length / 2).ceil();
    return [
      for (var i = 0; i < tracks.length; i++) ...[
        if (i == 0 || i == sideA)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              i == 0 ? 'SIDE A' : 'SIDE B',
              style: text.labelSmall?.copyWith(color: Palette.muted, letterSpacing: 1.6),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            SizedBox(
              width: 36,
              child: Text(
                i < sideA ? 'A${i + 1}' : 'B${i - sideA + 1}',
                style: text.labelLarge?.copyWith(
                  color: Palette.accent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Expanded(
              child: Text(tracks[i].name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyLarge),
            ),
          ]),
        ),
      ],
    ];
  }
}

/// The recommendation reason, framed like the liner notes on a sleeve.
class _LinerNotes extends StatelessWidget {
  const _LinerNotes({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Palette.elevated,
          border: Border(left: BorderSide(color: Palette.accent, width: 3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('LINER NOTES',
              style: theme.labelSmall?.copyWith(color: Palette.muted, letterSpacing: 1.6)),
          const SizedBox(height: 6),
          Text(text, style: theme.bodyLarge),
        ]),
      ),
    );
  }
}
