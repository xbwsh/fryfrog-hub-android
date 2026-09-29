import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/media_models.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';

/// Full-screen mpv (media_kit) player with seek / volume chrome and progress.
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.session,
    required this.video,
    this.title,
    this.startPosition = 0,
  });

  final Session session;
  final VideoItem video;
  final String? title;
  final double startPosition;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  Player? _player;
  VideoController? _controller;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<bool>? _playSub;
  StreamSubscription<String>? _errSub;

  String? _error;
  bool _loading = true;
  bool _initialized = false;
  bool _chromeVisible = true;
  bool _muted = false;
  bool _exiting = false;
  bool _saving = false;
  bool _markedWatched = false;

  double _lastProgressSave = 0;
  int _lastUiMs = -1000;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;

  VideoItem get _video => widget.video;
  String get _title => widget.title ?? _video.title;

  @override
  void initState() {
    super.initState();
    _enterImmersive();
    _init();
  }

  /// Landscape + hide system bars while the player owns the screen.
  Future<void> _enterImmersive() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _restoreAppChrome() async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  Future<void> _init() async {
    if (_exiting) return;
    setState(() {
      _loading = true;
      _error = null;
      _initialized = false;
    });
    try {
      final api = widget.session.api;
      if (api == null) throw Exception('未登录');
      final url = api.videoStreamUrl(_video);

      await _teardownPlayer();
      if (_exiting || !mounted) return;

      final player = Player();
      final controller = VideoController(player);
      _player = player;
      _controller = controller;

      _posSub = player.stream.position.listen((pos) {
        if (!mounted || _exiting) return;
        _position = pos;
        // Rebuild chrome at most ~4fps — full setState per mpv tick freezes UI.
        final ms = pos.inMilliseconds;
        if (_chromeVisible && ms - _lastUiMs >= 250) {
          _lastUiMs = ms;
          setState(() {});
        }
        _maybeSaveProgress();
      });
      _durSub = player.stream.duration.listen((dur) {
        if (!mounted || _exiting) return;
        setState(() => _duration = dur);
      });
      _playSub = player.stream.playing.listen((playing) {
        if (!mounted || _exiting) return;
        setState(() => _playing = playing);
        if (!playing) {
          unawaited(_saveProgress(force: true));
        }
      });
      _errSub = player.stream.error.listen((err) {
        if (!mounted || _exiting || err.isEmpty) return;
        setState(() => _error = err);
      });

      await player.open(Media(url), play: true);
      if (_exiting || !mounted) return;

      final start = widget.startPosition;
      if (start > 1) {
        for (var i = 0; i < 30; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          if (_exiting || !mounted) return;
          if (_duration.inSeconds > 0) {
            if (start < _duration.inSeconds - 5) {
              await player.seek(Duration(seconds: start.toInt()));
            }
            break;
          }
        }
      }

      if (_exiting || !mounted) return;
      setState(() {
        _initialized = true;
        _loading = false;
        _chromeVisible = true;
      });
    } catch (e) {
      if (!mounted || _exiting) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _teardownPlayer() async {
    await _posSub?.cancel();
    await _durSub?.cancel();
    await _playSub?.cancel();
    await _errSub?.cancel();
    _posSub = _durSub = _playSub = _errSub = null;
    final player = _player;
    _player = null;
    _controller = null;
    if (player != null) {
      try {
        await player.dispose().timeout(const Duration(seconds: 2));
      } catch (_) {
        // Native dispose can hang — already dropped the handle.
      }
    }
  }

  void _maybeSaveProgress() {
    final pos = _position.inSeconds.toDouble();
    final dur = _duration.inSeconds.toDouble();
    if (dur <= 0) return;
    if (pos - _lastProgressSave >= 5) {
      unawaited(_saveProgress());
    }
  }

  Future<void> _saveProgress({bool force = false}) async {
    if (_saving) return;
    final pos = _position.inSeconds.toDouble();
    final dur = _duration.inSeconds.toDouble();
    if (dur <= 0) return;
    if (!force && pos - _lastProgressSave < 5) return;
    _saving = true;
    _lastProgressSave = pos;
    try {
      await widget.session.api
          ?.saveWatchProgress(_video.id, position: pos, duration: dur)
          .timeout(const Duration(seconds: 3));
      if (dur > 0 && pos / dur >= 0.9 && !_markedWatched) {
        // One-shot: without this, every 5s save past 90% doubles up with
        // a setWatched request.
        _markedWatched = true;
        await widget.session.api
            ?.setWatched(_video.id, completed: true)
            .timeout(const Duration(seconds: 3));
      }
    } catch (e) {
      debugPrint('save progress failed: $e');
    } finally {
      _saving = false;
    }
  }

  @override
  void dispose() {
    _exiting = true;
    final pos = _position.inSeconds.toDouble();
    final dur = _duration.inSeconds.toDouble();
    if (dur > 0) {
      widget.session.api
          ?.saveWatchProgress(_video.id, position: pos, duration: dur)
          .timeout(const Duration(seconds: 2))
          .ignore();
    }
    // Cancel listeners first so no setState after dispose.
    unawaited(_posSub?.cancel());
    unawaited(_durSub?.cancel());
    unawaited(_playSub?.cancel());
    unawaited(_errSub?.cancel());
    final player = _player;
    _player = null;
    _controller = null;
    if (player != null) {
      player.dispose().timeout(const Duration(seconds: 2)).ignore();
    }
    unawaited(_restoreAppChrome());
    super.dispose();
  }

  void _toggleChrome() {
    if (_exiting) return;
    setState(() => _chromeVisible = !_chromeVisible);
  }

  /// Leave immediately. Progress is saved fire-and-forget in dispose —
  /// never block back-gesture on network.
  void _exit() {
    if (_exiting) return;
    _exiting = true;
    if (!mounted) return;
    // canPop stays false for the route; pop explicitly (maybePop would no-op).
    Navigator.of(context).pop();
  }

  void _seekBy(int seconds) {
    final player = _player;
    if (player == null) return;
    final target = _position + Duration(seconds: seconds);
    if (target < Duration.zero) {
      player.seek(Duration.zero);
    } else if (_duration > Duration.zero && target > _duration) {
      player.seek(_duration);
    } else {
      player.seek(target);
    }
  }

  void _toggleMute() {
    final player = _player;
    if (player == null) return;
    setState(() => _muted = !_muted);
    player.setVolume(_muted ? 0 : 100);
  }

  Future<void> _toggleOrientation() async {
    final screen = MediaQuery.sizeOf(context);
    final isPortrait = screen.height >= screen.width;
    if (isPortrait) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
    }
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '${d.inMinutes}:$s';
  }

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _exiting) return;
        _exit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleChrome,
              child: Center(child: _body(form)),
            ),
            if (_chromeVisible && !_exiting)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _TopChrome(form: form, title: _title, onBack: _exit),
              ),
            if (_chromeVisible && !_exiting && _initialized && _player != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _BottomChrome(
                  form: form,
                  playing: _playing,
                  position: _position,
                  duration: _duration,
                  muted: _muted,
                  fmt: _fmt,
                  onSeek: (d) {
                    _player?.seek(d);
                    unawaited(_saveProgress(force: true));
                  },
                  onTogglePlay: () {
                    final p = _player;
                    if (p == null) return;
                    if (_playing) {
                      p.pause();
                    } else {
                      p.play();
                    }
                  },
                  onSeekBy: _seekBy,
                  onToggleMute: _toggleMute,
                  onToggleOrientation: _toggleOrientation,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(DeviceForm form) {
    if (_loading) {
      return const CircularProgressIndicator(
        color: AppColors.accent,
        strokeWidth: 2.5,
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(Dimens.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '播放失败',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16 * form.typeScale,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Dimens.spacingSm),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13 * form.typeScale,
              ),
            ),
            const SizedBox(height: Dimens.spacingLg),
            FilledButton(
              onPressed: _exiting ? null : _init,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    final controller = _controller;
    if (controller == null) {
      return const CircularProgressIndicator(color: AppColors.accent);
    }
    return Video(
      controller: controller,
      controls: NoVideoControls,
      fit: BoxFit.contain,
    );
  }
}

class _TopChrome extends StatelessWidget {
  const _TopChrome({
    required this.form,
    required this.title,
    required this.onBack,
  });

  final DeviceForm form;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              IconButton(
                tooltip: '返回',
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14 * form.typeScale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'mpv',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11 * form.typeScale,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: Dimens.spacingMd),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomChrome extends StatelessWidget {
  const _BottomChrome({
    required this.form,
    required this.playing,
    required this.position,
    required this.duration,
    required this.muted,
    required this.fmt,
    required this.onSeek,
    required this.onTogglePlay,
    required this.onSeekBy,
    required this.onToggleMute,
    required this.onToggleOrientation,
  });

  final DeviceForm form;
  final bool playing;
  final Duration position;
  final Duration duration;
  final bool muted;
  final String Function(Duration) fmt;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onTogglePlay;
  final ValueChanged<int> onSeekBy;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleOrientation;

  @override
  Widget build(BuildContext context) {
    final maxMs = duration.inMilliseconds.toDouble().clamp(
      1.0,
      double.infinity,
    );
    final posMs = position.inMilliseconds.toDouble().clamp(0.0, maxMs);

    return Material(
      color: Colors.black54,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimens.spacingSm,
            Dimens.spacingXs,
            Dimens.spacingSm,
            Dimens.spacingSm,
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: playing ? '暂停' : '播放',
                iconSize: 32 * form.posterScale,
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
                onPressed: onTogglePlay,
              ),
              IconButton(
                tooltip: '后退 10 秒',
                icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                onPressed: () => onSeekBy(-10),
              ),
              IconButton(
                tooltip: '快进 10 秒',
                icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                onPressed: () => onSeekBy(10),
              ),
              const SizedBox(width: Dimens.spacingXs),
              Text(
                fmt(position),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12 * form.typeScale,
                ),
              ),
              Expanded(
                child: Slider(
                  value: posMs,
                  max: maxMs,
                  onChanged: (ms) {
                    onSeek(Duration(milliseconds: ms.toInt()));
                  },
                ),
              ),
              Text(
                fmt(duration),
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12 * form.typeScale,
                ),
              ),
              const SizedBox(width: Dimens.spacingXs),
              IconButton(
                tooltip: muted ? '取消静音' : '静音',
                icon: Icon(
                  muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                ),
                onPressed: onToggleMute,
              ),
              IconButton(
                tooltip: '旋转屏幕',
                icon: const Icon(
                  Icons.screen_rotation_rounded,
                  color: Colors.white,
                ),
                onPressed: onToggleOrientation,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
