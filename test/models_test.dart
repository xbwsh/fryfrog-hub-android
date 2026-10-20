import 'package:flutter_test/flutter_test.dart';
import 'package:fryfrog_hub/core/models/media_models.dart';

void main() {
  test('有声书刮削结果保留来源、原始 ID 和演播者', () {
    final result = ScrapeResult.fromJson({
      'source': 'ximalaya',
      'sourceId': '123',
      'title': '三体',
      'author': '作者甲',
      'narrator': '演员乙',
      'year': 2020,
    });
    expect(result.source, 'ximalaya');
    expect(result.sourceId, '123');
    expect(result.narrator, '演员乙');
    expect(result.pubYear, 2020);
  });

  test('刮削状态兼容旧标记和带来源的新标记', () {
    for (final source in ['scrape', 'scrape:ximalaya', 'scrape:bangumi']) {
      final detail = BookDetail.fromJson({
        'id': 1,
        'title': '三体',
        'metadataSource': source,
      });
      expect(detail.metadataSourceText, '已刮削');
    }
    expect(
      const BookDetail(
        id: 1,
        title: '三体',
        metadataSource: 'manual',
      ).metadataSourceText,
      '手动',
    );
    expect(const BookDetail(id: 1, title: '三体').metadataSourceText, '扫描');
  });

  group('VideoItem.fromJson', () {
    test('parses progress and episode label', () {
      final v = VideoItem.fromJson({
        'id': 7,
        'title': 'Ep 1',
        'seasonNumber': 1,
        'episodeNumber': 3,
        'watchPosition': 120.0,
        'watchProgressPercent': 42.5,
        'watched': false,
        'coverUrl': 'http://x/cover.jpg',
        'resolutionLabel': '1080p',
      });
      expect(v.id, 7);
      expect(v.episodeLabel, 'S01E03');
      expect(v.hasProgress, isTrue);
      expect(v.isWatched, isFalse);
      expect(v.coverUrl, 'http://x/cover.jpg');
      expect(v.resolutionLabel, '1080p');
    });
  });

  group('SeriesDetail.fromJson', () {
    test('flattens seasons and standalone flag', () {
      final d = SeriesDetail.fromJson({
        'id': 1,
        'type': 'series',
        'title': 'Show',
        'totalEpisodes': 2,
        'seasons': [
          {
            'seasonNumber': 1,
            'episodes': [
              {'id': 10, 'title': 'A'},
              {'id': 11, 'title': 'B'},
            ],
          },
        ],
      });
      expect(d.isStandalone, isFalse);
      expect(d.allEpisodes, hasLength(2));
      expect(d.firstEpisode!.id, 10);
      expect(d.displayTitle, 'Show');
    });
  });

  group('BookChapter', () {
    test('label falls back to index', () {
      const named = BookChapter(id: 1, chapterIndex: 0, title: '序章');
      const bare = BookChapter(id: 2, chapterIndex: 4);
      expect(named.label, '序章');
      expect(bare.label, '第 5 话');
    });

    test('fromJson defaults index 0', () {
      final c = BookChapter.fromJson({'id': 9});
      expect(c.id, 9);
      expect(c.chapterIndex, 0);
    });
  });

  group('ReadingProgress', () {
    test('fromJson + hasPosition', () {
      final p = ReadingProgress.fromJson({
        'chapterIndex': 2,
        'pageIndex': 5,
        'completed': true,
        'progressPercent': 33.0,
      });
      expect(p.hasPosition, isTrue);
      expect(p.completed, isTrue);
      expect(p.chapterIndex, 2);
    });
  });

  group('BookShelfKind', () {
    test('paths and aspect', () {
      expect(BookShelfKind.comic.coverPath(3), '/api/v1/comics/3/cover');
      expect(BookShelfKind.ebook.detailPath(1), '/api/v1/ebooks/1');
      expect(BookShelfKind.comic.coverAspect, closeTo(5 / 7, 1e-9));
    });
  });
}
