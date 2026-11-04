import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../auth/auth_controller.dart';
import '../../ui/theme.dart';
import '../../ui/vinyl.dart';
import '../recommendations/recommendations_controller.dart';

final marksProvider = FutureProvider.autoDispose<List<AlbumMark>>(
  (ref) => ref.watch(apiProvider).marks(),
);

/// Albums the user marked as owned or not interested; un-marking brings them back.
class MarksScreen extends ConsumerStatefulWidget {
  const MarksScreen({super.key});

  @override
  ConsumerState<MarksScreen> createState() => _MarksScreenState();
}

class _MarksScreenState extends ConsumerState<MarksScreen> {
  MarkKind _kind = MarkKind.owned;

  Future<void> _unmark(AlbumMark m) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiProvider).unmark(m.spotifyAlbumId);
      ref.invalidate(marksProvider);
      ref.invalidate(recommendationsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final marks = ref.watch(marksProvider);
    final all = marks.value ?? const <AlbumMark>[];
    int count(MarkKind k) => all.where((m) => m.kind == k).length;

    return Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const PageTitle(
              'Your Library',
              subtitle: "Records you own or hid. They won't be recommended.",
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(spacing: 8, children: [
                for (final (kind, label) in const [
                  (MarkKind.owned, 'Owned'),
                  (MarkKind.notInterested, 'Not interested'),
                ])
                  ChoiceChip(
                    label: Text(marks.hasValue ? '$label · ${count(kind)}' : label),
                    selected: _kind == kind,
                    onSelected: (_) => setState(() => _kind = kind),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: marks.when(
                loading: () => const LoadingRecord(),
                error: (e, _) => VinylMessage(icon: Icons.cloud_off, text: describeError(e)),
                data: (all) {
                  final items = all.where((m) => m.kind == _kind).toList();
                  if (items.isEmpty) {
                    return VinylMessage(
                      icon: _kind == MarkKind.owned ? Icons.check : Icons.visibility_off_outlined,
                      text: _kind == MarkKind.owned
                          ? 'Albums you mark as owned show up here.'
                          : 'Albums you hide show up here.',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _MarkTile(mark: items[i], onRestore: _unmark),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MarkTile extends StatelessWidget {
  const _MarkTile({required this.mark, required this.onRestore});

  final AlbumMark mark;
  final ValueChanged<AlbumMark> onRestore;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
      leading: SizedBox(
        width: 64,
        height: 56,
        child: SleeveCover(url: mark.coverUrl, radius: 4),
      ),
      title: Text(mark.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(mark.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Tooltip(
        message: 'Show in recommendations again',
        child: TextButton(
          style: TextButton.styleFrom(foregroundColor: Palette.subtext),
          onPressed: () => onRestore(mark),
          child: const Text('Restore'),
        ),
      ),
    );
  }
}
