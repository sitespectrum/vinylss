import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../auth/auth_controller.dart';
import '../../ui/theme.dart';
import '../../ui/vinyl.dart';
import '../recommendations/recommendations_controller.dart';

final settingsProvider = FutureProvider.autoDispose<UserSettings>(
  (ref) => ref.watch(apiProvider).settings(),
);

final discogsStatusProvider = FutureProvider.autoDispose<DiscogsStatus>(
  (ref) => ref.watch(apiProvider).discogs(),
);

final meProvider = FutureProvider.autoDispose<Me>((ref) => ref.watch(apiProvider).me());

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  UserSettings? _draft;
  bool _saving = false;

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref.read(apiProvider).saveSettings(draft);
      ref.invalidate(settingsProvider);
      if (mounted) setState(() => _draft = null);
      await ref.read(recommendationsProvider.notifier).refresh();
      router.go('/');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loaded = ref.watch(settingsProvider);
    final s = _draft ?? loaded.value;
    void update(String key, Object value) => setState(() => _draft = s!.set(key, value));

    return Scaffold(
      bottomNavigationBar: _SaveBar(
        visible: _draft != null,
        saving: _saving,
        onDiscard: () => setState(() => _draft = null),
        onSave: _save,
      ),
      body: s == null
          ? Center(
              child: loaded.hasError
                  ? Text(describeError(loaded.error!))
                  : const LoadingRecord(),
            )
          : Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(children: [
                  const PageTitle('Settings'),
                  const _Header('Recommendation types'),
                  _Group([
                    SwitchListTile(
                      title: const Text('Albums you already love'),
                      subtitle: const Text('Records containing many of the tracks you play'),
                      value: s.flag('mostListenedEnabled'),
                      onChanged: (v) => update('mostListenedEnabled', v),
                    ),
                    _SliderTile(
                      title: 'Minimum tracks you play',
                      value: s.number('minMatchedTracks').toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: (v) => v.round().toString(),
                      enabled: s.flag('mostListenedEnabled'),
                      onChanged: (v) => update('minMatchedTracks', v.round()),
                    ),
                    SwitchListTile(
                      title: const Text('Deep cuts from favourite artists'),
                      subtitle: const Text("Albums by top artists you haven't explored"),
                      value: s.flag('deepCutsEnabled'),
                      onChanged: (v) => update('deepCutsEnabled', v),
                    ),
                    _SliderTile(
                      title: 'Max share of album already heard',
                      value: s.number('deepCutsMaxCoverage').toDouble(),
                      min: 0,
                      max: 0.5,
                      divisions: 10,
                      label: (v) => '${(v * 100).round()}%',
                      enabled: s.flag('deepCutsEnabled'),
                      onChanged: (v) => update('deepCutsMaxCoverage', double.parse(v.toStringAsFixed(2))),
                    ),
                    _SliderTile(
                      title: 'Top artists to explore',
                      value: s.number('topArtistsToExplore').toDouble(),
                      min: 0,
                      max: 50,
                      divisions: 10,
                      label: (v) => v.round().toString(),
                      onChanged: (v) => update('topArtistsToExplore', v.round()),
                    ),
                  ]),
                  const _Header('Listening history to use'),
                  _Group([
                    for (final (key, label) in const [
                      ('useTopTracksLongTerm', 'Top tracks: all time'),
                      ('useTopTracksMediumTerm', 'Top tracks: last 6 months'),
                      ('useTopTracksShortTerm', 'Top tracks: last 4 weeks'),
                      ('useSavedTracks', 'Liked songs'),
                      ('useRecentlyPlayed', 'Recently played'),
                    ])
                      CheckboxListTile(
                        title: Text(label),
                        value: s.flag(key),
                        onChanged: (v) => update(key, v ?? false),
                      ),
                  ]),
                  const _Header('Album types'),
                  _Group([
                    SwitchListTile(
                      title: const Text('Include singles & EPs'),
                      value: s.flag('includeSinglesAndEps'),
                      onChanged: (v) => update('includeSinglesAndEps', v),
                    ),
                    SwitchListTile(
                      title: const Text('Include compilations'),
                      value: s.flag('includeCompilations'),
                      onChanged: (v) => update('includeCompilations', v),
                    ),
                  ]),
                  const _Header('Vinyl'),
                  _Group([
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: SegmentedButton<VinylMode>(
                        showSelectedIcon: false,
                        expandedInsets: EdgeInsets.zero,
                        segments: const [
                          ButtonSegment(value: VinylMode.onlyVinyl, label: Text('Vinyl only')),
                          ButtonSegment(value: VinylMode.preferVinyl, label: Text('Prefer vinyl')),
                          ButtonSegment(value: VinylMode.ignore, label: Text('Any album')),
                        ],
                        selected: {s.vinylMode},
                        onSelectionChanged: (v) => update('vinylMode', v.first),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        switch (s.vinylMode) {
                          VinylMode.onlyVinyl => 'Only albums with a vinyl pressing on Discogs.',
                          VinylMode.preferVinyl =>
                            'Albums without a known pressing are shown, but ranked lower.',
                          VinylMode.ignore => 'Skip Discogs and just recommend albums.',
                        },
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    _SliderTile(
                      title: 'Albums per section',
                      value: s.number('maxResultsPerSection').toDouble(),
                      min: 10,
                      max: 100,
                      divisions: 9,
                      label: (v) => v.round().toString(),
                      onChanged: (v) => update('maxResultsPerSection', v.round()),
                    ),
                  ]),
                  const _Header('Discogs collection'),
                  _Group([
                    const _DiscogsTile(),
                    SwitchListTile(
                      title: const Text('Hide records in my collection'),
                      subtitle: const Text('Uses your last synced Discogs collection'),
                      value: s.flag('excludeDiscogsCollection'),
                      onChanged: (v) => update('excludeDiscogsCollection', v),
                    ),
                  ]),
                  const _Header('Account'),
                  const _Group([_AccountTile()]),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
    );
  }
}

/// Slides up when there are unsaved changes.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.visible,
    required this.saving,
    required this.onDiscard,
    required this.onSave,
  });

  final bool visible;
  final bool saving;
  final VoidCallback onDiscard;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final bar = Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: Material(
        color: Palette.elevated,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(children: [
            Expanded(
              child: Text('Unsaved changes', style: Theme.of(context).textTheme.titleSmall),
            ),
            TextButton(onPressed: saving ? null : onDiscard, child: const Text('Discard')),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: saving ? null : onSave,
              child: Text(saving ? 'Saving…' : 'Save & refresh'),
            ),
          ]),
        ),
      ),
    );
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: visible ? bar : const SizedBox(width: double.infinity),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 16, 8),
        child: Text(text.toUpperCase(),
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Palette.muted, letterSpacing: 1.6)),
      );
}

/// Rounded panel holding one settings section.
class _Group extends StatelessWidget {
  const _Group(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Material(
          color: Palette.surface,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      );
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
    this.enabled = true,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) label;
  final ValueChanged<double> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(min, max);
    final text = Theme.of(context).textTheme;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(title, style: text.bodyLarge)),
            Text(label(v), style: text.titleSmall?.copyWith(color: Palette.accent)),
          ]),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(padding: const EdgeInsets.symmetric(vertical: 12)),
            child: Slider(
              value: v,
              min: min,
              max: max,
              divisions: divisions,
              label: label(v),
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ]),
      ),
    );
  }
}

class _DiscogsTile extends ConsumerStatefulWidget {
  const _DiscogsTile();

  @override
  ConsumerState<_DiscogsTile> createState() => _DiscogsTileState();
}

class _DiscogsTileState extends ConsumerState<_DiscogsTile> {
  final _username = TextEditingController();
  bool _busy = false;
  bool _initialized = false;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      ref.invalidate(discogsStatusProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(discogsStatusProvider).value;
    if (status != null && !_initialized) {
      _username.text = status.username ?? '';
      _initialized = true;
    }
    final api = ref.read(apiProvider);
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (status != null && !status.configured)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Discogs is not configured on the server; vinyl lookups are disabled.',
                style: text.bodySmall),
          ),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _username,
              decoration: const InputDecoration(labelText: 'Discogs username'),
              onSubmitted: (_) => _run(() => api.setDiscogsUsername(_username.text)),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder(
            valueListenable: _username,
            builder: (context, value, _) {
              final linked = status?.username != null && value.text.trim() == status!.username;
              return OutlinedButton(
                onPressed: _busy || linked || value.text.trim().isEmpty
                    ? null
                    : () => _run(() => api.setDiscogsUsername(_username.text.trim())),
                child: Text(linked ? 'Linked' : 'Link'),
              );
            },
          ),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: Text(
              status?.username == null
                  ? 'Link your account to hide records you already own.'
                  : status!.lastSync == null
                      ? 'Not synced yet'
                      : '${status.itemCount} records · synced ${_ago(status.lastSync!)}',
              style: text.bodySmall,
            ),
          ),
          TextButton.icon(
            onPressed: _busy || status?.username == null ? null : () => _run(api.syncDiscogs),
            icon: _busy
                ? const SizedBox.square(
                    dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync, size: 18),
            label: const Text('Sync now'),
          ),
        ]),
      ]),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${d.inDays} days ago';
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).value;
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: me?.avatarUrl == null ? null : NetworkImage(me!.avatarUrl!),
        child: me?.avatarUrl == null ? const Icon(Icons.person) : null,
      ),
      title: Text(me?.displayName ?? 'Spotify account'),
      subtitle: const Text('Connected to Spotify'),
      trailing: TextButton(
        onPressed: () => ref.read(authProvider.notifier).logout(),
        child: const Text('Log out'),
      ),
    );
  }
}
