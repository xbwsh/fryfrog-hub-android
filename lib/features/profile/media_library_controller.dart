import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/media_models.dart';
import '../../core/network/gateways.dart';

typedef _JobPoll = Future<bool?> Function();

/// Orchestration for the media library admin screen:
/// list CRUD, directory browsing and scan progress polling.
class MediaLibraryController extends ChangeNotifier {
  MediaLibraryController({required this.gateway});

  final MediaLibraryGateway gateway;

  List<MediaLibrary> libraries = [];
  bool loading = false;
  String? error;
  bool busy = false;

  bool taskRunning = false;
  String taskStage = '';
  String? taskDetail;
  double taskPercent = 0;
  int catalogRevision = 0;

  Timer? _poll;
  Timer? _hideDone;
  int _missingTicks = 0;
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
      final list = [...await gateway.fetchLibraries()];
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

  Future<String?> startScanAll() => _startJob('准备扫描…', () async {
    final submission = await gateway.scanAll();
    if (submission.count == 0) return (null, '没有启用的资源库');
    final ids = submission.libraryIds?.toSet();
    final pipelines = <int, LibraryScanProgress>{};
    return (() => _pollScanAll(ids, submission.count, pipelines), null);
  });

  Future<String?> startScanOne(int id) => _startJob('准备扫描…', () async {
    await gateway.scanOne(id);
    final name = libraries.where((l) => l.id == id).firstOrNull?.name;
    return (() => _pollScanOne(id, name), null);
  });

  Future<String?> refreshLibraryMetadata(int id) => _startMetadata(
    '刷新元数据',
    'rescrape:$id',
    () => gateway.refreshLibraryMetadata(id),
    refreshCatalog: true,
  );

  Future<String?> regenerateNfo({required int libraryId}) => _startMetadata(
    '重写 NFO',
    'nfo:$libraryId',
    () => gateway.regenerateNfo(libraryId: libraryId),
  );

  Future<String?> _startMetadata(
    String label,
    String module,
    Future<String> Function() submit, {
    bool refreshCatalog = false,
  }) => _startJob('$label · 提交中…', () async {
    final message = await submit();
    return (() => _pollMetadata(label, module), message);
  }, refreshCatalog: refreshCatalog);

  Future<String?> _startJob(
    String stage,
    Future<(_JobPoll?, String?)> Function() submit, {
    bool refreshCatalog = true,
  }) async {
    if (taskRunning || _disposed) return '已有媒体库任务正在处理';
    _hideDone?.cancel();
    taskRunning = true;
    taskStage = stage;
    taskDetail = null;
    taskPercent = 0;
    _missingTicks = 0;
    notifyListeners();
    try {
      final (poll, message) = await submit();
      if (_disposed) return null;
      if (poll == null) {
        taskRunning = false;
        taskStage = '';
        notifyListeners();
      } else {
        unawaited(_tick(poll, refreshCatalog));
      }
      return message;
    } catch (_) {
      taskRunning = false;
      taskStage = '';
      notifyListeners();
      rethrow;
    }
  }

  Future<bool?> _pollScanAll(
    Set<int>? ids,
    int expectedCount,
    Map<int, LibraryScanProgress> pipelines,
  ) async {
    final records = await gateway.fetchScanProgress();
    pipelines.addAll({
      for (final record in records)
        if (record.module == 'pipeline:${record.libraryId}' &&
            record.libraryId != null &&
            (ids == null || ids.contains(record.libraryId)))
          record.libraryId!: record,
    });
    final legacy = records
        .where((p) => p.module == 'scan:ALL' && p.total > 0)
        .firstOrNull;
    final scoped = pipelines.length == (ids?.length ?? expectedCount)
        ? pipelines.values
        : ids == null && legacy != null
        ? [legacy]
        : const <LibraryScanProgress>[];
    if (scoped.isEmpty) return null;

    final total = scoped.fold(0, (sum, p) => sum + p.total);
    final done = scoped.fold(0, (sum, p) => sum + p.done);
    final failed = scoped.fold(
      0,
      (sum, p) =>
          sum +
          (p.failed > 0
              ? p.failed
              : p.stage == 'error'
              ? 1
              : 0),
    );
    final active = scoped.any((p) => p.running);
    taskPercent = total == 0 ? 0 : done / total * 100;
    taskStage = active
        ? '扫描中 · $done/$total'
        : failed > 0
        ? '扫描结束 · $failed 项失败'
        : '扫描完成';
    taskDetail = active
        ? scoped
              .where((p) => p.running)
              .map((p) => p.currentItem)
              .whereType<String>()
              .firstOrNull
        : scoped.map((p) => p.message).whereType<String>().firstOrNull;
    return !active;
  }

  Future<bool?> _pollScanOne(int id, String? name) async {
    final progress = await gateway.fetchPipelineProgress(id);
    if (progress.stage == 'idle') return null;
    final label = switch (progress.stage) {
      'error' => '扫描失败',
      'done' => '扫描完成',
      _ => _stageLabels[progress.stage] ?? '扫描中',
    };
    taskStage = name == null ? label : '「$name」$label';
    taskPercent = progress.percent;
    taskDetail = progress.message ?? progress.currentItem;
    return !progress.running &&
        (progress.stage == 'done' || progress.stage == 'error');
  }

  Future<bool?> _pollMetadata(String label, String module) async {
    final progress = await gateway.fetchTaskProgress(module);
    if (progress.stage == 'idle' || progress.stage == null) return null;
    final total = progress.total ?? 0;
    final completed = progress.completed ?? 0;
    final accounted = completed + progress.failed + progress.skipped;
    taskPercent = total > 0 ? accounted / total * 100 : (progress.percent ?? 0);
    if (progress.running) {
      taskStage = total > 0 ? '$label · $accounted/$total' : '$label · 处理中';
      taskDetail = progress.currentItem;
      return false;
    }
    if (progress.stage != 'done' && progress.stage != 'error') return null;
    taskStage = switch (progress.stage) {
      'error' => '$label失败',
      _ when progress.failed > 0 => '$label结束 · ${progress.failed} 项失败',
      _ => '$label完成',
    };
    taskDetail =
        progress.message ??
        '成功 $completed，失败 ${progress.failed}，跳过 ${progress.skipped}';
    return true;
  }

  Future<void> _tick(_JobPoll poll, bool refreshCatalog) async {
    if (_disposed) return;
    bool? done;
    try {
      done = await poll();
    } catch (_) {
      // A transient fetch failure is distinct from a server-side task failure.
    }
    if (_disposed) return;
    _missingTicks = done == null ? _missingTicks + 1 : 0;
    if (_missingTicks >= 15) {
      taskStage = '暂时无法确认任务状态';
      taskDetail = '任务可能还在后端运行。';
      _finishJob();
    } else if (done == true) {
      if (refreshCatalog) catalogRevision++;
      _finishJob();
    } else {
      _poll = Timer(
        const Duration(seconds: 1),
        () => unawaited(_tick(poll, refreshCatalog)),
      );
    }
    notifyListeners();
  }

  void _finishJob() {
    _poll?.cancel();
    _poll = null;
    taskRunning = false;
    _hideDone = Timer(const Duration(seconds: 8), () {
      taskStage = '';
      taskDetail = null;
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
