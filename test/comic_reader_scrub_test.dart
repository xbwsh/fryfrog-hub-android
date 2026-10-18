import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fryfrog_hub/core/models/media_models.dart';
import 'package:fryfrog_hub/core/network/api_client.dart';
import 'package:fryfrog_hub/core/network/server_connection.dart';
import 'package:fryfrog_hub/core/state/app_prefs.dart';
import 'package:fryfrog_hub/core/state/session.dart';
import 'package:fryfrog_hub/features/books/comic_reader_screen.dart';

class _ComicApi extends ApiClient {
  _ComicApi() : super('http://test.local');

  @override
  Future<List<String>> fetchComicChapterPages(int chapterId) async =>
      List.generate(80, (i) => 'http://test.local/pages/$i');

  @override
  Future<ReadingProgress?> saveComicProgress(
    int comicId, {
    int? chapterIndex,
    int? pageIndex,
  }) async => null;
}

void main() {
  testWidgets('scrubbing previews locally and commits only the final page', (
    tester,
  ) async {
    final session = Session(ServerConnection(), AppPrefs())..api = _ComicApi();
    await tester.pumpWidget(
      MaterialApp(
        home: ComicReaderScreen(
          session: session,
          comicId: 1,
          title: '漫画',
          chapters: const [BookChapter(id: 1, chapterIndex: 0)],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    Set<String> visibleUrls() => tester
        .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
        .map((image) => image.imageUrl)
        .toSet();
    final initial = visibleUrls();
    for (final page in [20.0, 60.0, 10.0, 79.0]) {
      tester.widget<Slider>(find.byType(Slider)).onChanged!(page);
      await tester.pump();
      expect(visibleUrls(), initial);
      expect(tester.widget<Slider>(find.byType(Slider)).value, page);
    }
    tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(79);
    await tester.pump();
    await tester.pump();
    expect(visibleUrls(), contains('http://test.local/pages/79'));
    expect(tester.widget<Slider>(find.byType(Slider)).value, 79);

    // Jump backwards across pages that have not been laid out.
    tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(12);
    await tester.pump();
    await tester.pump();
    expect(visibleUrls(), contains('http://test.local/pages/12'));
    expect(
      tester
          .getTopLeft(
            find.byWidgetPredicate(
              (widget) =>
                  widget is CachedNetworkImage &&
                  widget.imageUrl.endsWith('/12'),
            ),
          )
          .dy,
      kToolbarHeight,
    );
    expect(tester.widget<Slider>(find.byType(Slider)).value, 12);
    await tester.tap(find.byTooltip('切换为翻页'));
    await tester.pump();
    await tester.pump();
    final beforeDrag = visibleUrls();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Slider)),
    );
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(visibleUrls(), beforeDrag);
    await gesture.up();
    await tester.pump();
    await tester.pump();
    final selected = tester.widget<Slider>(find.byType(Slider)).value.round();
    expect(visibleUrls(), contains('http://test.local/pages/$selected'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    session.dispose();
  });
}
