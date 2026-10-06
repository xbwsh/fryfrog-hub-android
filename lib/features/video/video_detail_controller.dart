import 'package:flutter/foundation.dart';

import '../../core/models/media_models.dart';
import '../../core/network/api_client.dart';
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

  /// 本页发生过会改库的操作（绑定/解绑/改元数据/换封面/Logo）。返回上级时
  /// 用它决定要不要让列表重载——否则新名字要杀进程才看得到。
  bool mutated = false;

  /// 标记发生了写操作。
  void markMutated() {
    mutated = true;
  }

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

  // ── Admin actions (TMDB / covers / logo) ─────────────────────────────

  /// video-table id the admin ops act on: current selection, else the first
  /// episode (for standalone that is the movie itself — never the series id).
  int? get targetVideoId => selected?.id ?? detail?.firstEpisode?.id;

  void _ensureIdle() {
    if (busy) throw ApiException(400, '操作进行中，请稍候');
  }

  int _requireVideoId() {
    final id = targetVideoId;
    if (id == null) throw ApiException(400, '无法确定视频条目');
    return id;
  }

  SeriesDetail _requireDetail() {
    final d = detail;
    if (d == null) throw ApiException(400, '详情尚未加载');
    return d;
  }

  Future<List<TmdbSearchItem>> searchTmdb(String q) => gateway.searchTmdb(q);

  /// Bind TMDB then poll the background job until it stops.
  /// Backend job module: `bind:{videoId}`.
  Future<void> bindTmdbWithPoll({
    required int tmdbId,
    required String mediaType,
  }) async {
    _ensureIdle();
    final videoId = _requireVideoId();
    busy = true;
    if (!_disposed) notifyListeners();
    try {
      await gateway.bindTmdb(videoId, tmdbId: tmdbId, mediaType: mediaType);
      await _pollBindJob(videoId);
      mutated = true;
      await refreshQuiet();
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Poll every 1.5s, at most 40 times. Polling is best-effort: a failed
  /// progress fetch ends the wait instead of failing the whole operation.
  Future<void> _pollBindJob(int videoId) async {
    for (var i = 0; i < 40; i++) {
      ScrapeProgress progress;
      try {
        progress = await gateway.fetchScrapeProgress('bind:$videoId');
      } catch (_) {
        return;
      }
      if (!progress.running) return;
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    }
  }

  /// Returns how many bindings were removed.
  Future<int> unbind() async {
    _ensureIdle();
    final videoId = _requireVideoId();
    busy = true;
    if (!_disposed) notifyListeners();
    try {
      final unbound = await gateway.unbindTmdb(videoId);
      mutated = true;
      await refreshQuiet();
      return unbound;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// [body] only contains non-null fields the dialog actually edited.
  Future<void> updateMetadata(Map<String, dynamic> body) async {
    _ensureIdle();
    final d = _requireDetail();
    busy = true;
    if (!_disposed) notifyListeners();
    try {
      if (d.isStandalone) {
        await gateway.updateVideoMetadata(_requireVideoId(), body);
      } else {
        await gateway.updateSeriesMetadata(d.id, body);
      }
      mutated = true;
      await refreshQuiet();
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Series-only, slow (~minutes) — ApiClient allows 300s for this call.
  Future<SeasonRefreshResult> refreshSeasonCovers() async {
    _ensureIdle();
    final d = _requireDetail();
    if (d.isStandalone) throw ApiException(400, '仅剧集支持刷新季海报');
    busy = true;
    if (!_disposed) notifyListeners();
    try {
      final result = await gateway.refreshSeasonCovers(d.id);
      mutated = true;
      await refreshQuiet();
      return result;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Auto-download the best TMDB logo. Returns whether one was downloaded.
  Future<bool> fillLogo() async {
    _ensureIdle();
    final d = _requireDetail();
    if (d.tmdbId == null) throw ApiException(400, '尚未绑定 TMDB');
    busy = true;
    if (!_disposed) notifyListeners();
    try {
      final ok = d.isStandalone
          ? await gateway.refreshVideoLogo(_requireVideoId())
          : await gateway.refreshSeriesLogo(d.id);
      mutated = true;
      await refreshQuiet();
      return ok;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<List<LogoOption>> fetchLogoOptions() async {
    _ensureIdle();
    final d = _requireDetail();
    if (d.tmdbId == null) throw ApiException(400, '尚未绑定 TMDB');
    busy = true;
    if (!_disposed) notifyListeners();
    try {
      return d.isStandalone
          ? await gateway.fetchVideoLogoOptions(_requireVideoId())
          : await gateway.fetchSeriesLogoOptions(d.id);
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> pickLogo(String filePath) async {
    _ensureIdle();
    final d = _requireDetail();
    busy = true;
    if (!_disposed) notifyListeners();
    try {
      if (d.isStandalone) {
        await gateway.setVideoLogo(_requireVideoId(), filePath: filePath);
      } else {
        await gateway.setSeriesLogo(d.id, filePath: filePath);
      }
      mutated = true;
      await refreshQuiet();
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Pull covers from TMDB for the selected video. false = backend said no.
  Future<bool> downloadCovers() async {
    _ensureIdle();
    final videoId = _requireVideoId();
    busy = true;
    if (!_disposed) notifyListeners();
    try {
      final ok = await gateway.downloadVideoCovers(videoId);
      mutated = true;
      await refreshQuiet();
      return ok;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// 本集在 TMDB 的横屏图（本集剧照 still）候选。
  Future<List<CoverOption>> fetchCoverOptions() async {
    _ensureIdle();
    final videoId = _requireVideoId();
    busy = true;
    if (!_disposed) notifyListeners();
    try {
      return await gateway.fetchVideoCoverOptions(videoId);
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// 把选中的 TMDB 图应用为本集横屏封面。
  Future<void> applyCover(String filePath) async {
    _ensureIdle();
    final videoId = _requireVideoId();
    busy = true;
    if (!_disposed) notifyListeners();
    try {
      await gateway.setVideoCover(videoId, filePath: filePath);
      mutated = true;
      await refreshQuiet();
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<List<FrameCandidate>> generateFrames() async {    _ensureIdle();
    final videoId = _requireVideoId();
    busy = true;
    if (!_disposed) notifyListeners();
    try {
      return await gateway.generateFrameCandidates(videoId);
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// [type] = poster | fanart.
  Future<void> selectFrame(int index, {required String type}) async {
    _ensureIdle();
    final videoId = _requireVideoId();
    busy = true;
    if (!_disposed) notifyListeners();
    try {
      await gateway.selectFrame(videoId, index: index, type: type);
      mutated = true;
      await refreshQuiet();
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
