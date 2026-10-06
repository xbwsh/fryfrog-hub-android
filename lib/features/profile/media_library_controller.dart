import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/media_models.dart';
import '../../core/network/gateways.dart';

/// Orchestration for the media library admin screen:
/// list CRUD, directory browsing and scan progress polling.
class MediaLibraryController extends ChangeNotifier {
  MediaLibraryController({required this.gateway});

  final MediaLibraryGateway gateway;

  List<MediaLibrary> libraries = [];
  bool loading = false;
  String? error;
  bool busy = false;

  // ── Scan progress state ─────────────────────────────────────────────
  bool scanning = false;

  /// null = scanning all libraries; otherwise the single library id.
  int? scanningId;
  String scanStage = '';
  String? scanCurrentItem;
  double scanPercent = 0;

  Timer? _poll;
  Timer? _hideDone;

  /// Consecutive 1-empty responses in scan-all mode; guards against the
  /// server never registering the scan (otherwise we poll 1 req/s forever).
  int _emptyTicks = 0;
  bool _disposed = false;

  /// No-op after dispose: async ticks/CRUD can resume post-dispose and
  /// notifyListeners() would otherwise assert in debug.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  static const Map<String, String> _stageLabels = {
    'scan': '扫描中',
    'scrape': '刮削中',
    'actors': '抓取演员',
    'assets': '处理图片',
    'done': '完成',
    'idle': '空闲',
  };

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final list = await gateway.fetchLibraries();
      list.sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
      libraries = list;
    } catch (e) {
      error = '$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> save({
    MediaLibrary? edit,
    required String name,
    required String path,
    required String subType,
    required bool enabled,
    bool enableScraping = true,
    bool isAdult = false,
    String? description,
  }) async {
    busy = true;
    notifyListeners();
    try {
      if (edit == null) {
        final created = await gateway.createLibrary(
          name: name,
          path: path,
          subType: subType,
          enabled: enabled,
          enableScraping: enableScraping,
          isAdult: isAdult,
          description: description,
        );
        libraries = [...libraries, created];
      } else {
        final updated = await gateway.updateLibrary(
          edit.id,
          name: name,
          path: path,
          subType: subType,
          enabled: enabled,
          enableScraping: enableScraping,
          isAdult: isAdult,
          description: description,
        );
        libraries = [
          for (final lib in libraries) lib.id == updated.id ? updated : lib,
        ];
      }
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> toggle(MediaLibrary lib) async {
    final updated = await gateway.toggleLibrary(lib.id);
    libraries = [
      for (final item in libraries) item.id == updated.id ? updated : item,
    ];
    notifyListeners();
  }

  Future<void> remove(int id) async {
    busy = true;
    notifyListeners();
    try {
      await gateway.deleteLibrary(id);
      libraries = libraries.where((l) => l.id != id).toList(growable: false);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<List<LibraryDirItem>> browse(String? path) =>
      gateway.browse(path: path);

  // ── Scanning ────────────────────────────────────────────────────────

  /// Starts a scan of all enabled libraries.
  /// Returns an error/status message for the UI (null = polling started).
  Future<String?> startScanAll() async {
    if (_poll != null) return null;
    final count = await gateway.scanAll();
    if (count == 0) return '没有启用的资源库';
    _beginScan(null, '准备扫描…');
    return null;
  }

  /// Starts a scan of one library. Returns error message or null.
  Future<String?> startScanOne(int id) async {
    if (_poll != null) return null;
    await gateway.scanOne(id);
    final lib = libraries.where((l) => l.id == id).firstOrNull;
    _beginScan(id, '「${lib?.name ?? ''}」准备中…');
    return null;
  }

  /// 批量刷新该库已绑定视频的元数据（后台任务，立即返回提示语）。
  ///
  /// 后端只处理已绑定的记录，未刮削的会被跳过——那些是用户刻意留在未绑定
  /// 状态的（TMDB 上没有），强搜只会写入错误内容。
  Future<String> refreshLibraryMetadata(int libraryId) async {
    return gateway.refreshLibraryMetadata(libraryId);
  }

  /// 批量重写该库的剧级/季级 NFO（后台任务，立即返回提示语）。
  ///
  /// 不复用扫描进度：这是独立任务，进度键是 `nfo:{libraryId}`，
  /// 混进扫描进度会让「扫描中」的显示错乱。
  Future<String> regenerateNfo({int? libraryId}) async {
    return gateway.regenerateNfo(libraryId: libraryId);
  }

  void _beginScan(int? id, String stage) {
    _hideDone?.cancel();
    scanning = true;
    scanningId = id;
    scanStage = stage;
    scanCurrentItem = null;
    scanPercent = 0;
    _emptyTicks = 0;
    notifyListeners();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _tick();
  }

  Future<void> _tick() async {
    if (!scanning) return;
    try {
      final id = scanningId;
      if (id == null) {
        final list = await gateway.fetchScanProgress();
        if (list.isEmpty) {
          // Progress not registered yet is normal for a few seconds;
          // give up after 15 so a lost scan cannot poll forever.
          if (++_emptyTicks >= 15) {
            scanStage = '扫描状态获取超时';
            _finishScan();
            notifyListeners();
          }
          return;
        }
        _emptyTicks = 0;
        var total = 0;
        var done = 0;
        final items = <String>{};
        for (final p in list) {
          total += p.total;
          done += p.done;
          final current = p.currentItem;
          if (current != null && current.isNotEmpty) items.add(current);
        }
        final allDone = list.every((p) => !p.running);
        scanPercent = total == 0 ? 0 : done / total * 100;
        scanCurrentItem = items.isEmpty ? null : items.join('、');
        scanStage = allDone ? '扫描完成' : '扫描 $done/$total';
        if (allDone) _finishScan();
      } else {
        final p = await gateway.fetchPipelineProgress(id);
        final stageLabel = _stageLabels[p.stage] ?? p.stage;
        final lib = libraries.where((l) => l.id == id).firstOrNull;
        scanPercent = p.percent;
        scanCurrentItem = p.currentItem;
        scanStage = '「${lib?.name ?? ''}」$stageLabel';
        final done = !p.running || p.stage == 'done' || p.percent >= 100;
        if (done) _finishScan();
      }
      notifyListeners();
    } catch (_) {
      // Polling failures are transient — keep trying on the next tick.
    }
  }

  void _finishScan() {
    _poll?.cancel();
    _poll = null;
    scanPercent = 100;
    // Hide the banner a few seconds after completion.
    _hideDone = Timer(const Duration(seconds: 5), () {
      if (!scanning) return;
      scanning = false;
      scanningId = null;
      scanStage = '';
      scanCurrentItem = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _hideDone?.cancel();
    super.dispose();
  }
}
