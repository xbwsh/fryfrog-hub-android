import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fryfrog_hub/core/adaptive/device_form.dart';
import 'package:fryfrog_hub/core/models/media_models.dart';
import 'package:fryfrog_hub/core/network/api_client.dart';
import 'package:fryfrog_hub/core/network/server_connection.dart';
import 'package:fryfrog_hub/core/state/app_prefs.dart';
import 'package:fryfrog_hub/core/state/session.dart';
import 'package:fryfrog_hub/features/profile/media_library_screen.dart';

/// 回归：媒体库管理页里开关/删除/编辑库之后，首页目录缓存必须重载——
/// 分组目录是服务端按 `enabled` 过滤的，客户端不重拉的话，关掉的 TV 剧库
/// 会一直在视频页显示到杀进程。

PageResponse<T> _emptyPage<T>(int page, int size) => PageResponse<T>(
  content: const [],
  page: page,
  size: size,
  totalElements: 0,
  totalPages: 0,
);

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super('http://test.local', token: 't');

  /// `session.loadCatalog()` 的直接证据。
  int groupedCalls = 0;

  List<MediaLibrary> libs = [
    MediaLibrary(
      id: 1,
      name: '电影',
      path: '/media/movie',
      type: 'VIDEO',
      subType: 'MOVIE',
      enabled: true,
      sortOrder: 0,
    ),
    MediaLibrary(
      id: 2,
      name: 'TV剧',
      path: '/media/tv',
      type: 'VIDEO',
      subType: 'TV',
      enabled: true,
      sortOrder: 1,
    ),
  ];

  @override
  Future<List<MediaLibrary>> fetchMediaLibraries() async => libs;

  @override
  Future<MediaLibrary> toggleMediaLibrary(int id) async {
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
  Future<void> deleteMediaLibrary(int id) async {
    libs = libs.where((l) => l.id != id).toList();
  }

  /// 服务端口径：只返回 enabled 的库。
  @override
  Future<List<LibrarySeriesGroup>> fetchGroupedSeries() async {
    groupedCalls++;
    return [
      for (final l in libs.where((l) => l.enabled))
        LibrarySeriesGroup(
          libraryId: l.id,
          libraryName: l.name,
          series: const [],
          standaloneVideos: const [],
        ),
    ];
  }

  @override
  Future<List<MusicLibraryGroup>> fetchMusicHome() async => const [];

  @override
  Future<PageResponse<MusicSong>> fetchMusicSongs({
    int page = 0,
    int size = 50,
  }) async => _emptyPage(page, size);

  @override
  Future<PageResponse<BookItem>> fetchBooks(
    BookShelfKind kind, {
    String? q,
    int page = 0,
    int size = 50,
  }) async => _emptyPage(page, size);
}

class _TestSession extends Session {
  _TestSession() : super(ServerConnection(), AppPrefs());
}

/// loadCatalog 内部有多个 await；按固定步数泵，避免被永动动画卡住。
Future<void> _pump(WidgetTester tester, {int steps = 40}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _openScreen(WidgetTester tester, _TestSession session) async {
  await tester.pumpWidget(
    AdaptiveScope(
      form: DeviceForm.phone,
      child: MaterialApp(home: MediaLibraryScreen(session: session)),
    ),
  );
  await _pump(tester, steps: 6);
}

void main() {
  testWidgets('关闭媒体库后首页目录重载，视频页不再有该库', (tester) async {
    final api = _FakeApiClient();
    final session = _TestSession()..api = api;
    session.videoGroups
      ..add(
        LibrarySeriesGroup(
          libraryId: 1,
          libraryName: '电影',
          series: const [],
          standaloneVideos: const [],
        ),
      )
      ..add(
        LibrarySeriesGroup(
          libraryId: 2,
          libraryName: 'TV剧',
          series: const [],
          standaloneVideos: const [],
        ),
      );
    session.catalogVersion = 1;

    await _openScreen(tester, session);
    expect(find.text('TV剧'), findsOneWidget);
    expect(api.groupedCalls, 0, reason: '仅打开管理页不应重载目录');

    // 关掉 TV 剧库
    final tile = find.ancestor(
      of: find.text('TV剧'),
      matching: find.byType(ListTile),
    );
    await tester.tap(find.descendant(of: tile, matching: find.byType(Switch)));
    await _pump(tester);

    expect(api.groupedCalls, 1, reason: '开关变化必须触发 session.loadCatalog()');
    expect(
      session.videoGroups.map((g) => g.libraryName),
      ['电影'],
      reason: '重载后的目录里关掉的库要消失（视频页直接消费这份缓存）',
    );
    expect(session.catalogVersion, 2);
  });

  testWidgets('打开管理页本身不重载目录（首屏 load 的空列表不算变化）', (
    tester,
  ) async {
    final api = _FakeApiClient();
    final session = _TestSession()..api = api;
    session.catalogVersion = 1;

    await _openScreen(tester, session);

    expect(find.text('电影'), findsOneWidget);
    expect(find.text('TV剧'), findsOneWidget);
    expect(api.groupedCalls, 0);
  });

  testWidgets('重新打开开关：目录同样重载回来', (tester) async {
    final api = _FakeApiClient();
    final session = _TestSession()..api = api;
    session.videoGroups
      ..add(
        LibrarySeriesGroup(
          libraryId: 1,
          libraryName: '电影',
          series: const [],
          standaloneVideos: const [],
        ),
      )
      ..add(
        LibrarySeriesGroup(
          libraryId: 2,
          libraryName: 'TV剧',
          series: const [],
          standaloneVideos: const [],
        ),
      );
    session.catalogVersion = 1;

    await _openScreen(tester, session);

    final tile = find.ancestor(
      of: find.text('TV剧'),
      matching: find.byType(ListTile),
    );
    final sw = find.descendant(of: tile, matching: find.byType(Switch));

    await tester.tap(sw);
    await _pump(tester);
    expect(api.groupedCalls, 1);
    expect(session.videoGroups.map((g) => g.libraryName), ['电影']);

    await tester.tap(sw);
    await _pump(tester);
    expect(api.groupedCalls, 2);
    expect(session.videoGroups.map((g) => g.libraryName), ['电影', 'TV剧']);
  });
}
