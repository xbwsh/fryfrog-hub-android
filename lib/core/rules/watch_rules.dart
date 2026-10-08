/// Pure reading / watch rules shared by player, detail, and reader.
/// No Flutter, no HTTP — unit-testable in isolation.
class WatchRules {
  const WatchRules._();

  /// Auto-mark watched at ≥ 95%.
  ///
  /// **必须与后端一致**：`fryfrog-hub-api` 的 `services/video_service.py`
  /// 定义 `COMPLETED_THRESHOLD = 0.95`，且 `update_position` 每次保存进度都会
  /// 用它重算 `completed`。客户端若用更低的阈值提前标已看，下一次进度保存
  /// （仍在 0.95 以下）会把刚写下的已看状态打回未看，而播放器的
  /// `_markedWatched` 已置位不再重标 —— 等于白标。
  static const double completedRatio = 0.95;

  static bool isCompleted(double positionSeconds, double durationSeconds) {
    if (durationSeconds <= 0) return false;
    return positionSeconds / durationSeconds >= completedRatio;
  }

  /// Should we persist a periodic progress sample?
  ///
  /// 双向判定：用户把进度条**往回拖**后，`position` 小于上次保存点，若只按
  /// 正向差值算会一直不满足 → 回退后到重新追平旧位置之前一次都不保存，
  /// 这期间杀进程就会跳回旧位置。取绝对值让后退同样触发保存。
  static bool shouldSave({
    required double positionSeconds,
    required double lastSavedSeconds,
    double minGapSeconds = 5,
  }) => (positionSeconds - lastSavedSeconds).abs() >= minGapSeconds;

  /// Episode to open first: partial progress → first unwatched → first.
  static T? pickResumeEpisode<T>(
    List<T> episodes, {
    required bool Function(T e) hasProgress,
    required bool Function(T e) isWatched,
  }) {
    if (episodes.isEmpty) return null;
    for (final e in episodes) {
      if (hasProgress(e) && !isWatched(e)) return e;
    }
    for (final e in episodes) {
      if (!isWatched(e)) return e;
    }
    return episodes.first;
  }

  /// Comic detail CTA label inputs.
  static String comicReadLabel({
    required int? chapterIndex,
    required int? pageIndex,
    required bool completed,
  }) {
    if (chapterIndex == null && pageIndex == null) return '开始阅读';
    if (completed) return '开始阅读';
    final chapter = (chapterIndex ?? 0) + 1;
    final page = (pageIndex ?? 0) + 1;
    return '继续阅读 · 第 $chapter 话 · 第 $page 页';
  }

  /// Clamp a resume page into `[0, pageCount-1]` (empty chapter → 0).
  static int clampPage(int pageIndex, int pageCount) {
    if (pageCount <= 0) return 0;
    if (pageIndex < 0) return 0;
    if (pageIndex > pageCount - 1) return pageCount - 1;
    return pageIndex;
  }
}
