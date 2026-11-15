import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fryfrog_hub/core/adaptive/device_form.dart';
import 'package:fryfrog_hub/core/models/media_models.dart';
import 'package:fryfrog_hub/core/network/api_client.dart';
import 'package:fryfrog_hub/core/network/server_connection.dart';
import 'package:fryfrog_hub/core/state/app_prefs.dart';
import 'package:fryfrog_hub/core/state/session.dart';
import 'package:fryfrog_hub/features/video/unscraped_screen.dart';

class _BacklogApi extends ApiClient {
  _BacklogApi() : super('http://test.local');

  final requests = <(int, int?, String)>[];
  final pendingPage = Completer<PageResponse<VideoItem>>();
  bool delayPaging = false;

  @override
  Future<PageResponse<VideoItem>> fetchUnscrapedVideos({
    int page = 0,
    int size = 20,
    int? libraryId,
    String query = '',
  }) async {
    requests.add((page, libraryId, query));
    if (delayPaging && page == 1) return pendingPage.future;
    return PageResponse(
      content: query.isEmpty
          ? [
              for (var id = 1; id <= 6; id++)
                VideoItem(
                  id: id,
                  title: '待处理视频 $id',
                  fileName: 'video-$id.mp4',
                ),
            ]
          : const [
              VideoItem(
                id: 90,
                title: '匹配的剧集',
                fileName: 'example-source.mkv',
                seasonNumber: 1,
                episodeNumber: 2,
                isSeries: true,
              ),
            ],
      page: page,
      size: size,
      totalElements: query.isNotEmpty ? 1 : (delayPaging ? 7 : 6),
      totalPages: delayPaging && query.isEmpty ? 2 : 1,
    );
  }
}

Future<void> _open(
  WidgetTester tester,
  DeviceForm form,
  Size size,
  _BacklogApi api,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(bottom: 24);
  addTearDown(tester.view.reset);
  final prefs = AppPrefs();
  final session = Session(ServerConnection(), prefs)..api = api;
  addTearDown(prefs.dispose);
  addTearDown(session.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: AdaptiveScope(
        form: form,
        child: UnscrapedScreen(
          session: session,
          libraryId: 7,
          libraryName: '示例视频库',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (form, size, columns) in [
    (DeviceForm.phone, const Size(390, 844), 1),
    (DeviceForm.tabletPortrait, const Size(716, 1140), 2),
    (DeviceForm.tabletLandscape, const Size(1140, 716), 3),
  ]) {
    testWidgets(
      '${form.name} uses $columns columns and respects bottom inset',
      (tester) async {
        await _open(tester, form, size, _BacklogApi());
        final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
        final delegate =
            grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, columns);
        expect(find.text('video-1.mp4'), findsOneWidget);
        expect(find.textContaining('待处理 6 项'), findsOneWidget);
        expect(find.byType(ChoiceChip), findsNothing);
        expect(
          tester.getBottomLeft(find.byType(CustomScrollView)).dy,
          size.height - 24,
        );
      },
    );
  }

  testWidgets('late next page cannot enter new search results', (tester) async {
    final api = _BacklogApi()..delayPaging = true;
    await _open(tester, DeviceForm.tabletLandscape, const Size(1140, 716), api);
    await tester.tap(find.text('加载更多'));
    await tester.pump();
    expect(api.requests.last.$1, 1);

    await tester.enterText(find.byType(TextField), 'example-source');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(api.requests.last, (0, 7, 'example-source'));
    expect(find.text('匹配的剧集'), findsOneWidget);

    api.pendingPage.complete(
      PageResponse(
        content: const [VideoItem(id: 99, title: '旧列表的下一页')],
        page: 1,
        size: 20,
        totalElements: 7,
        totalPages: 2,
      ),
    );
    await tester.pump();
    expect(find.text('旧列表的下一页'), findsNothing);
    expect(find.textContaining('匹配 1 项'), findsOneWidget);
  });
}
