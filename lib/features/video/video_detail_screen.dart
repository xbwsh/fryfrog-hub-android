import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/media_models.dart';
import '../../core/network/gateways.dart';
import '../../core/network/gateways_impl.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../widgets/server_image.dart';
import 'video_detail_controller.dart';
import 'video_player_screen.dart';

/// Detail for movies / TV series: metadata, episodes, play actions.
/// UI only — orchestration lives in [VideoDetailController].
class VideoDetailScreen extends StatefulWidget {
  const VideoDetailScreen({
    super.key,
    required this.session,
    required this.item,
  });

  final Session session;
  final SeriesListDto item;

  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen> {
  late final VideoDetailController _c;

  @override
  void initState() {
    super.initState();
    final api = widget.session.api;
    _c = VideoDetailController(
      gateway: api == null ? _NullVideoGateway() : ApiVideoGateway(api),
      item: widget.item,
    );
    _c.addListener(_onChanged);
    if (api == null) {
      _c.error = '未登录';
      _c.loading = false;
    } else {
      _c.load();
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _play({VideoItem? video, bool restart = false}) async {
    final target = video ?? _c.selected ?? _c.detail?.firstEpisode;
    if (target == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('暂无可播放内容')));
      return;
    }
    if (video != null) _c.selectOnly(video);
    final start = restart ? 0.0 : (target.watchPosition ?? 0);
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => VideoPlayerScreen(
          session: widget.session,
          video: target,
          title: target.title,
          startPosition: start,
        ),
      ),
    );
    if (!mounted) return;
    await _c.refreshQuiet();
  }

  Future<void> _toggleFavorite() async {
    try {
      await _c.toggleFavorite();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('收藏失败：$e')));
      }
    }
  }

  Future<void> _markWatched(bool watched) async {
    try {
      await _c.markWatched(watched);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);
    final detail = _c.detail;

    // Light icons: hero image is dark under the status bar.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        // Hero fills from y=0 so the backdrop sits under the status bar.
        extendBodyBehindAppBar: true,
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: Colors.white,
          title: Text(
            detail?.displayTitle ?? widget.item.displayTitle,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
            ),
          ),
          actions: [
            if (detail != null)
              IconButton(
                tooltip: (detail.favorite ?? false) ? '取消收藏' : '收藏',
                icon: Icon(
                  (detail.favorite ?? false)
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: (detail.favorite ?? false)
                      ? AppColors.danger
                      : Colors.white,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
                ),
                onPressed: _c.busy ? null : _toggleFavorite,
              ),
            IconButton(
              tooltip: '刷新',
              icon: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
              ),
              onPressed: _c.loading ? null : _c.load,
            ),
          ],
        ),
        body: _c.loading
            ? const SafeArea(
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accent,
                    strokeWidth: 2.5,
                  ),
                ),
              )
            : _c.error != null
            ? SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Dimens.spacingXl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _c.error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14 * form.typeScale,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                        const SizedBox(height: Dimens.spacingLg),
                        FilledButton(
                          onPressed: _c.load,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : _DetailView(
                detail: detail!,
                selected: _c.selected,
                actors: _c.actors,
                form: form,
                session: widget.session,
                onPlay: () => _play(),
                onPlayRestart: () => _play(restart: true),
                onSelectEpisode: (ep) => _play(video: ep),
                onSelectOnly: _c.selectOnly,
                onMarkWatched: _markWatched,
              ),
      ),
    );
  }
}

/// Fail-fast stub when Session has no ApiClient (e.g. unit hosts).
class _NullVideoGateway implements VideoGateway {
  @override
  Future<SeriesDetail> fetchSeriesDetail(int id, {String? type}) =>
      throw UnsupportedError('not logged in');

  @override
  Future<VideoItem> fetchVideoDetail(int id) =>
      throw UnsupportedError('not logged in');

  @override
  Future<List<VideoActorDto>> fetchVideoActors(int id) =>
      throw UnsupportedError('not logged in');

  @override
  Future<void> saveWatchProgress(
    int videoId, {
    required double position,
    double? duration,
  }) => throw UnsupportedError('not logged in');

  @override
  Future<void> setWatched(int videoId, {required bool completed}) =>
      throw UnsupportedError('not logged in');

  @override
  Future<void> deleteWatchProgress(int videoId) =>
      throw UnsupportedError('not logged in');

  @override
  Future<void> setSeriesFavorite(int id, {required bool status}) =>
      throw UnsupportedError('not logged in');

  @override
  String streamUrlFor(VideoItem video) => '';
}

class _DetailView extends StatelessWidget {
  const _DetailView({
    required this.detail,
    required this.selected,
    required this.actors,
    required this.form,
    required this.session,
    required this.onPlay,
    required this.onPlayRestart,
    required this.onSelectEpisode,
    required this.onSelectOnly,
    required this.onMarkWatched,
  });

  final SeriesDetail detail;
  final VideoItem? selected;
  final List<VideoActorDto> actors;
  final DeviceForm form;
  final Session session;
  final VoidCallback onPlay;
  final VoidCallback onPlayRestart;
  final ValueChanged<VideoItem> onSelectEpisode;
  final ValueChanged<VideoItem> onSelectOnly;
  final ValueChanged<bool> onMarkWatched;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ep = selected;
    final backdrop = ep?.fanartUrl ?? detail.fanartUrl ?? detail.coverUrl;
    final poster = ep?.coverUrl ?? detail.coverUrl;
    final progress = (ep?.watchProgressPercent ?? 0) / 100;
    final isDone = ep?.watched == true || progress >= 1;
    final showBadge = isDone || progress > 0;
    final resumeLabel = ep == null
        ? '播放'
        : (ep.watched == true
              ? '重新播放'
              : (ep.watchPosition != null && ep.watchPosition! > 1)
              ? '继续播放'
              : '播放');

    return CustomScrollView(
      slivers: [
        // ---- Hero ----
        SliverToBoxAdapter(
          child: SizedBox(
          height: Dimens.videoHeroHeight * form.posterScale,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ServerImage(
                url: backdrop,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.zero,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: Dimens.spacingLg,
                right: Dimens.spacingLg,
                bottom: Dimens.spacingLg,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: Dimens.videoPosterWidth * form.posterScale,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Dimens.radiusMd),
                        child: AspectRatio(
                          aspectRatio: 2 / 3,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ServerImage(
                                url: poster,
                                fit: BoxFit.cover,
                                borderRadius: BorderRadius.circular(
                                  Dimens.radiusMd,
                                ),
                              ),
                              if (showBadge)
                                Positioned(
                                  right: Dimens.spacingSm,
                                  bottom: Dimens.spacingSm,
                                  child: _ProgressBadge(
                                    value: progress.clamp(0.0, 1.0),
                                    completed: isDone,
                                    size:
                                        Dimens.videoProgressRing *
                                        form.posterScale,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Dimens.spacingLg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            detail.displayTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20 * form.typeScale,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: Dimens.spacingXs),
                          Text(
                            _metaLine(detail, ep),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12 * form.typeScale,
                            ),
                          ),
                          const SizedBox(height: Dimens.spacingMd),
                          Wrap(
                            spacing: Dimens.spacingSm,
                            runSpacing: Dimens.spacingSm,
                            children: [
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  minimumSize: Size(0, 42 * form.posterScale),
                                ),
                                onPressed: onPlay,
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: Text(resumeLabel),
                              ),
                              if ((ep?.watchPosition ?? 0) > 1 &&
                                  ep?.watched != true)
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    minimumSize: Size(0, 42 * form.posterScale),
                                  ),
                                  onPressed: onPlayRestart,
                                  icon: const Icon(
                                    Icons.replay_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('从头播放'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            Dimens.spacingLg,
            Dimens.spacingLg,
            Dimens.spacingLg,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              if (detail.overview != null && detail.overview!.isNotEmpty) ...[
                Text(
                  '简介',
                  style: TextStyle(
                    fontSize: 16 * form.typeScale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Dimens.spacingSm),
                Text(
                  detail.overview!,
                  style: TextStyle(
                    fontSize: 14 * form.typeScale,
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: Dimens.spacingXl),
              ],
              if (ep != null && (ep.director != null || ep.actors != null)) ...[
                Text(
                  '主创',
                  style: TextStyle(
                    fontSize: 16 * form.typeScale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Dimens.spacingSm),
                if (ep.director != null && ep.director!.isNotEmpty)
                  Text(
                    '导演：${ep.director}',
                    style: TextStyle(
                      fontSize: 13 * form.typeScale,
                      height: 1.4,
                    ),
                  ),
                if (ep.actors != null && ep.actors!.isNotEmpty)
                  Text(
                    '主演：${ep.actors}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13 * form.typeScale,
                      height: 1.4,
                      color: theme.hintColor,
                    ),
                  ),
                const SizedBox(height: Dimens.spacingMd),
              ],
              if (actors.isNotEmpty) ...[
                Text(
                  '演职人员',
                  style: TextStyle(
                    fontSize: 16 * form.typeScale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Dimens.spacingMd),
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: actors.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: Dimens.spacingMd),
                    itemBuilder: (context, i) {
                      final a = actors[i];
                      return SizedBox(
                        width: 72,
                        child: Column(
                          children: [
                            SizedBox(
                              width: 56,
                              height: 56,
                              child: ClipOval(
                                child: ServerImage(
                                  url: a.imageUrl,
                                  fit: BoxFit.cover,
                                  borderRadius: BorderRadius.zero,
                                ),
                              ),
                            ),
                            const SizedBox(height: Dimens.spacingXs),
                            Text(
                              a.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11 * form.typeScale),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: Dimens.spacingXl),
              ],
              if (ep != null && (ep.isWatched || ep.hasProgress)) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ep.isWatched
                            ? '已看完'
                            : '已看 ${(ep.watchProgressPercent ?? 0).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 13 * form.typeScale,
                          color: ep.isWatched
                              ? AppColors.success
                              : theme.hintColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => onMarkWatched(!ep.isWatched),
                      child: Text(ep.isWatched ? '标为未看' : '标为已看'),
                    ),
                  ],
                ),
                const SizedBox(height: Dimens.spacingSm),
              ],
            ],
          ),
        ),
        ),
        if (detail.seasons.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Dimens.spacingLg,
              0,
              Dimens.spacingLg,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.isStandalone
                        ? '正片'
                        : '剧集 · ${detail.episodeCount ?? detail.allEpisodes.length}',
                    style: TextStyle(
                      fontSize: 16 * form.typeScale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Dimens.spacingSm),
                ],
              ),
            ),
          ),
          for (final season in detail.seasons) ...[
            if (detail.seasons.length > 1)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  Dimens.spacingLg,
                  Dimens.spacingSm,
                  Dimens.spacingLg,
                  Dimens.spacingXs,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '第 ${season.seasonNumber} 季',
                    style: TextStyle(
                      fontSize: 14 * form.typeScale,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimens.spacingLg,
              ),
              sliver: SliverList.builder(
                itemCount: season.episodes.length,
                itemBuilder: (context, i) {
                  final e = season.episodes[i];
                  // Clip to the same radius as the surface fill — otherwise
                  // the selected/ink tint paints square corners over the
                  // rounded card (very visible in dark mode).
                  final radius = BorderRadius.vertical(
                    top: i == 0
                        ? Radius.circular(Dimens.radiusLg)
                        : Radius.zero,
                    bottom: i == season.episodes.length - 1
                        ? Radius.circular(Dimens.radiusLg)
                        : Radius.zero,
                  );
                  return ClipRRect(
                    key: ValueKey(e.id),
                    borderRadius: radius,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: radius,
                      ),
                      child: _EpisodeTile(
                        episode: e,
                        selected: selected?.id == e.id,
                        form: form,
                        onTap: () => onSelectEpisode(e),
                        onLongPress: () => onSelectOnly(e),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
        const SliverToBoxAdapter(child: SizedBox(height: Dimens.spacingXxl)),
        const SliverToBoxAdapter(child: SizedBox(height: Dimens.spacingLg)),
      ],
    );
  }

  String _metaLine(SeriesDetail detail, VideoItem? ep) {
    final parts = <String>[
      if (detail.year != null) '${detail.year}',
      if (detail.rating != null && detail.rating! > 0)
        '★ ${detail.rating!.toStringAsFixed(1)}',
      if (!detail.isStandalone && (detail.episodeCount ?? 0) > 0)
        '${detail.episodeCount} 集',
      if (ep?.episodeNumber != null) '第 ${ep!.episodeNumber} 集',
      if (ep?.resolutionLabel != null) ep!.resolutionLabel!,
      if (ep?.genre != null && ep!.genre!.isNotEmpty)
        ep.genre!.split(RegExp(r'[,/·]')).first.trim(),
      if (detail.status != null &&
          detail.status!.isNotEmpty &&
          detail.status!.toLowerCase() != 'released')
        detail.status!,
    ];
    return parts.join(' · ');
  }
}

/// Watch badge on the hero poster: percent ring, or green check when done.
class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({
    required this.value,
    required this.completed,
    required this.size,
  });

  /// 0..1 while watching.
  final double value;
  final bool completed;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (completed) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 6,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.check_rounded,
          color: Colors.white,
          size: size * 0.52,
        ),
      );
    }

    final pct = (value * 100).round();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 3.5,
              backgroundColor: Colors.white24,
              color: AppColors.accent,
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            '$pct%',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.26,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    required this.episode,
    required this.selected,
    required this.form,
    required this.onTap,
    required this.onLongPress,
  });

  final VideoItem episode;
  final bool selected;
  final DeviceForm form;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (episode.watchProgressPercent ?? 0) / 100;

    return Material(
      color: selected ? theme.colorScheme.primary.withValues(alpha: 0.1) : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimens.spacingMd,
            vertical: Dimens.spacingSm,
          ),
          child: Row(
            children: [
              SizedBox(
                width: Dimens.videoEpisodeThumbWidth * 0.55,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Dimens.radiusSm),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ServerImage(
                          url: episode.fanartUrl ?? episode.coverUrl,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(Dimens.radiusSm),
                        ),
                        if (episode.isWatched)
                          Container(
                            color: Colors.black45,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.success,
                              size: 22,
                            ),
                          ),
                        if (progress > 0 && progress < 1)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              minHeight: 3,
                              backgroundColor: Colors.black45,
                              color: AppColors.accent,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Dimens.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      episode.episodeNumber != null
                          ? '${episode.episodeLabel} · ${episode.title}'
                          : episode.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13 * form.typeScale,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    if (episode.durationMinutes != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${episode.durationMinutes} 分钟',
                        style: TextStyle(
                          fontSize: 11 * form.typeScale,
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Dimens.spacingSm),
              Icon(
                Icons.play_circle_outline_rounded,
                size: 26 * form.posterScale,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
