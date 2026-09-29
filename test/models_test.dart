import 'package:flutter_test/flutter_test.dart';
import 'package:fryfrog_hub/core/models/media_models.dart';

void main() {
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
