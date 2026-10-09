import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/media_models.dart';
import '../../core/rules/seek_rules.dart';
import '../../core/rules/watch_rules.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import 'player_panels.dart';

/// Full-screen mpv (media_kit) player with seek / volume chrome and progress.
///
/// 手势层（一个 pan 手势按位移方向动态定轴，互不抢触发）：
/// · 点按 — 显隐控制栏（因为要区分双击，会比双击超时晚约 300ms）
/// · 双击 — 播放/暂停
/// · 横滑 / 拖进度条 — seek：期间控制栏收到只剩进度条，松手才真正跳转
/// · 左半屏上下滑 — 屏幕亮度；右半屏上下滑 — 系统音量
/// · 长按 — 2.0x 倍速播放，松手恢复
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.session,
    required this.video,
    this.title,
    this.startPosition = 0,
    this.episodes = const [],
  });

  final Session session;
  final VideoItem video;
  final String? title;
  final double startPosition;

  /// 选集用的同一部剧的所有集（电影只有一集 → 选集按钮自动隐藏）。
  final List<VideoItem> episodes;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

/// 一次拖动判定出的轴：判定前进度/亮度/音量都不动，避免互相误触发。
enum _DragAxis { seek, adjust }

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  Player? _player;
  VideoController? _controller;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<bool>? _playSub;
  StreamSubscription<String>? _errSub;
  StreamSubscription<Tracks>? _tracksSub;
  StreamSubscription<Track>? _trackSub;

  // ── 内封字幕（libmpv 上报的 sid；外挂字幕待后端接口）────────────────
  /// 本片可选的内封字幕轨，已滤掉 mpv 的 `auto`/`no` 占位项；
  /// 为空 = 本片无字幕，底栏「字幕」按钮整个不显示。
  List<SubtitleTrack> _subTracks = const [];

  /// mpv 当前生效的 sid（`no`=关闭 / `auto`=未定 / 具体 id=在显示）。
  String? _subSelectedId;

  String? _error;
  bool _loading = true;
  bool _initialized = false;
  bool _chromeVisible = true;
  bool _exiting = false;
  bool _saving = false;
  bool _markedWatched = false;

  // ── 当前播放这一集（选集会整体换掉），以及它的续播起点 ──────────────
  late VideoItem _current;
  late String _titleText;
  double _startAt = 0;

  // ── 倍数（长按临时 2.0x 时不改这里）────────────────────────────────
  double _rate = 1.0;

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

  // ── 横滑/拖动进度条 seek ───────────────────────────────────────────
  bool _seeking = false;
  Duration _seekStart = Duration.zero;
  Duration _seekPreview = Duration.zero;
  double _seekDeltaPx = 0;
  // seek 起手前控制栏的显隐：松手还原，别让一次拖动把状态永久改掉。
  bool _chromeBeforeSeek = true;
  // seek 刚发出后的短暂窗口：mpv 回吐的旧位置不可信，忽略之，否则进度条回跳。
  int _seekSettleUntilMs = 0;

  // ── 拖动轴判定：攒够位移前既不动进度也不动亮度/音量 ────────────────
  _DragAxis? _dragAxis;
  bool _dragIgnored = false;
  Offset _dragStartLocal = Offset.zero;
  double _dragDx = 0;
  double _dragDy = 0;

  // ── 长按倍速 ───────────────────────────────────────────────────────
  bool _speedUp = false;
  double _rateBeforeSpeedUp = 1.0;

  VideoItem get _video => _current;
  String get _title => _titleText;

  @override
  void initState() {
    super.initState();
    _current = widget.video;
    _titleText = widget.title ?? widget.video.title;
    _startAt = widget.startPosition;
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
      // 换集/重进时这些是上一条片子的，必须清掉。
      _position = Duration.zero;
      _duration = Duration.zero;
      _playing = false;
      _speedUp = false;
      _markedWatched = false;
      _lastProgressSave = 0;
      _lastUiMs = -1000;
      _seekSettleUntilMs = 0;
      _subTracks = const [];
      _subSelectedId = null;
    });
    try {
      final api = widget.session.api;
      if (api == null) throw Exception('未登录');
      final url = api.videoStreamUrl(_current);

      await _teardownPlayer();
      if (_exiting || !mounted) return;

      final player = Player();
      final controller = VideoController(player);
      _player = player;
      _controller = controller;
      // 倍数是跨集保留的：换集后新 player 要重新套上。
      unawaited(player.setRate(_rate));

      _posSub = player.stream.position.listen((pos) {
        if (!mounted || _exiting) return;
        // 拖动中显示全走预览：这期间 mpv 回吐的还是拖动前的旧位置，
        // 拿它更新 _position 会把下一段手势的起算点拽回去 → 进度条抖动。
        if (_seeking) return;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (nowMs < _seekSettleUntilMs &&
            (pos - _position).abs() > const Duration(milliseconds: 1500)) {
          return;
        }
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
      _tracksSub = player.stream.tracks.listen((tracks) {
        if (!mounted || _exiting) return;
        final real = tracks.subtitle
            .where((t) => t.id != 'auto' && t.id != 'no')
            .toList(growable: false);
        setState(() => _subTracks = real);
        // 换片后轨道表被清空 → 兜底收起字幕面板，别让按钮悬空。
        if (real.isEmpty && _subOpen) _closePanels();
      });
      _trackSub = player.stream.track.listen((track) {
        if (!mounted || _exiting) return;
        setState(() => _subSelectedId = track.subtitle.id);
      });

      await player.open(Media(url), play: true);
      if (_exiting || !mounted) return;

      final start = _startAt;
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
    await _tracksSub?.cancel();
    await _trackSub?.cancel();
    _posSub = _durSub = _playSub = _errSub = null;
    _tracksSub = _trackSub = null;
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
    unawaited(_tracksSub?.cancel());
    unawaited(_trackSub?.cancel());
    _tracksSub = _trackSub = null;
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
    _restoreAppChrome().whenComplete(() => navigator.pop(_switchedTo));
  }

  void _togglePlay() {
    final player = _player;
    if (player == null) return;
    if (_playing) {
      player.pause();
    } else {
      player.play();
    }
  }

  // ── 选集：换掉片子但复用同一个播放器（不然要退回详情页再进来）──────
  Future<void> _switchEpisode(VideoItem next) async {
    // 正在加载/正在拖进度时都不许换，否则两次 _init 会互相打架。
    if (_exiting || _loading || _seeking || next.id == _current.id) return;
    // 当前这一集的进度先落盘（参数在 await 前求值，拿到的还是旧 id）。
    unawaited(_saveProgress(force: true));
    if (!mounted) return;
    setState(() {
      _current = next;
      _titleText = next.title;
      _startAt = next.watchPosition ?? 0;
      _chromeVisible = true;
    });
    // 退出时把换过的这一集带回详情页，那边的「继续播放」才指得对。
    _switchedTo = next;
    await _init();
  }

  /// 换过集后记录下来，退出时作为路由返回值带回详情页。
  VideoItem? _switchedTo;

  // ── 倍数 / 右侧选集抽屉 / 右下倍速·字幕浮层 ──────────────────────

  /// 按钮上的倍数；长按 2.0x 期间如实显示 2.0X。
  String get _rateLabel => formatSpeed(_speedUp ? 2.0 : _rate);

  /// 三个浮层互斥：开一个就关其余（= 原型 closeAll 语义）。
  bool _epOpen = false;
  bool _speedOpen = false;
  bool _subOpen = false;

  void _toggleEpDrawer() {
    if (_exiting) return;
    setState(() {
      _epOpen = !_epOpen;
      if (_epOpen) {
        _speedOpen = false;
        _subOpen = false;
        // 面板开着时控制栏不能自己收起来，否则高亮的按钮点不到。
        _chromeVisible = true;
      }
    });
  }

  void _toggleSpeedPanel() {
    if (_exiting) return;
    setState(() {
      _speedOpen = !_speedOpen;
      if (_speedOpen) {
        _epOpen = false;
        _subOpen = false;
        _chromeVisible = true;
      }
    });
  }

  void _toggleSubPanel() {
    if (_exiting) return;
    setState(() {
      _subOpen = !_subOpen;
      if (_subOpen) {
        _epOpen = false;
        _speedOpen = false;
        _chromeVisible = true;
      }
    });
  }

  void _closePanels() {
    if (!_epOpen && !_speedOpen && !_subOpen) return;
    setState(() {
      _epOpen = false;
      _speedOpen = false;
      _subOpen = false;
    });
  }

  Future<void> _setRate(double value) async {
    if (_exiting) return;
    setState(() => _rate = value);
    await _player?.setRate(value);
  }

  /// 字幕面板里选了一轨（`SubtitleTrack.no()` = 关闭）：先收面板再切轨。
  Future<void> _setSubtitle(SubtitleTrack track) async {
    if (_exiting) return;
    _closePanels();
    await _player?.setSubtitleTrack(track);
  }

  /// 抽屉里点了一集：先关面板，再走复用同一个播放器的换集流程。
  Future<void> _onPickEpisode(VideoItem ep) async {
    final same = ep.id == _current.id;
    _closePanels();
    if (same || _exiting) return;
    await _switchEpisode(ep);
  }

  // ── 手势：横滑 seek · 左半屏亮度 · 右半屏系统音量 · 长按 2.0x ──────

  /// 屏幕最左/最右 24px 让给系统返回手势（Android 手势导航的边缘滑动）。
  bool _isGestureEdge(Offset localPosition) {
    final width = MediaQuery.sizeOf(context).width;
    return localPosition.dx < 24 || localPosition.dx > width - 24;
  }

  void _onPanStart(DragStartDetails details) {
    // 进度条正在被拖（滑杆自己的手势）：别起第二套预览，交给它拖完。
    if (_seeking) {
      _dragIgnored = true;
      _dragAxis = null;
      return;
    }
    _dragAxis = null;
    _dragStartLocal = details.localPosition;
    _dragIgnored = _exiting || _isGestureEdge(details.localPosition);
    _dragDx = 0;
    _dragDy = 0;
    _adjusting = false;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_exiting || _dragIgnored) return;
    _dragDx += details.delta.dx;
    _dragDy += details.delta.dy;

    if (_dragAxis == null) {
      if (!SeekRules.readyToDecide(_dragDx, _dragDy)) return;
      // 判定前两者都不动手：横滑快进绝不会顺手把亮度/音量改掉，反之亦然。
      if (SeekRules.isHorizontal(_dragDx, _dragDy)) {
        _dragAxis = _DragAxis.seek;
        if (!_beginSeek()) {
          _dragIgnored = true; // 总时长还没拿到，无从预览进度
          return;
        }
      } else {
        _dragAxis = _DragAxis.adjust;
        _beginAdjust();
      }
      return;
    }

    if (_dragAxis == _DragAxis.seek) {
      _seekDeltaPx = _dragDx;
      _updateSeekPreview();
    } else {
      _adjustDeltaPx = _dragDy;
      if (_adjustReady) unawaited(_applyAdjust());
    }
  }

  void _onPanEnd(DragEndDetails details) => unawaited(_endDrag());

  void _onPanCancel() => unawaited(_endDrag());

  Future<void> _endDrag() async {
    final axis = _dragAxis;
    final ignored = _dragIgnored;
    _dragAxis = null;
    _dragIgnored = false;
    if (ignored) return;

    if (axis == _DragAxis.seek) {
      _commitSeek();
    } else if (axis == _DragAxis.adjust) {
      await _endAdjust();
    }
  }

  /// 进入 seek 模式：控制栏收到只剩进度条，显示值改走预览。
  /// [from] 非空表示滑杆自己被拖（绝对目标），空表示横滑（由位移换算）。
  bool _beginSeek({Duration? from}) {
    // 拖进度是面板关闭后才可能发生的路径，兜底关一下浮层。
    _closePanels();
    if (_duration <= Duration.zero) return false;
    if (!_seeking) _chromeBeforeSeek = _chromeVisible;
    _seeking = true;
    _seekStart = _position;
    _seekDeltaPx = _dragDx;
    if (from != null) {
      _seekPreview = from;
    } else {
      _seekPreview = SeekRules.preview(
        start: _seekStart,
        duration: _duration,
        deltaPx: _seekDeltaPx,
        width: MediaQuery.sizeOf(context).width,
      );
    }
    _chromeVisible = true;
    if (mounted) setState(() {});
    return true;
  }

  void _updateSeekPreview() {
    if (!_seeking) return;
    final width = MediaQuery.sizeOf(context).width;
    // 横滑整个屏宽 ≈ 走完整集时长，clamp 在 [0, 时长]。
    _seekPreview = SeekRules.preview(
      start: _seekStart,
      duration: _duration,
      deltaPx: _seekDeltaPx,
      width: width,
    );
    if (mounted) setState(() {});
  }

  /// 松手：真的跳过去 + 存进度，并把控制栏还原成拖动前的样子。
  void _commitSeek() {
    if (!_seeking) return;
    final target = _seekPreview;
    final player = _player;
    _seeking = false;
    _chromeVisible = _chromeBeforeSeek;
    if (player != null && _duration > Duration.zero) {
      // 先落本地位置再存进度，否则存的是跳转前的旧位置。
      _position = target;
      // 900ms 内 mpv 可能还在回吐 seek 前的旧位置，别让它把进度条拽回去。
      _seekSettleUntilMs = DateTime.now().millisecondsSinceEpoch + 900;
      unawaited(_seekTo(player, target));
      unawaited(_saveProgress(force: true));
    }
    if (mounted) setState(() {});
  }

  /// 精确 seek。mpv 默认按关键帧 seek，会落在目标前面的 I 帧上——松手后
  /// 进度条会肉眼可见地往回跳几秒；exact 会解码到目标帧，代价是一小段解码。
  Future<void> _seekTo(Player player, Duration target) async {
    final platform = player.platform;
    if (platform is NativePlayer) {
      try {
        await platform.command([
          'seek',
          (target.inMilliseconds / 1000).toStringAsFixed(4),
          'absolute',
          'exact',
        ]);
        return;
      } catch (_) {
        // 命令失败（平台/初始化差异）→ 回落普通 seek。
      }
    }
    await player.seek(target);
  }

  // ── 进度条自己被拖：拖动中只更新预览，松手才 seek 一次 ──────────────
  void _onScrubStart(Duration value) {
    _beginSeek(from: value);
  }

  void _onScrubUpdate(Duration value) {
    if (!_seeking) return;
    setState(() => _seekPreview = value);
  }

  void _onScrubEnd(Duration value) {
    if (!_seeking) return;
    _seekPreview = value;
    _commitSeek();
  }

  /// 判成纵向后才开始调亮度/音量（异步读当前值）。
  void _beginAdjust() {
    final size = MediaQuery.sizeOf(context);
    _adjusting = true;
    _adjustBrightness = _dragStartLocal.dx <= size.width / 2;
    _adjustReady = false;
    _adjustDeltaPx = _dragDy;
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
        // = 原型的 Esc：面板开着时返回键先关面板，再谈退出播放器。
        if (_epOpen || _speedOpen || _subOpen) {
          _closePanels();
          return;
        }
        _exit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleChrome,
              onDoubleTap: _togglePlay,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              onPanCancel: _onPanCancel,
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
            // 拖动 seek 中控制栏收到只剩进度条：顶栏也一并收起。
            if (_chromeVisible && !_seeking && !_exiting)
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
                  // 拖动中（横滑或滑杆）进度条跟预览走，松手才真正跳转。
                  seeking: _seeking,
                  preview: _seeking ? _seekPreview : null,
                  duration: _duration,
                  rateLabel: _rateLabel,
                  speedOpen: _speedOpen,
                  epOpen: _epOpen,
                  subOpen: _subOpen,
                  onPickSpeed: _toggleSpeedPanel,
                  onPickSubtitles: _subTracks.isNotEmpty
                      ? _toggleSubPanel
                      : null,
                  onPickEpisodes: widget.episodes.length > 1
                      ? _toggleEpDrawer
                      : null,
                  fmt: _fmt,
                  onChangeStart: _onScrubStart,
                  onChanged: _onScrubUpdate,
                  onChangeEnd: _onScrubEnd,
                  onTogglePlay: _togglePlay,
                ),
              ),
            // ── 选集抽屉 / 倍速·字幕浮层 + 遮罩：盖住视频与控制栏 ──────
            if (!_exiting) ...[
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_epOpen && !_speedOpen && !_subOpen,
                  child: GestureDetector(
                    onTap: _closePanels,
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedOpacity(
                      opacity: (_epOpen || _speedOpen || _subOpen) ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                child: EpisodeDrawer(
                  open: _epOpen,
                  episodes: widget.episodes,
                  currentId: _current.id,
                  onClose: _closePanels,
                  onPick: _onPickEpisode,
                ),
              ),
              Positioned(
                right: Dimens.spacingLg,
                bottom: Dimens.playerSpeedPanelBottom,
                child: SpeedPanel(
                  open: _speedOpen,
                  rate: _rate,
                  onChanged: _setRate,
                ),
              ),
              Positioned(
                right: Dimens.spacingLg,
                bottom: Dimens.playerSpeedPanelBottom,
                child: SubtitlePanel(
                  open: _subOpen,
                  tracks: _subTracks,
                  selectedId: _subSelectedId,
                  onPick: _setSubtitle,
                ),
              ),
            ],
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
    return DecoratedBox(
      // 渐变代替硬边黑条：顶边最深、向下化开，标题在最深处仍可读。
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.black54, Colors.transparent],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: kToolbarHeight,
            child: Row(
              children: [
                IconButton(
                  tooltip: '返回',
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
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
    required this.fmt,
    required this.seeking,
    required this.rateLabel,
    required this.speedOpen,
    required this.epOpen,
    required this.subOpen,
    required this.onPickSpeed,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onTogglePlay,
    this.onPickSubtitles,
    this.onPickEpisodes,
    this.preview,
  });

  final DeviceForm form;
  final bool playing;
  final Duration position;
  final Duration duration;
  final String Function(Duration) fmt;

  /// 拖动 seek 中（横滑或滑杆）：只留进度条 + 时间，其余控件全收起。
  final bool seeking;
  final ValueChanged<Duration> onChangeStart;
  final ValueChanged<Duration> onChanged;
  final ValueChanged<Duration> onChangeEnd;
  final VoidCallback onTogglePlay;

  /// 倍数按钮文案（如 `1.0X`）与回调。
  final String rateLabel;
  final VoidCallback onPickSpeed;

  /// 字幕回调；null = 本片无内封字幕，按钮整个不显示。
  final VoidCallback? onPickSubtitles;

  /// 选集回调；null = 只有一集（电影），按钮整个不显示。
  final VoidCallback? onPickEpisodes;

  /// 对应浮层开着 → 按钮高亮（accent 字 + accent12% 底）。
  final bool speedOpen;
  final bool epOpen;
  final bool subOpen;

  /// seek 中的预览位置；非 null 时时间与滑杆都显示它而非真实进度。
  final Duration? preview;

  /// seek 中把按钮藏起来但**保留占位**：滑杆轨道宽度不变，拇指不会因为
  /// 布局重排而横跳（那看起来就是进度条在抖）。
  Widget _hideWhileSeeking(Widget child) => Visibility(
    visible: !seeking,
    maintainState: true,
    maintainAnimation: true,
    maintainSize: true,
    child: child,
  );

  /// 面板按钮样式：对应浮层开着时 accent 字 + accent 12% 底（原型 .text-btn.active）。
  ButtonStyle _panelBtnStyle(bool active) {
    return TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.spacingSm),
      minimumSize: Size(44 * form.typeScale, 32),
      foregroundColor: active ? AppColors.accent : Colors.white,
      backgroundColor: active
          ? AppColors.accent.withValues(alpha: 0.12)
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimens.radiusSm),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = duration.inMilliseconds.toDouble().clamp(
      1.0,
      double.infinity,
    );
    final shownMs = (preview ?? position).inMilliseconds;
    final posMs = shownMs.toDouble().clamp(0.0, maxMs);
    final timeStyle = TextStyle(
      color: Colors.white,
      fontSize: 12 * form.typeScale,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return DecoratedBox(
      // 渐变代替硬边黑条：底边最深、向上化开，亮画面里白字仍可读。
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black54, Colors.black54, Colors.transparent],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
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
                // seek 中只隐藏不占位地收起按钮 —— 直接从 Row 里删掉会改变
                // 滑杆轨道宽度，拇指瞬间横跳，反而像抖动。
                _hideWhileSeeking(
                  IconButton(
                    tooltip: playing ? '暂停' : '播放',
                    iconSize: 32 * form.posterScale,
                    icon: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
                    onPressed: onTogglePlay,
                  ),
                ),
                const SizedBox(width: Dimens.spacingXs),
                // 已播/总时长并排（3:43/16:00），总时长压暗一档区分。
                Text.rich(
                  TextSpan(
                    text: fmt(preview ?? position),
                    style: timeStyle,
                    children: [
                      TextSpan(
                        text: '/${fmt(duration)}',
                        style: timeStyle.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: posMs,
                    max: maxMs,
                    // 拖动中只更新预览，松手才 seek —— 见 _onScrub*。
                    onChangeStart: (ms) =>
                        onChangeStart(Duration(milliseconds: ms.toInt())),
                    onChanged: (ms) =>
                        onChanged(Duration(milliseconds: ms.toInt())),
                    onChangeEnd: (ms) =>
                        onChangeEnd(Duration(milliseconds: ms.toInt())),
                  ),
                ),
                const SizedBox(width: Dimens.spacingXs),
                _hideWhileSeeking(
                  TextButton(
                    style: _panelBtnStyle(speedOpen),
                    onPressed: onPickSpeed,
                    child: Text(
                      rateLabel,
                      style: TextStyle(
                        fontSize: 13 * form.typeScale,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                if (onPickSubtitles != null)
                  _hideWhileSeeking(
                    TextButton(
                      style: _panelBtnStyle(subOpen),
                      onPressed: onPickSubtitles,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.subtitles_rounded,
                            size: 17 * form.typeScale,
                          ),
                          const SizedBox(width: Dimens.spacingXs),
                          Text(
                            '字幕',
                            style: TextStyle(
                              fontSize: 13 * form.typeScale,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (onPickEpisodes != null)
                  _hideWhileSeeking(
                    TextButton(
                      style: _panelBtnStyle(epOpen),
                      onPressed: onPickEpisodes,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.format_list_bulleted_rounded,
                            size: 17 * form.typeScale,
                          ),
                          const SizedBox(width: Dimens.spacingXs),
                          Text(
                            '选集',
                            style: TextStyle(
                              fontSize: 13 * form.typeScale,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
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
        ? Text(formatSpeed(2.0), style: textStyle)
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
