import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fryfrog_hub/core/models/media_models.dart';
import 'package:fryfrog_hub/core/network/gateways.dart';
import 'package:fryfrog_hub/features/profile/media_library_controller.dart';

class _FakeGateway implements MediaLibraryGateway {
  _FakeGateway(this.libs, {this.scanAllCount = 1});

  List<MediaLibrary> libs;
  int scanAllCount;
  List<int>? scanIds;
  Future<void> Function()? onScanOne;
  List<LibraryScanProgress> scanProgress = const [];
  LibraryPipelineProgress pipeline = const LibraryPipelineProgress(
    running: false,
    stage: 'done',
    percent: 100,
  );
  ScrapeProgress metadataProgress = const ScrapeProgress(stage: 'idle');
  final taskModules = <String>[];

  @override
  Future<List<MediaLibrary>> fetchLibraries() async => libs;

  @override
  Future<MediaLibrary> createLibrary({
    required String name,
    required String path,
    String? subType,
    required bool enabled,
    bool enableScraping = true,
    bool isAdult = false,
    String? description,
  }) async {
    final created = MediaLibrary(
      id: 99,
      name: name,
      path: path,
      type: 'VIDEO',
      subType: subType,
      enabled: enabled,
      enableScraping: enableScraping,
      isAdult: isAdult,
      sortOrder: libs.length,
      description: description,
    );
    libs = [...libs, created];
    return created;
  }

  @override
  Future<MediaLibrary> updateLibrary(
    int id, {
    String? name,
    String? path,
    String? subType,
    bool? enabled,
    bool? enableScraping,
    bool? isAdult,
    String? description,
  }) async {
    final lib = libs.firstWhere((l) => l.id == id);
    final updated = MediaLibrary(
      id: lib.id,
      name: name ?? lib.name,
      path: path ?? lib.path,
      type: lib.type,
      subType: subType ?? lib.subType,
      enabled: enabled ?? lib.enabled,
      enableScraping: enableScraping ?? lib.enableScraping,
      isAdult: isAdult ?? lib.isAdult,
      sortOrder: lib.sortOrder,
      description: description ?? lib.description,
    );
    libs = [for (final l in libs) l.id == id ? updated : l];
    return updated;
  }

  @override
  Future<void> deleteLibrary(int id) async {
    libs = libs.where((l) => l.id != id).toList();
  }

  @override
  Future<MediaLibrary> toggleLibrary(int id) async {
    final lib = libs.firstWhere((l) => l.id == id);
    final updated = MediaLibrary(
      id: lib.id,
      name: lib.name,
      path: lib.path,
      type: lib.type,
      subType: lib.subType,
      enabled: !lib.enabled,
      enableScraping: lib.enableScraping,
      isAdult: lib.isAdult,
      sortOrder: lib.sortOrder,
      description: lib.description,
    );
    libs = [for (final l in libs) l.id == id ? updated : l];
    return updated;
  }

  @override
  Future<LibraryScanSubmission> scanAll() async =>
      LibraryScanSubmission(count: scanAllCount, libraryIds: scanIds);

  @override
  Future<void> scanOne(int id) async => await onScanOne?.call();

  @override
  Future<List<LibraryScanProgress>> fetchScanProgress() async => scanProgress;

  @override
  Future<LibraryPipelineProgress> fetchPipelineProgress(int id) async =>
      pipeline;

  @override
  Future<ScrapeProgress> fetchTaskProgress(String module) async {
    taskModules.add(module);
    return metadataProgress;
  }

  @override
  Future<StaleRecords> fetchStaleRecords(int libraryId) async =>
      const StaleRecords();

  @override
  Future<int> purgeStaleRecords(int libraryId, {bool dryRun = false}) async =>
      0;

  @override
  Future<String> regenerateNfo({int? libraryId}) async => '已启动';

  @override
  Future<String> refreshLibraryMetadata(int libraryId) async => '已启动';

  @override
  Future<List<LibraryDirItem>> browse({String? path}) async => const [];
}

MediaLibrary _lib(int id, String name, {int? order, bool enabled = true}) =>
    MediaLibrary(
      id: id,
      name: name,
      path: '/media/$name',
      type: 'VIDEO',
      subType: 'MIXED',
      enabled: enabled,
      sortOrder: order,
    );

void main() {
  test('load sorts libraries by sortOrder', () async {
    final gateway = _FakeGateway([
      _lib(1, 'b', order: 2),
      _lib(2, 'a', order: 1),
    ]);
    final c = MediaLibraryController(gateway: gateway);

    await c.load();

    expect(c.libraries.map((l) => l.name), ['a', 'b']);
    expect(c.error, isNull);
  });

  test('save create appends, update replaces in place', () async {
    final gateway = _FakeGateway([_lib(1, 'old')]);
    final c = MediaLibraryController(gateway: gateway);
    await c.load();

    await c.save(
      name: 'new',
      path: '/media/new',
      subType: 'MOVIE',
      enabled: true,
      description: null,
    );
    expect(c.libraries.map((l) => l.name), ['old', 'new']);

    await c.save(
      edit: c.libraries.first,
      name: 'renamed',
      path: '/media/old',
      subType: 'TV',
      enabled: true,
      description: null,
    );
    expect(c.libraries.first.name, 'renamed');
    expect(c.libraries.first.subType, 'TV');
  });

  test('save passes scraping and adult flags through', () async {
    final gateway = _FakeGateway([_lib(1, 'a')]);
    final c = MediaLibraryController(gateway: gateway);
    await c.load();

    await c.save(
      name: '成人库',
      path: '/media/adult',
      subType: 'MIXED',
      enabled: true,
      enableScraping: false,
      isAdult: true,
      description: null,
    );
    final created = c.libraries.last;
    expect(created.enableScraping, isFalse);
    expect(created.isAdult, isTrue);

    await c.save(
      edit: created,
      name: '成人库',
      path: '/media/adult',
      subType: 'MIXED',
      enabled: true,
      enableScraping: true,
      isAdult: false,
      description: null,
    );
    expect(c.libraries.last.enableScraping, isTrue);
    expect(c.libraries.last.isAdult, isFalse);
  });

  test('toggle flips enabled, remove drops the entry', () async {
    final gateway = _FakeGateway([_lib(1, 'a'), _lib(2, 'b')]);
    final c = MediaLibraryController(gateway: gateway);
    await c.load();

    await c.toggle(c.libraries.first);
    expect(c.libraries.first.enabled, isFalse);

    await c.remove(2);
    expect(c.libraries.map((l) => l.id), [1]);
  });

  test('startScanAll reports when nothing is enabled', () async {
    final gateway = _FakeGateway(const [], scanAllCount: 0);
    final c = MediaLibraryController(gateway: gateway);

    final msg = await c.startScanAll();

    expect(msg, '没有启用的资源库');
    expect(c.taskRunning, isFalse);
  });
  testWidgets('scan submission is guarded and a failed scan shows its reason', (
    tester,
  ) async {
    final pending = Completer<void>();
    var submissions = 0;
    final gateway = _FakeGateway([_lib(1, 'anime')])
      ..onScanOne = (() {
        submissions++;
        return pending.future;
      })
      ..pipeline = const LibraryPipelineProgress(
        running: false,
        stage: 'error',
        percent: 25,
        message: '路径不可访问',
      );
    final c = MediaLibraryController(gateway: gateway);
    final first = c.startScanOne(1);
    expect(c.taskRunning, isTrue);
    expect(await c.startScanOne(1), isNotNull);
    expect(submissions, 1);
    pending.complete();
    await first;
    await tester.pump();
    expect(c.taskRunning, isFalse);
    expect(c.taskStage, '扫描失败');
    expect(c.taskDetail, '路径不可访问');
    expect(c.taskPercent, 25);
    c.dispose();
  });

  testWidgets(
    'scan all ignores unrelated jobs and waits for requested libraries',
    (tester) async {
      const unrelated = LibraryScanProgress(
        module: 'rescrape:2',
        libraryId: 2,
        running: true,
        total: 500,
        completed: 0,
        failed: 0,
        skipped: 0,
      );
      const first = LibraryScanProgress(
        module: 'pipeline:1',
        libraryId: 1,
        stage: 'done',
        running: false,
        total: 1,
        completed: 1,
        failed: 0,
        skipped: 0,
      );
      final gateway =
          _FakeGateway([_lib(1, 'a'), _lib(2, 'b')], scanAllCount: 2)
            ..scanIds = [1, 2]
            ..scanProgress = [unrelated, first];
      final c = MediaLibraryController(gateway: gateway);
      await c.startScanAll();
      await tester.pump();
      expect(c.taskRunning, isTrue);
      gateway.scanProgress = [
        unrelated,
        first,
        const LibraryScanProgress(
          module: 'pipeline:2',
          libraryId: 2,
          stage: 'error',
          running: false,
          total: 1,
          completed: 0,
          failed: 1,
          skipped: 0,
          message: '路径不可访问',
        ),
      ];
      await tester.pump(const Duration(seconds: 1));
      expect(c.taskRunning, isFalse);
      expect(c.taskStage, '扫描结束 · 1 项失败');
      expect(c.taskDetail, '路径不可访问');
      c.dispose();
    },
  );

  testWidgets('NFO tracks its own module and reports partial failure', (
    tester,
  ) async {
    final gateway = _FakeGateway([_lib(2, 'b')])
      ..metadataProgress = const ScrapeProgress(
        stage: 'nfo',
        running: true,
        total: 3,
      );
    final c = MediaLibraryController(gateway: gateway);
    await c.regenerateNfo(libraryId: 2);
    await tester.pump();
    expect(c.taskRunning, isTrue);
    gateway.metadataProgress = const ScrapeProgress(
      stage: 'done',
      completed: 2,
      total: 3,
      failed: 1,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(gateway.taskModules, ['nfo:2', 'nfo:2']);
    expect(c.taskRunning, isFalse);
    expect(c.taskStage, '重写 NFO结束 · 1 项失败');
    expect(c.taskDetail, '成功 2，失败 1，跳过 0');
    c.dispose();
  });
}
