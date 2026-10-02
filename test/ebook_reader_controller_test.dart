import 'package:flutter_test/flutter_test.dart';
import 'package:fryfrog_hub/core/models/media_models.dart';
import 'package:fryfrog_hub/core/network/gateways.dart';
import 'package:fryfrog_hub/features/books/ebook_reader_controller.dart';

class _FakeEbookGateway implements EbookGateway {
  _FakeEbookGateway({this.failContent = false});

  bool failContent;
  final List<({double positionPercent, int chapterIndex})> saves = [];

  @override
  Future<List<BookChapter>> fetchChapters(int bookId) async =>
      throw UnimplementedError();

  @override
  Future<EbookChapterContent> fetchChapterContent(
    int bookId, {
    required int chapterIndex,
  }) async {
    if (failContent) throw Exception('boom');
    return EbookChapterContent(
      index: chapterIndex,
      title: '第$chapterIndex章',
      text: 'body-$chapterIndex',
      chapterCount: 3,
    );
  }

  @override
  Future<void> saveProgress(
    int bookId, {
    required double positionPercent,
    required int chapterIndex,
  }) async {
    saves.add(
      (positionPercent: positionPercent, chapterIndex: chapterIndex),
    );
  }
}

List<BookChapter> _chapters(int n) => [
  for (var i = 0; i < n; i++)
    BookChapter(id: i, chapterIndex: i, title: '第${i + 1}章'),
];

EbookReaderController _controller(
  _FakeEbookGateway gateway, {
  int count = 3,
  int initial = 0,
}) => EbookReaderController(
  gateway: gateway,
  bookId: 7,
  chapters: _chapters(count),
  initialChapterIndex: initial,
);

void main() {
  test('load fetches initial chapter content', () async {
    final gateway = _FakeEbookGateway();
    final c = _controller(gateway, initial: 1);
    expect(c.chapterPos, 1);
    await c.load();
    expect(c.loading, false);
    expect(c.error, isNull);
    expect(c.content, 'body-1');
    c.dispose();
  });

  test('goToChapter moves position and reloads', () async {
    final gateway = _FakeEbookGateway();
    final c = _controller(gateway, count: 3);
    await c.load();
    await c.goToChapter(2);
    expect(c.chapterPos, 2);
    expect(c.content, 'body-2');
    expect(c.hasPrevChapter, true);
    expect(c.hasNextChapter, false);
    c.dispose();
  });

  test('goToChapter rejects out-of-range positions', () async {
    final gateway = _FakeEbookGateway();
    final c = _controller(gateway, count: 2);
    await c.load();
    await c.goToChapter(5);
    expect(c.chapterPos, 0);
    c.dispose();
  });

  test('positionPercent combines chapter index and scroll fraction', () async {
    final gateway = _FakeEbookGateway();
    final c = _controller(gateway, count: 4);
    await c.load();
    c.onScrollFraction(0.5);
    // (0 + 0.5) / 4 * 100 = 12.5
    expect(c.positionPercent, closeTo(12.5, 0.001));
    await c.goToChapter(3);
    c.onScrollFraction(1.0);
    // (3 + 1.0) / 4 * 100 = 100
    expect(c.positionPercent, closeTo(100, 0.001));
    c.dispose();
  });

  test('flushProgress persists percent and chapter', () async {
    final gateway = _FakeEbookGateway();
    final c = _controller(gateway, count: 2);
    await c.load();
    c.onScrollFraction(1.0);
    await c.flushProgress();
    expect(gateway.saves, isNotEmpty);
    final last = gateway.saves.last;
    expect(last.chapterIndex, 0);
    expect(last.positionPercent, closeTo(50, 0.001));
    // Not dirty → no duplicate save.
    await c.flushProgress();
    expect(gateway.saves.length, 1);
    c.dispose();
  });

  test('load failure surfaces error and stops loading', () async {
    final gateway = _FakeEbookGateway(failContent: true);
    final c = _controller(gateway);
    await c.load();
    expect(c.loading, false);
    expect(c.error, isNotNull);
    expect(c.content, isEmpty);
    c.dispose();
  });
}
