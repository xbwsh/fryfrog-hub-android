import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/media_models.dart';
import '../../core/rules/watch_rules.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';

/// Full-screen mpv (media_kit) player with seek / volume chrome and progress.
///
/// 手势层（对齐常见播放器 / media_kit 内置手势）：
/// · 点按 — 显隐控制栏
/// · 左半屏上下滑 — 屏幕亮度；右半屏上下滑 — 系统音量
/// · 长按 — 2.0x 倍速播放，松手恢复
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

  // ── 上下滑手势：左屏亮度 / 右屏系统音量 ────────────────────────────
  bool _adjusting = false;
  bool _adjustBrightness = false;
  bool _adjustReady = false;
  double _adjustBase = 0;
  double _adjustDeltaPx = 0;
  double _adjustRange = 1;
  double _adjustValue = 0;
  int _lastAdjustApplyMs = 0;

  // ── 长按倍速 ───────────────────────────────────────────────────────
  bool _speedUp = false;
  double _rateBeforeSpeedUp = 1.0;

  VideoItem get _video => widget.video;
  String get _title => widget.title ?? _video.title;

  @override
  void initState() {
    super.initState();
    // 音量手势自己画 HUD，不要 Android 再弹一条系统音量条盖住画面。
    VolumeController.instance.showSystemUI = false;
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
    if (WatchRules.shouldSave(
      positionSeconds: pos,
      lastSavedSeconds: _lastProgressSave,
    )) {
      unawaited(_saveProgress());
    }
  }

  Future<void> _saveProgress({bool force = false}) async {
    if (_saving) return;
    final pos = _position.inSeconds.toDouble();
    final dur = _duration.inSeconds.toDouble();
    if (dur <= 0) return;
    if (!force &&
        !WatchRules.shouldSave(
          positionSeconds: pos,
          lastSavedSeconds: _lastProgressSave,
        )) {
      return;
    }
    _saving = true;
    _lastProgressSave = pos;
    try {
      await widget.session.api
          ?.saveWatchProgress(_video.id, position: pos, duration: dur)
          .timeout(const Duration(seconds: 3));
      // 用 WatchRules 而不是本地魔法数：后端 update_position 每次保存都按
      // 同一个阈值重算 completed，客户端提前标会在下一次保存时被打回。
      if (WatchRules.isCompleted(pos, dur) && !_markedWatched) {
        await widget.session.api
            ?.setWatched(_video.id, completed: true)
            .timeout(const Duration(seconds: 3));
        // 标记成功才置位：失败时下个周期重试，否则一次超时就永远不标了。
        _markedWatched = true;
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
    // 应用级亮度只在观影期间生效，退出必须还原——否则整个 App 会一直
    // 停在观影时的暗亮度上。
    ScreenBrightness.instance.resetApplicationScreenBrightness().ignore();
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
    final navigator = Navigator.of(context);
    // Rotation + bars must settle while the player still covers the detail
    // page — otherwise its top bar shifts downward when they come back.
    _restoreAppChrome().whenComplete(navigator.pop);
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

  // ── 手势：左半屏亮度 · 右半屏系统音量 · 长按 2.0x ──────────────────

  /// 屏幕最左/最右 24px 让给系统返回手势（Android 手势导航的边缘滑动）。
  bool _isGestureEdge(DragStartDetails details) {
    final width = MediaQuery.sizeOf(context).width;
    final x = details.localPosition.dx;
    return x < 24 || x > width - 24;
  }

  void _onVerticalDragStart(DragStartDetails details) {
    if (_exiting || _isGestureEdge(details)) return;
    final size = MediaQuery.sizeOf(context);
    _adjusting = true;
    _adjustBrightness = details.localPosition.dx <= size.width / 2;
    _adjustReady = false;
    _adjustDeltaPx = 0;
    // 全程（约半个屏高）走完 0→100%，和常见播放器手感一致。
    _adjustRange = size.height * 0.5;
    _adjustValue = 0;
    unawaited(_loadAdjustBase());
  }

  /// 起手先读当前值（异步）；读到之前累积的位移在读到后一并套用。
  Future<void> _loadAdjustBase() async {
    final brightness = _adjustBrightness;
    final value = brightness ? await _readBrightness() : await _readVolume();
    if (!mounted || !_adjusting || brightness != _adjustBrightness) return;
    if (value == null) {
      // 平台不支持（Web 等）：手势直接作废，不给假反馈。
      setState(() => _adjusting = false);
      return;
    }
    _adjustBase = value;
    _adjustReady = true;
    await _applyAdjust(force: true);
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_adjusting) return;
    _adjustDeltaPx += details.delta.dy;
    if (!_adjustReady) return;
    unawaited(_applyAdjust());
  }

  void _onVerticalDragEnd(DragEndDetails details) => unawaited(_endAdjust());

  void _onVerticalDragCancel() => unawaited(_endAdjust());

  Future<void> _endAdjust() async {
    if (!_adjusting) return;
    // 节流可能吞掉最后一步，松手时强制落盘。
    if (_adjustReady) await _applyAdjust(force: true);
    if (!mounted) return;
    setState(() => _adjusting = false);
  }

  Future<void> _applyAdjust({bool force = false}) async {
    if (!_adjustReady) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!force && nowMs - _lastAdjustApplyMs < 40) return;
    _lastAdjustApplyMs = nowMs;

    final raw = _adjustBase - _adjustDeltaPx / _adjustRange;
    final value = raw.clamp(0.0, 1.0).toDouble();
    _adjustValue = value;

    if (_adjustBrightness) {
      try {
        await ScreenBrightness.instance.setApplicationScreenBrightness(value);
      } catch (_) {
        // 权限/平台异常：手势照常走，只是亮度不动，不打断拖动。
      }
    } else {
      await _writeVolume(value);
    }
    if (mounted) setState(() {});
  }

  Future<double?> _readBrightness() async {
    try {
      // 应用级亮度：不需要 WRITE_SETTINGS，也只影响本 App。
      return await ScreenBrightness.instance.application;
    } catch (_) {
      return null;
    }
  }

  Future<double?> _readVolume() async {
    try {
      return await VolumeController.instance.getVolume();
    } catch (_) {
      // 无系统音量的平台（Web）：退回播放器自身音量。
      final volume = _player?.state.volume;
      return volume == null ? null : (volume / 100).clamp(0.0, 1.0).toDouble();
    }
  }

  Future<void> _writeVolume(double value) async {
    try {
      await VolumeController.instance.setVolume(value);
      // 系统音量动了就必须解开播放器静音，否则怎么拖都没声。
      if (_muted) {
        _muted = false;
        unawaited(_player?.setVolume(100));
      }
    } catch (_) {
      unawaited(_player?.setVolume(value * 100));
    }
  }

  void _onLongPressStart() {
    final player = _player;
    if (_exiting || player == null) return;
    _rateBeforeSpeedUp = player.state.rate;
    unawaited(player.setRate(2.0));
    setState(() => _speedUp = true);
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (!_speedUp) return;
    final player = _player;
    if (player != null) unawaited(player.setRate(_rateBeforeSpeedUp));
    if (mounted) setState(() => _speedUp = false);
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
              onVerticalDragStart: _onVerticalDragStart,
              onVerticalDragUpdate: _onVerticalDragUpdate,
              onVerticalDragEnd: _onVerticalDragEnd,
              onVerticalDragCancel: _onVerticalDragCancel,
              onLongPress: _onLongPressStart,
              onLongPressEnd: _onLongPressEnd,
              child: Center(child: _body(form)),
            ),
            // 亮度/音量/倍速的即时反馈，居中悬浮，不参与命中测试。
            if ((_adjusting || _speedUp) && !_exiting)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: _GestureHud(
                      form: form,
                      speedUp: _speedUp,
                      brightness: _adjustBrightness,
                      value: _adjustValue,
                    ),
                  ),
                ),
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

/// 亮度/音量/倍速的居中反馈牌（长按倍速时只显示 `2.0x`）。
class _GestureHud extends StatelessWidget {
  const _GestureHud({
    required this.form,
    required this.speedUp,
    required this.brightness,
    required this.value,
  });

  final DeviceForm form;
  final bool speedUp;
  final bool brightness;
  final double value;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 14 * form.typeScale,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final child = speedUp
        ? Text('2.0x', style: textStyle)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, color: Colors.white, size: 20 * form.typeScale),
              const SizedBox(width: Dimens.spacingSm),
              Text('${(value * 100).round()}%', style: textStyle),
            ],
          );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimens.spacingLg,
        vertical: Dimens.spacingMd,
      ),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(Dimens.radiusLg),
      ),
      child: child,
    );
  }

  IconData get _icon {
    if (brightness) {
      if (value > 0.66) return Icons.brightness_high_rounded;
      if (value > 0.33) return Icons.brightness_medium_rounded;
      return Icons.brightness_low_rounded;
    }
    if (value <= 0) return Icons.volume_off_rounded;
    if (value < 0.5) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }
}
