import 'package:flutter_test/flutter_test.dart';
import 'package:fryfrog_hub/core/rules/watch_rules.dart';

class _Ep {
  _Ep(this.id, {this.progress = 0, this.watched = false});
  final int id;
  final double progress;
  final bool watched;
  bool get hasProgress => progress > 0;
}

void main() {
  group('WatchRules.isCompleted', () {
    test('true at >= 95%（对齐后端 COMPLETED_THRESHOLD）', () {
      expect(WatchRules.isCompleted(95, 100), isTrue);
      expect(WatchRules.isCompleted(100, 100), isTrue);
      expect(WatchRules.isCompleted(94.9, 100), isFalse);
    });

    test('false when duration unknown', () {
      expect(WatchRules.isCompleted(10, 0), isFalse);
      expect(WatchRules.isCompleted(10, -1), isFalse);
    });

    // 回归：客户端阈值曾是 0.9，而每次 saveWatchProgress 都会让后端用 0.95
    // 重算 completed → 90%~95% 之间标的已看会在下一次保存时被打回未看。
    test('阈值必须与后端 services/video_service.py 的 0.95 一致', () {
      expect(WatchRules.completedRatio, 0.95);
      // 0.9 必须不再算完成，否则自动标已看会被后端撤销。
      expect(WatchRules.isCompleted(90, 100), isFalse);
      expect(WatchRules.isCompleted(94, 100), isFalse);
    });
  });

  group('WatchRules.shouldSave', () {
    test('gaps by 5s', () {
      expect(
        WatchRules.shouldSave(positionSeconds: 6, lastSavedSeconds: 0),
        isTrue,
      );
      expect(
        WatchRules.shouldSave(positionSeconds: 4, lastSavedSeconds: 0),
        isFalse,
      );
    });

    // 回退后 position < lastSaved，正向阈值会一直不满足 → 回看期间
    // 一次都不保存，杀进程就跳回旧位置。
    test('backward seek also triggers a save', () {
      expect(
        WatchRules.shouldSave(positionSeconds: 40, lastSavedSeconds: 100),
        isTrue,
      );
      expect(
        WatchRules.shouldSave(positionSeconds: 98, lastSavedSeconds: 100),
        isFalse,
      );
    });
  });

  group('WatchRules.pickResumeEpisode', () {
    test('prefers partial progress unwatched', () {
      final eps = [_Ep(1, watched: true), _Ep(2, progress: 40), _Ep(3)];
      expect(
        WatchRules.pickResumeEpisode(
          eps,
          hasProgress: (e) => e.hasProgress,
          isWatched: (e) => e.watched,
        )!.id,
        2,
      );
    });

    test('else first unwatched', () {
      final eps = [_Ep(1, watched: true), _Ep(2), _Ep(3, watched: true)];
      expect(
        WatchRules.pickResumeEpisode(
          eps,
          hasProgress: (e) => e.hasProgress,
          isWatched: (e) => e.watched,
        )!.id,
        2,
      );
    });

    test('else first', () {
      final eps = [_Ep(1, watched: true), _Ep(2, watched: true)];
      expect(
        WatchRules.pickResumeEpisode(
          eps,
          hasProgress: (e) => e.hasProgress,
          isWatched: (e) => e.watched,
        )!.id,
        1,
      );
    });

    test('empty → null', () {
      expect(
        WatchRules.pickResumeEpisode<_Ep>(
          const [],
          hasProgress: (e) => e.hasProgress,
          isWatched: (e) => e.watched,
        ),
        isNull,
      );
    });
  });

  group('WatchRules.comicReadLabel', () {
    test('start when no position', () {
      expect(
        WatchRules.comicReadLabel(
          chapterIndex: null,
          pageIndex: null,
          completed: false,
        ),
        '开始阅读',
      );
    });

    test('resume with chapter/page', () {
      expect(
        WatchRules.comicReadLabel(
          chapterIndex: 0,
          pageIndex: 4,
          completed: false,
        ),
        '继续阅读 · 第 1 话 · 第 5 页',
      );
    });

    test('completed restarts', () {
      expect(
        WatchRules.comicReadLabel(
          chapterIndex: 3,
          pageIndex: 9,
          completed: true,
        ),
        '开始阅读',
      );
    });
  });

  group('WatchRules.clampPage', () {
    test('bounds', () {
      expect(WatchRules.clampPage(-1, 10), 0);
      expect(WatchRules.clampPage(0, 10), 0);
      expect(WatchRules.clampPage(9, 10), 9);
      expect(WatchRules.clampPage(10, 10), 9);
      expect(WatchRules.clampPage(5, 0), 0);
    });
  });
}
