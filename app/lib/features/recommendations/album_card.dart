import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/models.dart';
import '../../ui/theme.dart';
import '../../ui/vinyl.dart';

typedef MarkCallback = void Function(Recommendation r, MarkKind kind);

Future<void> openUrl(String? url) async {
  if (url == null) return;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// Lowest price such as "$18.50", or null when Discogs has none.
String? shortPrice(VinylInfo v) {
  if (v.lowestPrice == null) return null;
  final price = v.lowestPrice!.toStringAsFixed(2);
  return v.currency == 'USD' || v.currency == null ? '\$$price' : '${v.currency} $price';
}

String formatPrice(VinylInfo v) {
  final price = shortPrice(v);
  return price == null ? 'Vinyl' : 'Vinyl from $price';
}

bool _isTouch(BuildContext context) => switch (Theme.of(context).platform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia => true,
      _ => false,
    };

class AlbumCover extends StatelessWidget {
  const AlbumCover({super.key, required this.url, this.size, this.square = true});

  final String? url;
  final double? size;

  /// When false the cover fills its parent (cropped) instead of forcing a 1:1 box.
  final bool square;

  @override
  Widget build(BuildContext context) {
    if (!square) return SizedBox.expand(child: CoverImage(url: url));
    return SizedBox(
      width: size,
      height: size,
      child: AspectRatio(aspectRatio: 1, child: CoverImage(url: url)),
    );
  }
}

class VinylBadge extends StatelessWidget {
  const VinylBadge({super.key, required this.item});

  final Recommendation item;

  @override
  Widget build(BuildContext context) {
    return switch (item.vinylStatus) {
      VinylStatus.available => _Pill(
          icon: Icons.album,
          label: formatPrice(item.discogs!),
          background: Palette.accent,
          foreground: Palette.onAccent,
        ),
      VinylStatus.notFound => const _Pill(
          icon: Icons.block,
          label: 'No vinyl found',
          background: Palette.elevated,
          foreground: Palette.subtext,
        ),
      VinylStatus.unknown => const SizedBox.shrink(),
    };
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground, fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

/// Album tile: the record peeks out of its sleeve and slides out on hover or press.
///
/// Pointer devices get an actions button on hover; touch devices long-press for the same menu
/// (tapping opens the details sheet, which has every action too).
class AlbumCard extends StatefulWidget {
  const AlbumCard({super.key, required this.item, required this.onTap, required this.onMark});

  /// Height of everything below the sleeve (gap, title, artist and the "tracks you play" line).
  static const textHeight = 72.0;
  static const padding = 8.0;

  /// Total card height for a given card width.
  static double heightFor(double width) =>
      (width - 2 * padding) * SleeveCover.sleeveFraction + 2 * padding + textHeight;

  final Recommendation item;
  final VoidCallback onTap;
  final MarkCallback onMark;

  @override
  State<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<AlbumCard> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final text = Theme.of(context).textTheme;
    final active = _hover || _pressed;
    final touch = _isTouch(context);
    final sticker = switch (item.vinylStatus) {
      VinylStatus.available => PriceSticker(price: shortPrice(item.discogs!)),
      VinylStatus.notFound => const PriceSticker.noVinyl(),
      VinylStatus.unknown => null,
    };

    return Material(
      color: active ? Palette.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: touch ? () => showAlbumMenu(context, item, widget.onMark) : null,
        onHover: (v) => setState(() => _hover = v),
        onHighlightChanged: (v) => setState(() => _pressed = v),
        splashColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(AlbumCard.padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SleeveCover(
                url: item.coverUrl,
                pulled: active,
                overlay: [
                  if (sticker != null) Positioned(top: 6, right: 6, child: sticker),
                  if (!touch)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: AnimatedOpacity(
                        opacity: active ? 1 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: AlbumMenu(item: item, onMark: widget.onMark),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall),
              const SizedBox(height: 2),
              Text(
                [item.artist, if (item.year != null) item.year].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall,
              ),
              const SizedBox(height: 4),
              if (item.matchedTracks.isNotEmpty)
                Text(
                  '${item.matchedTracks.length} of ${item.totalTracks} tracks you play',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(color: Palette.accent),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _AlbumAction { discogs, spotify, own, skip }

List<PopupMenuEntry<_AlbumAction>> _menuItems(Recommendation item) => [
      if (item.discogs?.hasVinyl ?? false)
        const PopupMenuItem(
          value: _AlbumAction.discogs,
          child: ListTile(leading: Icon(Icons.shopping_bag_outlined), title: Text('Buy on Discogs')),
        ),
      if (item.spotifyUrl != null)
        const PopupMenuItem(
          value: _AlbumAction.spotify,
          child: ListTile(leading: Icon(Icons.open_in_new), title: Text('Open in Spotify')),
        ),
      const PopupMenuItem(
        value: _AlbumAction.own,
        child: ListTile(leading: Icon(Icons.check_circle_outline), title: Text('I own this')),
      ),
      const PopupMenuItem(
        value: _AlbumAction.skip,
        child: ListTile(leading: Icon(Icons.visibility_off_outlined), title: Text('Not interested')),
      ),
    ];

void _onAction(_AlbumAction? action, Recommendation item, MarkCallback onMark) => switch (action) {
      _AlbumAction.discogs => openUrl(item.discogs?.marketplaceUrl ?? item.discogs?.url),
      _AlbumAction.spotify => openUrl(item.spotifyUrl),
      _AlbumAction.own => onMark(item, MarkKind.owned),
      _AlbumAction.skip => onMark(item, MarkKind.notInterested),
      null => null,
    };

/// The album actions menu, anchored to the widget at [context].
Future<void> showAlbumMenu(BuildContext context, Recommendation item, MarkCallback onMark) async {
  final box = context.findRenderObject()! as RenderBox;
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
  final action = await showMenu<_AlbumAction>(
    context: context,
    position: RelativeRect.fromRect(topLeft & box.size, Offset.zero & overlay.size),
    items: _menuItems(item),
  );
  _onAction(action, item, onMark);
}

class AlbumMenu extends StatelessWidget {
  const AlbumMenu({super.key, required this.item, required this.onMark});

  final Recommendation item;
  final MarkCallback onMark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      child: SizedBox.square(
        dimension: 32,
        child: PopupMenuButton<_AlbumAction>(
          tooltip: 'Actions',
          padding: EdgeInsets.zero,
          iconSize: 18,
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (v) => _onAction(v, item, onMark),
          itemBuilder: (_) => _menuItems(item),
        ),
      ),
    );
  }
}
