/// Pure reading / watch rules shared by player, detail, and reader.
/// No Flutter, no HTTP — unit-testable in isolation.
class WatchRules {
  const WatchRules._();

  /// Auto-mark watched at ≥ 90% (matches backend auto-complete intent).
  static const double completedRatio = 0.9;

  static bool isCompleted(double positionSeconds, double durationSeconds) {
    if (durationSeconds <= 0) return false;
    return positionSeconds / durationSeconds >= completedRatio;
  }

  /// Should we persist a periodic progress sample?
  static bool shouldSave({
    required double positionSeconds,
    required double lastSavedSeconds,
    double minGapSeconds = 5,
  }) => positionSeconds - lastSavedSeconds >= minGapSeconds;

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
