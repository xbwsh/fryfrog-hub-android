import 'package:flutter/foundation.dart';

import '../../core/models/media_models.dart';
import '../../core/network/gateways.dart';
import '../../core/rules/watch_rules.dart';

/// Application-layer controller for the video detail use-case.
///
/// Owns load / pick-episode / favorite / watched orchestration so the
/// screen only renders state and forwards taps.
class VideoDetailController extends ChangeNotifier {
  VideoDetailController({required this.gateway, required this.item});

  final VideoGateway gateway;
  final SeriesListDto item;

  SeriesDetail? detail;
  List<VideoActorDto> actors = const [];
  VideoItem? selected;
  String? error;
  bool loading = true;
  bool busy = false;
  bool _disposed = false;

  String get _type => item.type == 'standalone' ? 'standalone' : 'series';

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final d = await gateway.fetchSeriesDetail(item.id, type: _type);
      final episodes = d.allEpisodes;
      selected = WatchRules.pickResumeEpisode<VideoItem>(
        episodes,
        hasProgress: (e) => e.hasProgress,
        isWatched: (e) => e.isWatched,
      );
      actors = const [];
      if (selected != null) {
        try {
          actors = await gateway.fetchVideoActors(selected!.id);
        } catch (_) {
          // Optional sugar.
        }
      }
      detail = d;
      loading = false;
      if (!_disposed) notifyListeners();
    } catch (e) {
      error = '$e';
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Silent refresh after play / favorite / watched.
  Future<void> refreshQuiet() async {
    try {
      final d = await gateway.fetchSeriesDetail(item.id, type: _type);
      final prevId = selected?.id;
      final match = prevId == null
          ? null
          : d.allEpisodes.cast<VideoItem?>().firstWhere(
              (e) => e!.id == prevId,
              orElse: () => null,
            );
      detail = d;
      if (match != null) selected = match;
      if (!_disposed) notifyListeners();
    } catch (_) {
      // Keep previous data.
    }
  }

  void selectOnly(VideoItem ep) {
    selected = ep;
    if (!_disposed) notifyListeners();
  }

  Future<void> toggleFavorite() async {
    final d = detail;
    if (d == null || busy) return;
    busy = true;
    if (!_disposed) notifyListeners();
    try {
      await gateway.setSeriesFavorite(d.id, status: !(d.favorite ?? false));
      await refreshQuiet();
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> markWatched(bool watched) async {
    final ep = selected;
    if (ep == null) return;
    try {
      await gateway.setWatched(ep.id, completed: watched);
      if (watched) {
        await gateway.deleteWatchProgress(ep.id);
      }
      await refreshQuiet();
    } catch (e) {
      error = '操作失败：$e';
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
