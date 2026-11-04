import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models.dart';
import '../../auth/auth_controller.dart';

final recommendationsProvider =
    AsyncNotifierProvider<RecommendationsController, RecommendationSnapshot>(
  RecommendationsController.new,
);

/// Loads the latest recommendation snapshot and polls while the backend is generating one.
class RecommendationsController extends AsyncNotifier<RecommendationSnapshot> {
  static const pollInterval = Duration(seconds: 2);
  Timer? _poll;

  @override
  Future<RecommendationSnapshot> build() async {
    ref.onDispose(() => _poll?.cancel());
    final api = ref.watch(apiProvider);
    var snapshot = await api.recommendations();
    if (snapshot.status == SnapshotStatus.idle) {
      // First visit: kick off a run.
      await api.refreshRecommendations();
      snapshot = await api.recommendations();
    }
    _schedulePoll(snapshot);
    return snapshot;
  }

  Future<void> refresh() async {
    final api = ref.read(apiProvider);
    await api.refreshRecommendations();
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(status: SnapshotStatus.queued));
    await _reload();
  }

  Future<void> _reload() async {
    try {
      final snapshot = await ref.read(apiProvider).recommendations();
      state = AsyncData(snapshot);
      _schedulePoll(snapshot);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void _schedulePoll(RecommendationSnapshot snapshot) {
    _poll?.cancel();
    if (snapshot.isWorking) _poll = Timer(pollInterval, _reload);
  }

  /// Marks an album and removes it from the visible list right away.
  Future<void> mark(Recommendation r, MarkKind kind) async {
    await ref.read(apiProvider).mark(r, kind);
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      sections: [for (final s in current.sections) s.without(r.spotifyAlbumId)],
    ));
  }

  Future<void> unmark(Recommendation r) async {
    await ref.read(apiProvider).unmark(r.spotifyAlbumId);
    await _reload();
  }
}
