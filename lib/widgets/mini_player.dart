import 'package:flutter/material.dart';

import '../core/adaptive/device_form.dart';
import '../core/audio/audio_playback_controller.dart';
import '../core/rules/lyrics_rules.dart';
import '../core/state/session.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/dimens.dart';
import 'server_image.dart';

/// Shared audio strip used by every app shell. It observes Session without
/// creating the native player and appears after the first playback request.
class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final audio = session.audioController;
      if (audio == null) return const SizedBox.shrink();
      return ListenableBuilder(
        listenable: audio,
        builder: (context, _) {
          final item = audio.nowPlaying;
          if (item == null) return const SizedBox.shrink();
          return _MiniPlayerContent(
            session: session,
            controller: audio,
            item: item,
          );
        },
      );
    },
  );
}

class _MiniPlayerContent extends StatelessWidget {
  const _MiniPlayerContent({
    required this.session,
    required this.controller,
    required this.item,
  });

  final Session session;
  final AudioPlaybackController controller;
  final AudioNowPlaying item;

  void _openPanel(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          _AudioPlayerSheet(session: session, controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);
    final theme = Theme.of(context);
    final subText = controller.error ?? item.subtitle;
    return Material(
      key: const ValueKey('audio-mini-player'),
      color: AppColors.surface(context),
      elevation: 4,
      borderRadius: BorderRadius.circular(Dimens.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(Dimens.radiusLg),
        onTap: () => _openPanel(context),
        child: Container(
          height: Dimens.audioMiniHeight,
          padding: const EdgeInsets.symmetric(horizontal: Dimens.spacingSm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimens.radiusLg),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: Dimens.audioMiniCoverSize,
                height: Dimens.audioMiniCoverSize,
                child: ServerImage(
                  url: item.coverUrl,
                  session: session,
                  borderRadius: BorderRadius.circular(Dimens.radiusSm),
                ),
              ),
              const SizedBox(width: Dimens.spacingSm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13 * form.typeScale,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: Dimens.spacingXs),
                    Text(
                      subText.isEmpty ? '正在播放' : subText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11 * form.typeScale,
                        color: controller.error == null
                            ? theme.hintColor
                            : theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              if (controller.isBuffering)
                SizedBox.square(
                  dimension: Dimens.audioMiniProgressSize,
                  child: CircularProgressIndicator(
                    strokeWidth: Dimens.audioMiniProgressStroke,
                    color: theme.colorScheme.primary,
                  ),
                )
              else ...[
                IconButton(
                  tooltip: '上一首',
                  visualDensity: VisualDensity.compact,
                  onPressed: controller.hasPrevious
                      ? controller.playPrevious
                      : null,
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
                IconButton(
                  tooltip: controller.isPlaying ? '暂停' : '播放',
                  visualDensity: VisualDensity.compact,
                  onPressed: controller.togglePlayback,
                  icon: Icon(
                    controller.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: Dimens.audioMiniIconSize,
                  ),
                ),
                IconButton(
                  tooltip: '下一首',
                  visualDensity: VisualDensity.compact,
                  onPressed: controller.hasNext ? controller.playNext : null,
                  icon: const Icon(Icons.skip_next_rounded),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioPlayerSheet extends StatefulWidget {
  const _AudioPlayerSheet({required this.session, required this.controller});

  final Session session;
  final AudioPlaybackController controller;

  @override
  State<_AudioPlayerSheet> createState() => _AudioPlayerSheetState();
}

class _AudioPlayerSheetState extends State<_AudioPlayerSheet> {
  Duration? _preview;
  int _lyricsRequestVersion = 0;
  int? _lyricsSongId;
  bool _showLyrics = false;
  bool _lyricsLoading = false;
  String? _lyricsError;
  String? _lyricsText;
  List<TimedLyricLine>? _timedLyrics;

  @override
  void initState() {
    super.initState();
    _lyricsSongId = widget.controller.nowPlaying?.songId;
    widget.controller.addListener(_handlePlaybackChanged);
  }

  @override
  void didUpdateWidget(covariant _AudioPlayerSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handlePlaybackChanged);
      widget.controller.addListener(_handlePlaybackChanged);
      _lyricsSongId = widget.controller.nowPlaying?.songId;
      _resetLyrics();
    }
  }

  void _handlePlaybackChanged() {
    final songId = widget.controller.nowPlaying?.songId;
    if (songId == _lyricsSongId) return;
    _lyricsSongId = songId;
    _resetLyrics();
  }

  void _resetLyrics() {
    _lyricsRequestVersion++;
    if (!mounted) return;
    setState(() {
      _showLyrics = false;
      _lyricsLoading = false;
      _lyricsError = null;
      _lyricsText = null;
      _timedLyrics = null;
      _preview = null;
    });
  }

  void _setLyricsVisible(bool visible, int? songId) {
    setState(() => _showLyrics = visible);
    if (visible && songId != null && _lyricsText == null && !_lyricsLoading) {
      _loadLyrics(songId);
    }
  }

  Future<void> _loadLyrics(int songId) async {
    final request = ++_lyricsRequestVersion;
    setState(() {
      _lyricsLoading = true;
      _lyricsError = null;
      _lyricsText = null;
      _timedLyrics = null;
    });
    try {
      final api = widget.session.api;
      if (api == null) throw StateError('请先登录');
      final lyrics = await api.fetchMusicLyrics(songId);
      if (!_isCurrentLyricsRequest(request, songId)) return;
      setState(() {
        _lyricsText = lyrics;
        _timedLyrics = parseLrc(lyrics);
        _lyricsLoading = false;
      });
    } catch (_) {
      if (!_isCurrentLyricsRequest(request, songId)) return;
      setState(() {
        _lyricsError = '歌词加载失败，请检查网络后重试';
        _lyricsLoading = false;
      });
    }
  }

  bool _isCurrentLyricsRequest(int request, int songId) =>
      mounted &&
      request == _lyricsRequestVersion &&
      widget.controller.nowPlaying?.songId == songId;

  Widget _lyricsContent(BuildContext context, ThemeData theme, int? songId) {
    final typeScale = AdaptiveScope.of(context).typeScale;
    final style = TextStyle(
      fontSize: 14 * typeScale,
      color: theme.colorScheme.onSurface,
    );
    final borderRadius = BorderRadius.circular(Dimens.radiusLg);

    Widget child;
    if (songId == null) {
      child = const Center(child: Text('当前歌曲暂不支持歌词'));
    } else if (_lyricsLoading) {
      child = const Center(child: CircularProgressIndicator());
    } else if (_lyricsError != null) {
      child = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_lyricsError!, textAlign: TextAlign.center, style: style),
          TextButton.icon(
            onPressed: () => _loadLyrics(songId),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
          ),
        ],
      );
    } else if (_lyricsText == null) {
      child = const Center(child: Text('正在准备歌词'));
    } else if (_lyricsText!.trim().isEmpty) {
      child = const Center(child: Text('暂无歌词'));
    } else {
      final timed = _timedLyrics ?? const <TimedLyricLine>[];
      child = timed.isEmpty
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(Dimens.spacingMd),
              child: Text(_lyricsText!.trim(), style: style),
            )
          : _TimedLyricsList(
              lines: timed,
              position: widget.controller.position,
              typeScale: typeScale,
            );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.all(Dimens.spacingMd),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _lyricsRequestVersion++;
    widget.controller.removeListener(_handlePlaybackChanged);
    super.dispose();
  }

  String _format(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (minutes >= 60) {
      final hours = value.inHours;
      final remainingMinutes = value.inMinutes
          .remainder(60)
          .toString()
          .padLeft(2, '0');
      return '$hours:$remainingMinutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final item = widget.controller.nowPlaying;
      if (item == null) return const SizedBox.shrink();
      final form = AdaptiveScope.of(context);
      final theme = Theme.of(context);
      final duration = widget.controller.duration;
      final shownPosition = _preview ?? widget.controller.position;
      final maxMs = duration.inMilliseconds > 0
          ? duration.inMilliseconds.toDouble()
          : 1.0;
      final value = shownPosition.inMilliseconds
          .toDouble()
          .clamp(0, maxMs)
          .toDouble();
      final coverSize =
          (MediaQuery.sizeOf(context).width *
                  Dimens.audioPanelCoverWidthFraction)
              .clamp(Dimens.audioPanelCoverMin, Dimens.audioPanelCoverMax)
              .toDouble();

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Dimens.spacingXl,
          Dimens.spacingSm,
          Dimens.spacingXl,
          Dimens.spacingXl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21 * form.typeScale,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (item.subtitle.isNotEmpty) ...[
              const SizedBox(height: Dimens.spacingSm),
              Text(
                item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14 * form.typeScale,
                  color: theme.hintColor,
                ),
              ),
            ],
            if (item.queueLength > 1) ...[
              const SizedBox(height: Dimens.spacingXs),
              Text(
                '${item.queueIndex + 1} / ${item.queueLength}',
                style: TextStyle(
                  fontSize: 12 * form.typeScale,
                  color: theme.hintColor,
                ),
              ),
            ],
            if (item.kind == AudioPlaybackKind.music) ...[
              const SizedBox(height: Dimens.spacingLg),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.album_outlined),
                    label: Text('封面'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.lyrics_outlined),
                    label: Text('歌词'),
                  ),
                ],
                selected: {_showLyrics},
                onSelectionChanged: (selection) =>
                    _setLyricsVisible(selection.first, item.songId),
              ),
              const SizedBox(height: Dimens.spacingLg),
            ] else
              const SizedBox(height: Dimens.spacingXl),
            SizedBox.square(
              dimension: coverSize,
              child: _showLyrics && item.kind == AudioPlaybackKind.music
                  ? _lyricsContent(context, theme, item.songId)
                  : ServerImage(
                      url: item.coverUrl,
                      session: widget.session,
                      borderRadius: BorderRadius.circular(Dimens.radiusLg),
                    ),
            ),
            if (widget.controller.error != null) ...[
              const SizedBox(height: Dimens.spacingSm),
              Text(
                widget.controller.error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13 * form.typeScale,
                  color: theme.colorScheme.error,
                ),
              ),
              TextButton.icon(
                onPressed: widget.controller.retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重试'),
              ),
            ],
            const SizedBox(height: Dimens.spacingXl),
            Slider(
              value: value,
              max: maxMs,
              onChangeStart: widget.controller.canSeek
                  ? (value) => setState(
                      () => _preview = Duration(milliseconds: value.round()),
                    )
                  : null,
              onChanged: widget.controller.canSeek
                  ? (value) => setState(
                      () => _preview = Duration(milliseconds: value.round()),
                    )
                  : null,
              onChangeEnd: widget.controller.canSeek
                  ? (value) {
                      setState(() => _preview = null);
                      widget.controller.seek(
                        Duration(milliseconds: value.round()),
                      );
                    }
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimens.spacingSm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_format(shownPosition)),
                  Text(_format(duration)),
                ],
              ),
            ),
            const SizedBox(height: Dimens.spacingLg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: '上一首',
                  iconSize: Dimens.audioPanelSkipIconSize,
                  onPressed: widget.controller.hasPrevious
                      ? widget.controller.playPrevious
                      : null,
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
                const SizedBox(width: Dimens.spacingLg),
                IconButton(
                  style: IconButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface,
                    backgroundColor: Colors.transparent,
                    minimumSize: Size.square(Dimens.audioPanelPlayButtonSize),
                  ),
                  tooltip: widget.controller.isPlaying ? '暂停' : '播放',
                  iconSize: Dimens.audioPanelPlayIconSize,
                  onPressed: widget.controller.togglePlayback,
                  icon: Icon(
                    widget.controller.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
                const SizedBox(width: Dimens.spacingLg),
                IconButton(
                  tooltip: '下一首',
                  iconSize: Dimens.audioPanelSkipIconSize,
                  onPressed: widget.controller.hasNext
                      ? widget.controller.playNext
                      : null,
                  icon: const Icon(Icons.skip_next_rounded),
                ),
              ],
            ),
            if (widget.controller.isBuffering) ...[
              const SizedBox(height: Dimens.spacingMd),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      );
    },
  );
}

class _TimedLyricsList extends StatefulWidget {
  const _TimedLyricsList({
    required this.lines,
    required this.position,
    required this.typeScale,
  });

  final List<TimedLyricLine> lines;
  final Duration position;
  final double typeScale;

  @override
  State<_TimedLyricsList> createState() => _TimedLyricsListState();
}

class _TimedLyricsListState extends State<_TimedLyricsList> {
  final ScrollController _scrollController = ScrollController();
  int _lastActive = -2;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = activeLyricIndex(widget.lines, widget.position);
    if (active != _lastActive) {
      _lastActive = active;
      if (active >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients || !mounted) return;
          final target = (active * Dimens.audioLyricRowExtent)
              .clamp(0.0, _scrollController.position.maxScrollExtent)
              .toDouble();
          _scrollController.animateTo(
            target,
            duration: Dimens.audioLyricScrollDuration,
            curve: Curves.easeOut,
          );
        });
      }
    }

    final theme = Theme.of(context);
    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.lines.length,
      itemExtent: Dimens.audioLyricRowExtent,
      itemBuilder: (context, index) {
        final isActive = index == active;
        return Center(
          child: Text(
            widget.lines[index].text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: (isActive ? 16 : 13) * widget.typeScale,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}
