import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fryfrog_hub/core/adaptive/device_form.dart';
import 'package:fryfrog_hub/core/models/media_models.dart';
import 'package:fryfrog_hub/core/network/api_client.dart';
import 'package:fryfrog_hub/core/network/server_connection.dart';
import 'package:fryfrog_hub/core/state/app_prefs.dart';
import 'package:fryfrog_hub/core/state/session.dart';
import 'package:fryfrog_hub/widgets/server_image.dart';
import 'package:fryfrog_hub/features/video/video_detail_screen.dart';
import 'package:fryfrog_hub/features/video/video_library_screen.dart';

/// C1 回归：详情页改完数据（绑 TMDB / 改元数据）后，
/// `LibraryPosterCard` 不能再 `Navigator.pop(true)` 把容器自己关掉——
/// 详情页此时**已经 pop 掉了**，顶上就是库页，等于"改一条数据库页被弹回首页"，
/// 而首页那个 push 又没人 await，`true` 直接丢，两边都不刷新。
/// 正确做法是卡片内部 `session.loadCatalog()` + 容器自己的 `onChanged`。

LibrarySeriesGroup _group(String title) => LibrarySeriesGroup(
  libraryId: 7,
  libraryName: '电影',
  series: [SeriesListDto(id: 1, type: 'series', title: title, mediaType: 'tv')],
  standaloneVideos: const [],
);

const SeriesDetail _detail = SeriesDetail(
  id: 1,
  type: 'series',
  title: '旧名',
  mediaType: 'tv',
  tmdbId: 999,
  seasons: [
    SeasonInfo(seasonNumber: 1, episodes: [VideoItem(id: 11, title: '第 1 集')]),
  ],
);

PageResponse<T> _emptyPage<T>(int page, int size) => PageResponse<T>(
  content: const [],
  page: page,
  size: size,
  totalElements: 0,
  totalPages: 0,
);

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super('http://test.local', token: 't');

  /// 卡片回调 `session.loadCatalog()` 的直接证据。
  int groupedCalls = 0;
  int logoCalls = 0;

  /// 首次返回旧名，重载后返回新名——模拟"改完元数据后的下一次目录"。
  bool refreshed = false;

  @override
  Future<List<LibrarySeriesGroup>> fetchGroupedSeries() async {
    groupedCalls++;
    return [_group(refreshed ? '新名' : '旧名')];
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

  @override
  Future<SeriesDetail> fetchSeriesDetail(int id, {String? type}) async =>
      _detail;

  @override
  Future<List<VideoActorDto>> fetchVideoActors(int id) async => const [];

  @override
  Future<bool> refreshSeriesLogo(int seriesId) async {
    logoCalls++;
    refreshed = true;
    return true;
  }

  @override
  Future<PageResponse<VideoItem>> fetchUnscrapedVideos({
    int page = 0,
    int size = 20,
    int? libraryId,
  }) async => _emptyPage(page, size);

  @override
  Future<StaleRecords> fetchStaleRecords(int libraryId) async =>
      const StaleRecords();
}

/// Session 子类：把 `@protected notifyListeners` 暴露给测试。
class _TestSession extends Session {
  _TestSession() : super(ServerConnection(), AppPrefs());

  void bump() => notifyListeners();
}

/// 进度圈是永动动画，`pumpAndSettle` 会超时；按固定步数泵即可。
Future<void> _pump(WidgetTester tester, {int steps = 40}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('详情页改完数据：库页留在原地，目录自动重载出新名字', (tester) async {
    final api = _FakeApiClient();
    final session = _TestSession()
      ..api = api
      ..user = const UserProfile(id: 1, username: 'admin', role: 'ADMIN');
    session.videoGroups.add(_group('旧名'));
    session.catalogVersion = 1;

    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      SessionScope(
        session: session,
        child: AdaptiveScope(
          form: DeviceForm.phone,
          child: MaterialApp(
            navigatorKey: navKey,
            home: const Scaffold(body: Center(child: Text('首页'))),
          ),
        ),
      ),
    );
    await _pump(tester, steps: 4);

    navKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            VideoLibraryScreen(session: session, group: session.videoGroups[0]),
      ),
    );
    await _pump(tester);
    expect(find.byType(VideoLibraryScreen), findsOneWidget);
    expect(find.text('旧名'), findsOneWidget);

    // 进详情页
    await tester.tap(find.text('旧名'));
    await _pump(tester);
    expect(find.byType(VideoDetailScreen), findsOneWidget);
    expect(api.logoCalls, 0);

    // 管理员菜单 → 补全 Logo（一个会置 mutated 的写操作）
    await tester.tap(find.byTooltip('管理'));
    await _pump(tester, steps: 20);
    await tester.tap(find.text('补全 Logo'));
    await _pump(tester, steps: 40);
    expect(api.logoCalls, 1);

    // 返回：详情页 pop(mutated == true)
    await tester.tap(
      find.descendant(
        of: find.byType(VideoDetailScreen),
        matching: find.byType(BackButton),
      ),
    );
    await _pump(tester);

    expect(find.byType(VideoDetailScreen), findsNothing);
    // 回归点 1：库页不能被卡片的 pop 一起关掉（否则首页会变成顶层、露出来）。
    expect(find.byType(VideoLibraryScreen), findsOneWidget);
    expect(find.text('首页'), findsNothing);
    // 回归点 2：卡片必须重载目录，否则新名字要杀进程才看得到。
    expect(api.groupedCalls, 1);
    expect(find.text('新名'), findsOneWidget);
    expect(find.text('旧名'), findsNothing);
    expect(find.text('电影'), findsOneWidget); // 库名/页头不变
  });

  testWidgets('外部重载目录后，库页按 libraryId 重新取组而非旧快照', (tester) async {
    final session = _TestSession();
    session.videoGroups.add(_group('旧名'));
    session.catalogVersion = 1;

    await tester.pumpWidget(
      SessionScope(
        session: session,
        child: AdaptiveScope(
          form: DeviceForm.phone,
          child: MaterialApp(
            home: VideoLibraryScreen(
              session: session,
              group: session.videoGroups[0],
            ),
          ),
        ),
      ),
    );
    await _pump(tester, steps: 4);
    expect(find.text('旧名'), findsOneWidget);

    // 模拟首页 loadCatalog 完成：videoGroups 被 clear()+addAll() 换成新对象。
    session.videoGroups
      ..clear()
      ..add(_group('新名'));
    session.catalogVersion++;
    session.bump();
    await tester.pump();

    expect(find.text('新名'), findsOneWidget);
    expect(find.text('旧名'), findsNothing);
    expect(find.text('电影'), findsOneWidget);
  });

  testWidgets('卸载后不再监听 session（不会对已销毁的 State 调 setState）', (tester) async {
    final session = _TestSession();
    session.videoGroups.add(_group('旧名'));

    await tester.pumpWidget(
      SessionScope(
        session: session,
        child: AdaptiveScope(
          form: DeviceForm.phone,
          child: MaterialApp(
            home: VideoLibraryScreen(
              session: session,
              group: session.videoGroups[0],
            ),
          ),
        ),
      ),
    );
    await _pump(tester, steps: 4);

    // 换掉整棵树 → dispose 应把 listener 摘掉。
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    session.videoGroups
      ..clear()
      ..add(_group('新名'));
    session.catalogVersion++;
    session.bump(); // 若 listener 还在，这里会炸（setState after dispose）
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
