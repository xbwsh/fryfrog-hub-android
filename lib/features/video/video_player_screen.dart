import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/media_models.dart';
import '../../core/models/video.dart';
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
  // 字幕诊断：mpv error 级日志（PlayerConfiguration.logLevel 默认 error 即有）。
  StreamSubscription<PlayerLog>? _mpvLogSub;
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

  // ── 顶栏留白 ───────────────────────────────────────────────────────
  //
  /// 播放期间系统栏恒定隐藏，所以**不能**用 SafeArea：immersive 下
  /// `padding.top` 为 0（横屏时开孔也在侧边），SafeArea 等于没留白，
  /// 返回键会贴到屏幕物理顶边。改用固定的最小留白，位置恒定、不会跳动。

  // ── 倍数（长按临时 2.0x 时不改这里）────────────────────────────────
  double _rate = 1.0;

  /// 字幕字号倍率（四档 0.85 / 1.0 / 1.2 / 1.45，1.0 默认），持久化于 AppPrefs。
  double _subScale = 1.0;

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
    _subScale = widget.session.prefs.subScale;
    // 音量手势自己画 HUD，不要 Android 再弹一条系统音量条盖住画面。
    VolumeController.instance.showSystemUI = false;
    _enterImmersive();
    _init();
  }

  /// Landscape + hide system bars while the player owns the screen.
  ///
  /// 播放期间**恒定沉浸**：状态栏与底部导航条全程不出现，画面占满整屏。
  /// 控制栏自己显隐，但不再牵动系统栏——两者各管各的反而更稳，也不会因为
  /// 系统栏进出导致顶栏留白硬切而跳动。
  ///
  /// 竖屏进场有两个坑（都实测复现过），顺序很关键：
  ///   1. **先旋转再设 immersive 会闪一下**：竖屏→横屏的旋转动画期间系统栏
  ///      可见，要等 immersive 生效才消失，中间约半秒状态栏「先出现再消失」。
  ///      横屏进场旋转瞬时完成，所以看不出问题。
  ///      → 先设 immersive 压制系统栏，再旋转。
  ///   2. **旋转会冲掉 immersive**：Android 在旋转中重建窗口并重新应用系统栏
  ///      策略，把设好的 immersive 重置——于是状态栏和小白条一直留着。
  ///      → 旋转落定后补设一次（见 [_confirmImmersive]）。
  Future<void> _enterImmersive() async {
    // 顺序要紧：先压制系统栏（避免旋转期间闪现），再锁横屏。
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    unawaited(_confirmImmersive());
  }

  /// 旋转落定后补一次 immersive。
  ///
  /// 竖屏进场时，方向锁定的旋转动画会重建窗口并重置系统栏策略。等旋转跑完
  /// 再重设一次即可稳定隐藏。横屏进场时旋转几乎瞬时，这次调用同样无害
  /// （幂等）。
  ///
  /// 延迟取 [_immersiveRetryDelay]：略长于系统旋转动画（实测约 300ms 级）。
  /// 因为进场时已经先设过 immersive，这段等待期系统栏也是藏着的，不会闪。
  Future<void> _confirmImmersive() async {
    if (_exiting) return;
    await Future<void>.delayed(_immersiveRetryDelay);
    if (_exiting || !mounted) return;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// 旋转落定后补设 immersive 的等待时长。
  static const Duration _immersiveRetryDelay = Duration(milliseconds: 450);

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
      _externalSubs = const [];
    });
    // 拉外挂字幕（与视频同目录的 .srt/.ass，mpv 不会自动识别）。
    unawaited(_loadExternalSubs(_current.id));
    try {
      final api = widget.session.api;
      if (api == null) throw Exception('未登录');
      final url = api.videoStreamUrl(_current);

      await _teardownPlayer();
      if (_exiting || !mounted) return;

      // ★ 决定性修复：media_kit 的 PlayerConfiguration.libass **默认 false**，
      //   会下发 sub-ass=no —— ASS 样式和全部 tag（\p1 矢量绘图、\k 卡拉OK、
      //   \pos 定位…）被禁用，按纯文本渲染：满屏绘图指令、卡拉OK崩坏、
      //   双图层错位……iOS 端直连 libmpv 没有这层，默认就是完整 ASS，
      //   所以一直正常。libass=true → sub-ass=yes 才是完整特效渲染。
      //   （media_kit 配套的 libassAndroidFont 资产字体方案是给官方残废
      //     libmpv 用的，我们有 fontconfig+/system/fonts，不需要。）
      final player = Player(
        configuration: PlayerConfiguration(libass: true),
      );
      final controller = VideoController(player);
      _player = player;
      _controller = controller;
      // 倍数是跨集保留的：换集后新 player 要重新套上。
      unawaited(player.setRate(_rate));
      // VideoController 的创建是异步的，media_kit 的 Android 实现会在
      // AndroidVideoController.create 里把 sub-font-provider 设成 none
      // （官方 libmpv 没编 fontconfig，关了也无所谓；但我们自编的带
      // fontconfig，关掉就白编了）。不等它设完就改会被覆盖回去 → libass
      // 找不到系统字体 → ASS 特效字幕竖排堆叠。platform 是 VideoController
      // 暴露的 Completer，await 它就能拿到「create 已全部写完」的时机。
      try {
        await controller.platform.future.timeout(const Duration(seconds: 5));
      } catch (_) {
        // 创建超时/异常不该阻塞播放；后面的字幕参数照常下发，
        // open 后还有一次兜底重设（该选项 UPDATE_SUB_HARD，可热更）。
      }
      // 字幕参数（字体/编码等）**必须在 open 之前**设好：libass 在打开媒体的
      // 时刻就解析字体，失了之后再设就不生效了。所以这里 await，不能
      // unawaited（那会与下面的 open 竞态，谁先到不定）。
      await _applySubtitleDefaults(player);
      if (_exiting || !mounted) return;

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
        // 播放→开始自动隐藏计时；暂停→取消（控件留在屏上）。
        _syncAutoHide();
        // 状态真的变了才闪图标，避免「点了没反应」时给出错误反馈。
        if (playing != _lastFlashPlayState) {
          _lastFlashPlayState = playing;
          _flashPlayState();
        }
      });
      _errSub = player.stream.error.listen((err) {
        if (!mounted || _exiting || err.isEmpty) return;
        _logSub('[SUBDBG|player-error] $err');
        setState(() => _error = err);
      });
      // mpv 日志订阅只在 debug 构建建立：release 下 error 文本可能带
      // 签名流 URL，不进正式包 logcat。
      if (kDebugMode) {
        _mpvLogSub = player.stream.log.listen((l) {
          if (!mounted || _exiting) return;
          _logSub('[MPV-${l.level}] ${l.prefix}: ${l.text}');
        });
      }
      _tracksSub = player.stream.tracks.listen((tracks) {
        if (!mounted || _exiting) return;
        final real = tracks.subtitle
            .where((t) => t.id != 'auto' && t.id != 'no')
            .toList(growable: false);
        setState(() => _subTracks = real);
        _logSub('[SUBDBG|tracks-event] ${real.map((t) => 'id=${t.id}/'
            '${t.title ?? t.language ?? '?'}').join(', ')}');
        // 轨道表刚就绪时同步一次选中态（自动选轨的解析见方法注释）。
        unawaited(_syncSubSelectionFromMpv());
        // 换片后轨道表被清空 → 兜底收起字幕面板，别让按钮悬空。
        if (real.isEmpty && _subOpen) _closePanels();
      });
      _trackSub = player.stream.track.listen((track) {
        if (!mounted || _exiting) return;
        final id = track.subtitle.id;
        // mpv 自动选轨时 media_kit 上报占位 id 'auto'——画面已有字幕但
        // 面板对不上任何一行。等 tracks 里拿到具体 id，或直接查 mpv。
        if (id == 'auto') {
          unawaited(_syncSubSelectionFromMpv());
          return;
        }
        setState(() => _subSelectedId = id);
      });

      await player.open(Media(url), play: true);
      if (_exiting || !mounted) return;
      // 兜底重设：上面 await 控制器创建若超时，media_kit 的 none 可能晚于
      // 我们那次写入；sub-font-provider 带 UPDATE_SUB_HARD，此刻再写一次
      // 会重建字幕轨并生效，确保最终值是 fontconfig。
      final postOpenPlat = player.platform;
      if (postOpenPlat is NativePlayer) {
        try {
          await postOpenPlat.setProperty('sub-font-provider', 'fontconfig');
        } catch (_) {
          // 设不上不影响播放，字幕参数问题会在画面上暴露。
        }
      }
      unawaited(_debugSubs('open-done'));

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
    await _mpvLogSub?.cancel();
    await _tracksSub?.cancel();
    await _trackSub?.cancel();
    _posSub = _durSub = _playSub = _errSub = null;
    _mpvLogSub = null;
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
      if (kDebugMode) debugPrint('save progress failed: $e');
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
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
    _playFlashTimer?.cancel();
    _playFlashTimer = null;
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
    if (_chromeVisible) {
      _scheduleAutoHide();
    } else {
      _autoHideTimer?.cancel();
    }
  }

  // ── 控制栏自动隐藏 ─────────────────────────────────────────────────
  ///
  /// 播放器不该一直挂着控件挡画面：显示后 [_chromeAutoHideDelay] 内无操作就收起。
  /// 只在**播放中**计时——暂停时把控件留在屏上，用户才看得见进度/继续按钮。
  Timer? _autoHideTimer;

  /// 无操作多久后自动收起控制栏。
  static const Duration _chromeAutoHideDelay = Duration(seconds: 5);

  /// 安排一次自动隐藏。已安排/正在 seek/已暂停/控制栏本就隐藏时不重复安排。
  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
    if (_exiting || !_chromeVisible || _seeking || !_playing) return;
    _autoHideTimer = Timer(_chromeAutoHideDelay, () {
      _autoHideTimer = null;
      if (!mounted || _exiting || !_chromeVisible || !_playing) return;
      // 面板/抽屉开着时别收，否则会盖住用户正在操作的东西。
      if (_epOpen || _speedOpen || _subOpen) return;
      setState(() => _chromeVisible = false);
    });
  }

  /// 播放状态变化后重新安排/取消自动隐藏。
  void _syncAutoHide() {
    if (_playing && _chromeVisible) {
      _scheduleAutoHide();
    } else {
      _autoHideTimer?.cancel();
      _autoHideTimer = null;
    }
  }

  /// 进度条被拖动时暂停自动隐藏，松手后再重新计时——拖动过程中控件不能消失。
  void _holdAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
  }

  // ── 播放/暂停的中央图标反馈 ─────────────────────────────────────────
  //
  /// null = 不显示；否则显示该状态的图标。
  ///
  /// 暂停时**常驻**（不自动消失），恢复播放时才闪一下就淡出——和主流播放器
  /// 一致。理由：暂停是个稳定状态，用户要靠这个图标（和进度条一起）确认
  /// 「现在是停着的」，闪一下就没等于没反馈；而恢复播放是个瞬时动作，图标只需
  /// 短暂确认一下就会消失，不该挡着画面。
  bool? _playFlash;

  /// 播放/暂停时在中央闪一下图标，给用户明确反馈。
  void _flashPlayState() {
    // 加载中不闪：加载背景中央已有进度圈，再叠一个图标会糊在一起。
    if (!mounted || _loading) return;
    _playFlashTimer?.cancel();
    _playFlashTimer = null;
    setState(() => _playFlash = _playing);
    // 只在「恢复播放」时淡出；暂停时保持常驻。
    if (!_playing) return;
    _playFlashTimer = Timer(_PlayFlashState.fadeDuration, () {
      _playFlashTimer = null;
      if (mounted) setState(() => _playFlash = null);
    });
  }

  Timer? _playFlashTimer;

  /// 上一次闪图标时的播放状态，用来判断「状态是否真的变了」。
  bool _lastFlashPlayState = true;

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

  /// 字幕字号四档切换（0.85 / 1.0 / 1.2 / 1.45，见 SubtitlePanel.scaleOptions）。
  ///
  /// 热更新已核对 mpv 源码链路：sub-scale 变更携带 UPDATE_OSD →
  /// `mp_option_change_callback` 对每条字幕轨发 `SD_CTRL_UPDATE_OPTS` →
  /// sd_ass 无条件置 `ass_configured=false` → 下一帧 `get_bitmaps`
  /// 重跑 `configure_ass` → `ass_set_font_scale(新值)`，无需重建字幕轨。
  Future<void> _setSubScale(double value) async {
    if (_exiting) return;
    setState(() => _subScale = value);
    unawaited(widget.session.prefs.setSubScale(value));
    final plat = _player?.platform;
    if (plat is NativePlayer) {
      try {
        await plat.setProperty('sub-scale', value.toStringAsFixed(2));
      } catch (_) {
        // 设不上不影响播放，下次 open 时 _applySubtitleDefaults 会补。
      }
    }
    _scheduleAutoHide();
  }

  /// 诊断日志门：`kDebugMode` 是编译期常量，release 构建整段裁剪——
  /// [SUBDBG]/mpv 错误文本（可能含签名流 URL）不会进正式包 logcat，
  /// debug 包保留完整排查能力。
  void _logSub(String message) {
    if (kDebugMode) debugPrint(message);
  }

  /// 字幕诊断快照：把 mpv 的 sid/secondary-sid/track-list 等关键状态打到
  /// logcat（[SUBDBG] 前缀），用于排查双字幕、关了选不回来这类状态问题。
  Future<void> _debugSubs(String why) async {
    if (!kDebugMode) return;
    final player = _player;
    if (player == null) return;
    final plat = player.platform;
    if (plat is! NativePlayer) return;
    final parts = <String>[];
    for (final name in [
      'sid',
      'secondary-sid',
      'sub-visibility',
      'secondary-sub-visibility',
      'sub-font-provider',
      'embeddedfonts',
    ]) {
      try {
        parts.add('$name=${await plat.getProperty(name)}');
      } catch (_) {
        parts.add('$name=ERR');
      }
    }
    final sel = player.state.track.subtitle;
    parts.add('sel(id=${sel.id},title=${sel.title})');
    debugPrint('[SUBDBG|$why] ${parts.join(' ')}');
    try {
      final tl = await plat.getProperty('track-list');
      debugPrint('[SUBDBG|$why] track-list=$tl');
    } catch (e) {
      debugPrint('[SUBDBG|$why] track-list ERR: $e');
    }
  }

  /// 面板选中态与 mpv 实际显示对齐。
  ///
  /// mpv 自动选轨（`sid=auto` → 默认简体）后 media_kit 上报的当前轨是
  /// 占位 id `'auto'`，面板按 `selectedId == track.id` 高亮 → 对不上任何
  /// 一行（画面有字幕、面板却没选中）。mpv 的 `track-list` 里每个 sub
  /// 条目带 `"selected": true/false`，以它为唯一事实来源解析出具体 id。
  /// 仅在当前状态为 null/'auto' 时介入，不覆盖用户显式选择（含"关闭"）。
  Future<void> _syncSubSelectionFromMpv() async {
    final cur = _subSelectedId;
    if (cur != null && cur != 'auto') return;
    final plat = _player?.platform;
    if (plat is! NativePlayer) return;
    try {
      final raw = await plat.getProperty('track-list');
      final list = jsonDecode(raw) as List<dynamic>;
      String? sel;
      for (final t in list) {
        if (t is Map && t['type'] == 'sub' && t['selected'] == true) {
          sel = '${t['id']}';
          break;
        }
      }
      if (!mounted || _exiting) return;
      // 解析不出（真没选任何轨）时保持"关闭"高亮，别把 no 冲掉。
      final next = sel ?? (cur == 'no' ? 'no' : null);
      if (_subSelectedId != next) {
        setState(() => _subSelectedId = next);
      }
    } catch (_) {
      // track-list 未就绪/解析失败：维持现状，不影响播放。
    }
  }

  /// 字幕面板里选了一轨（`SubtitleTrack.no()` = 关闭）：先收面板再切轨。
  Future<void> _setSubtitle(SubtitleTrack track) async {
    if (_exiting) return;
    _closePanels();
    _logSub('[SUBDBG|user-select] id=${track.id} title=${track.title}');
    await _debugSubs('before-select');
    // 切轨就等于换轨：mpv 在 setSubtitleTrack 时会卸掉上一条 uri 轨，
    // 所以不用像 iOS 那样手工 sub-remove记账。
    await _player?.setSubtitleTrack(track);
    await _debugSubs('after-select');
    _scheduleAutoHide();
  }

  // ── 外挂字幕 ────────────────────────────────────────────────────────
  //
  // mpv 只自动识别**容器内嵌**的字幕轨；与视频同目录的外挂 .srt/.ass 需要
  // 客户端主动加载。iOS 端一直用 `sub-add` 加载，Android 端原先没接，
  // 于是只有内嵌字幕能用——这就是两端表现不一致的根因。
  //
  // 这里用 media_kit 官方的 [SubtitleTrack.uri]：它内部就是 sub-add，
  // 但切走时 mpv 会自动卸载 uri 轨，不用像 iOS 那样手工记账 sub-remove。
  List<ExternalSubtitle> _externalSubs = const [];

  /// 播放器创建后立刻下发的字幕相关 mpv 参数。
  ///
  /// 必须在 [Player.open] **之前**设：libass 在打开媒体的瞬间就按当时的
  /// 配置建立字体缓存，之后再设不生效。
  ///
  /// 不设这些就是 libmpv 默认值，和 iOS 端（`MpvPlayer.swift` 里显式
  /// `vo=libmpv` + `sub-auto=no` + 手动选轨）行为不一致，字幕就会表现不同：
  ///
  /// · `sub-auto=no`：默认 `all`，会探测**流URL 旁边**的 sidecar 字幕文件。
  ///   流地址（`/api/v1/video/{id}/stream`）旁边当然什么都没有，于是刷一串
  ///   404，还可能打乱自动选中的 `sid`。外挂字幕走 [SubtitleTrack.uri]
  ///   显式加载，所以关掉自动探测。
  /// · `sub-ass-scale-with-window=yes`：字号按窗口而非视频原始分辨率缩放。
  ///   1920x1080 的流渲到手机屏时，按原始分辨率算的字会明显偏小、行距错乱。
  ///
  /// ⚠️ **不要瞎加字体相关参数**：这个 libmpv（media_kit 预编译）**没有**
  /// `sub-fonts` / `sub-ass-fonts` / `sub-ass-font-fallback` 这些选项——
  /// 二进制里搜不到，设了会被静默忽略。字体只能由 libass 走 fontconfig
  /// 自找，客户端改不了。
  ///
  /// 参数下发失败不能影响播放，所以全部吞掉异常。
  Future<void> _applySubtitleDefaults(Player player) async {
    final platform = player.platform;
    if (platform is! NativePlayer) return;
    // final（非 const）：sub-scale 取运行时的 _subScale 档位值。
    final opts = <List<String>>[
      // ── 与 iOS 端（MpvPlayer.swift）对齐的最小集 ─────────────────────
      // iOS 端几乎只设 vo/sub-auto，ASS 全走 mpv 默认——特效字幕正常。
      // mpv 的 sub-ass-override 默认 yes：所有 sub-ass-* 选项都会应用到
      // ASS 上，文档明说 sub-ass-scale-with-window/sub-scale "can break
      // ASS subtitles"——之前设的 sub-ass-scale-with-window=yes 正是
      // 卡拉OK双图层错位、布局崩坏的元凶。默认值能对齐 iOS 就别动。

      // 不自动探测 sidecar 文件（会对流地址刷 404，且会乱掉 sid）。
      ['sub-auto', 'no'],
      // 显式保证字幕层可见。
      ['sub-visibility', 'yes'],
      // 字幕字号倍率（三档设置的持久化值）。sub-scale 在 override≥yes 时
      // 经 ass_set_font_scale 作用于 ASS；变更带 UPDATE_OSD 标志会触发
      // sd_ass 重跑 configure_ass（mpv command.c → SD_CTRL_UPDATE_OPTS →
      // ass_configured=false → 下一帧生效），可热更新。
      ['sub-scale', _subScale.toStringAsFixed(2)],
      // ⚠️ 不要设 sub-scale 以外的 sub-ass-* 覆盖项：它们同样会作用于
      // ASS（override 默认 yes），破坏与 iOS 一致的原始 Style。
      ['sub-font-provider', 'fontconfig'],
    ];
    for (final opt in opts) {
      try {
        await platform.setProperty(opt[0], opt[1]);
      } catch (_) {
        // 单个参数不支持就跳过，不影响其它。
      }
    }
  }

  /// 拉取当前视频的外挂字幕列表（切集后要重拉）。
  Future<void> _loadExternalSubs(int videoId) async {
    final api = widget.session.api;
    if (api == null) return;
    try {
      final subs = await api.fetchSubtitles(videoId);
      if (!mounted || _exiting) return;
      setState(() => _externalSubs = subs);
    } catch (_) {
      // 拉不到就当没有外挂字幕，不该影响内嵌字幕和播放本身。
    }
  }

  /// 选中某个外挂字幕。
  Future<void> _setExternalSubtitle(ExternalSubtitle sub) async {
    final player = _player;
    if (_exiting || player == null) return;
    _closePanels();
    await player.setSubtitleTrack(
      SubtitleTrack.uri(
        sub.url,
        title: sub.displayName,
        language: sub.language,
      ),
    );
    _scheduleAutoHide();
  }

  /// 关闭外挂字幕（并彻底关掉字幕输出）。
  Future<void> _clearExternalSubtitle() async {
    if (_exiting) return;
    _closePanels();
    _logSub('[SUBDBG|user-off]');
    await _debugSubs('before-off');
    await _player?.setSubtitleTrack(SubtitleTrack.no());
    await _debugSubs('after-off');
    _scheduleAutoHide();
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
    // 拖动期间控件必须留在屏上（拖到一半消失没法用），暂停自动隐藏计时。
    _holdAutoHide();
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
    // 松手后恢复自动隐藏计时（拖动过程中由 _beginSeek 暂停过）。
    _syncAutoHide();
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
            // 长按倍速期间可能同时在加载（切集），同样避开与进度圈重叠。
            if ((_adjusting || _speedUp) && !_exiting && !_loading)
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
            // 播放/暂停的中央大图标反馈（短暂淡出，不抢画面）。
            //
            // 加载中不显示：加载背景自带中央进度圈，两者都在正中会叠成
            // 「圈里套个图标」的糊状。加载时也没有可暂停的帧，提示无意义。
            if (_playFlash != null && !_exiting && !_loading)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(child: _PlayFlash(playing: _playFlash!)),
                ),
              ),
            // 控制栏常驻树内，只靠滑入/滑出动画进出（见 _ChromeReveal）：
            // 顶栏从上往下、底栏从下往上，与系统栏的显隐方向一致。
            // _exiting 时才真正从树里摘掉，避免退出动画中途被重建打断。
            if (!_exiting) ...[
              if (_initialized || _loading || _error != null)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _ChromeReveal(
                    // seek 中顶栏也一并收起（只剩底部进度条）。
                    shown: _chromeVisible && !_seeking,
                    axis: _ChromeAxis.top,
                    child: _TopChrome(form: form, title: _title, onBack: _exit),
                  ),
                ),
              if (_initialized && _player != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _ChromeReveal(
                    shown: _chromeVisible,
                    axis: _ChromeAxis.bottom,
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
                ),
            ],
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
                  subScale: _subScale,
                  onScaleChanged: _setSubScale,
                  externalSubs: _externalSubs,
                  onPickExternal: _setExternalSubtitle,
                  onClearExternal: _clearExternalSubtitle,
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
      // 加载中：绿紫晕染背景铺满画面 + 呼吸动画，中央再叠一个进度圈。
      // 黑屏等视频太「硬」，用有色彩层次的背景过渡更像是在「准备播放」。
      return const _LoadingBackdrop();
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
      return CircularProgressIndicator(color: AppColors.accentOf(context));
    }
    return Video(
      controller: controller,
      controls: NoVideoControls,
      fit: BoxFit.contain,
    );
  }
}

/// chrome 滑入/滑出的方向：顶栏自上而下，底栏自下而上。
enum _ChromeAxis { top, bottom }

/// 控制栏的进出场包装：按方向滑入/滑出 + 渐隐，并屏蔽隐藏态的点击。
///
/// 为什么不用 `if (_chromeVisible)` 直接增删：
///   直接增删没有任何过渡，「啪一下出现」，观感上就是「卡一下」。
///
/// **进出必须对称**：进场与退场用同一条曲线、同一个时长，否则一侧「唰」
/// 地消失、另一侧「黏」地淡出，两下看起来不是一个动作。位移上，进场从
/// 视口外滑到原位、退场从原位滑回视口外，方向严格相反、对称。
class _ChromeReveal extends StatelessWidget {
  const _ChromeReveal({
    required this.shown,
    required this.axis,
    required this.child,
  });

  final bool shown;
  final _ChromeAxis axis;
  final Widget child;

  /// 隐藏时滑出的方向：顶栏往上、底栏往下（与进场方向相反）。
  Offset get _hiddenOffset => switch (axis) {
    _ChromeAxis.top => const Offset(0, -1.2),
    _ChromeAxis.bottom => const Offset(0, 1.2),
  };

  @override
  Widget build(BuildContext context) {
    // 用户在系统里开了「移除动画」时干脆不播，直接到位。
    final dur = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Dimens.playerChromeAnimDuration;

    // easeInOutCubic：进出共用一条自带对称性的曲线（前半段渐快、后半段渐慢，
    // 反向播放正好是它的镜像），这样「滑入」与「滑出」严格互为镜像、时长一致。
    // 早前用 easeOutCubic 是错的——它是单向曲线，退场时「猛地淡出」，与进场的
    // 「缓缓淡入」不对称，看着像两个动作。
    const curve = Curves.easeInOutCubic;

    final content = AnimatedSlide(
      offset: shown ? Offset.zero : _hiddenOffset,
      duration: dur,
      curve: curve,
      child: AnimatedOpacity(
        opacity: shown ? 1 : 0,
        duration: dur,
        curve: curve,
        child: child,
      ),
    );

    return IgnorePointer(ignoring: !shown, child: content);
  }
}

/// 视频加载中的过渡背景（≈原型 `.loading-bg`）。
///
/// 三层叠加：左上偏中的青绿径向光晕 + 右下的蓝紫径向光晕 + 深色斜向底渐变；
/// 另叠一层极淡的网格线（径向遮罩，只在画面中心附近可见）。整体做 2.4s 的
/// 明暗呼吸动画，避免静止画面显得死板。
///
/// 配色按需求固定为原型值（不跟随主题色）。
class _LoadingBackdrop extends StatefulWidget {
  const _LoadingBackdrop();

  @override
  State<_LoadingBackdrop> createState() => _LoadingBackdropState();
}

class _LoadingBackdropState extends State<_LoadingBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _LoadingBackdropState.pulseDuration,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 三层渐变整体做呼吸：明暗 1↔1.15、饱和 1↔1.2（原型 loadingPulse）。
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_c.value);
            final brightness = 1.0 + 0.15 * t;
            final saturate = 1.0 + 0.20 * t;
            return DecoratedBox(
              // 底层：深蓝灰 → 近黑，斜向（对应原型 160° linear-gradient）。
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF161A22), Color(0xFF0A0B0F)],
                ),
              ),
              // 两处径向光晕用内层 Stack 叠在底渐变上——BoxDecoration 只支持
              // 单个渐变，画不了三个。
              child: Stack(
                fit: StackFit.expand,
                children: [
                  for (final g in _LoadingGlowSpec.values)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: g.center,
                          radius: g.radius,
                          colors: [
                            g.color.withValues(
                              alpha: (g.baseAlpha * saturate * brightness)
                                  .clamp(0.0, 1.0),
                            ),
                            g.color.withValues(alpha: 0),
                          ],
                          // 原型 transparent 落在 55% 处。
                          stops: const [0.0, 0.55],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        // 极淡网格线（原型 ::after）。
        const _GridOverlay(),
        // 中央进度圈：叠在背景之上。
        Center(
          child: SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
      ],
    );
  }

  /// 呼吸动画周期（原型 loadingPulse 2.4s ease-in-out）。
  static const Duration pulseDuration = Duration(milliseconds: 2400);
}

/// 两处径向光晕的位置与配色。
enum _LoadingGlowSpec {
  teal(
    center: Alignment(-0.44, -0.36),
    color: Color(0xFF00C8B4),
    baseAlpha: 0.30,
  ),
  indigo(
    center: Alignment(0.52, 0.44),
    color: Color(0xFF5868FF),
    baseAlpha: 0.28,
  );

  const _LoadingGlowSpec({
    required this.center,
    required this.color,
    required this.baseAlpha,
  });

  /// 中心点：原型 28%/32% → Alignment(-0.44,-0.36)；76%/72% → (0.52,0.44)。
  final Alignment center;

  /// 光晕颜色。
  final Color color;

  /// 峰值不透明度（原型 .30 / .28）。
  final double baseAlpha;

  /// 半径（原型 transparent 55%，这里作为 RadialGradient 的归一化半径）。
  double get radius => 1.1;
}

/// 原型 `.loading-bg::after` 的极淡网格线：52px 网格 + 径向遮罩。
class _GridOverlay extends StatelessWidget {
  const _GridOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _GridPainter(), size: Size.infinite),
    );
  }
}

class _GridPainter extends CustomPainter {
  /// 网格间距（原型 52px）。
  static const double cell = 52;

  @override
  void paint(Canvas canvas, Size size) {
    final half = size.longestSide / 2;
    final origin = Offset(size.width / 2, size.height / 2);
    for (double x = 0; x < size.width; x += cell) {
      for (double y = 0; y < size.height; y += cell) {
        final center = Offset(x + cell / 2, y + cell / 2);
        final dist = ((center - origin).distance / half).clamp(0.0, 1.0);
        // 径向遮罩：中心 1 → 边缘 0；基础透明度取原型的 .028。
        final alpha = (1.0 - Curves.easeOut.transform(dist)) * 0.028;
        if (alpha <= 0.002) continue;
        final paint = Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha)
          ..strokeWidth = 1;
        canvas.drawLine(Offset(x, y), Offset(x + cell, y), paint);
        canvas.drawLine(Offset(x, y), Offset(x, y + cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 播放/暂停时在画面中央闪一下的大图标。
///
/// 没有它时，用户点了暂停却看不到任何反馈——画面在动、控件又可能已自动收起，
/// 很容易以为没点上。
///
/// **两种模式**：
/// · 暂停（playing=true 表示刚点暂停）→ **常驻**，不淡出。暂停是稳定状态，
///   用户需要它一直提示「现在是停着的」，和进度条一起构成完整状态反馈。
/// · 恢复播放 → 闪现约 [fadeDuration] 后淡出，不长期遮挡画面。
class _PlayFlash extends StatefulWidget {
  const _PlayFlash({required this.playing});

  /// true = 刚点暂停 → 显示「暂停」图标并常驻。
  final bool playing;

  @override
  State<_PlayFlash> createState() => _PlayFlashState();
}

class _PlayFlashState extends State<_PlayFlash>
    with SingleTickerProviderStateMixin {
  /// 恢复播放时的闪现时长；暂停态的淡入动画在 [fadeDuration] 前段就走完了，
  /// 之后停住不动，所以两种模式可以共用一个 controller。
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: fadeDuration,
  );

  /// 是否已经播过一次。
  ///
  /// 关键点：`_playFlash` 是从 `null` 变成 true/false 的，所以每闪一次都是
  /// **新建** `_PlayFlash`——不是更新已有的。而 `AnimationController` 初始
  /// 值就是 1.0（已播完），只有 `didUpdateWidget` 会 `forward(from: 0)`，
  /// 新建的这首个 build 什么都不触发，动画永远不播（图标一出现就没了）。
  /// 所以首次 build 必须主动 forward。
  @override
  void initState() {
    super.initState();
    _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(_PlayFlash old) {
    super.didUpdateWidget(old);
    if (old.playing != widget.playing) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FadeTransition(
        // 前 35% 时间淡入，之后**保持不透明**（Interval 在 0.35 之后被 clamp
        // 到 1，不会自动淡出）。暂停态靠外层「不启动消失计时器」常驻，
        // 恢复播放态靠计时器移除组件，两者都无需在这里做淡出。
        opacity: CurvedAnimation(
          parent: _c,
          curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
        ),
        child: ScaleTransition(
          scale: Tween(
            begin: 0.82,
            end: 1.0,
          ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack)),
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              // 半透明圆底：在亮画面上也能看清，但不遮挡画面主体。
              color: Colors.black.withValues(alpha: 0.42),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 46,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  /// 大图标从出现到淡出的总时长。
  static const Duration fadeDuration = Duration(milliseconds: 620);
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
        // 不用 SafeArea：系统栏恒定沉浸，padding.top 为 0，等于没避让，
        // 返回键会贴到物理顶边。给固定留白，位置恒定。
        child: Padding(
          padding: const EdgeInsets.only(top: Dimens.playerChromeMinTop),
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
  ButtonStyle _panelBtnStyle(BuildContext context, bool active) {
    return TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.spacingSm),
      minimumSize: Size(44 * form.typeScale, 32),
      foregroundColor: active ? AppColors.accentOf(context) : Colors.white,
      backgroundColor: active
          ? AppColors.accentOf(context).withValues(alpha: 0.12)
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
        // 与顶栏同理：系统栏恒定隐藏，SafeArea 给不出避让，统一用固定内边距。
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
                  style: _panelBtnStyle(context, speedOpen),
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
                    style: _panelBtnStyle(context, subOpen),
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
                    style: _panelBtnStyle(context, epOpen),
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
