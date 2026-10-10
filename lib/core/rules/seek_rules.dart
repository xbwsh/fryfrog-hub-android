/// 拖动手势的纯规则（可单测）：先定轴，再算快进预览位置。
///
/// 抽出来是因为播放器 State 无法在测试里跑（media_kit 要原生 mpv），
/// 而轴判定/预览 clamp 是"横滑不会误触发亮度音量"这件事的全部依据。
class SeekRules {
  const SeekRules._();

  /// 位移攒够 slop 之前不许动手：进度、亮度、音量都还没开始改。
  static bool readyToDecide(double dx, double dy, {double slop = 8}) =>
      dx.abs() + dy.abs() >= slop;

  /// 横向位移更大 → 快进快退；否则走纵向的亮度/音量。
  static bool isHorizontal(double dx, double dy) => dx.abs() >= dy.abs();

  /// 横滑整个屏宽 ≈ 走完整集时长；结果 clamp 在 `[0, duration]`。
  ///
  /// 时长还没拿到（`duration` 为 0）或屏宽非法时退回起点，不产生跳转。
  static Duration preview({
    required Duration start,
    required Duration duration,
    required double deltaPx,
    required double width,
  }) {
    if (duration <= Duration.zero || width <= 0) return start;
    final ms =
        start.inMilliseconds + duration.inMilliseconds * (deltaPx / width);
    final capped = ms.clamp(0.0, duration.inMilliseconds.toDouble());
    return Duration(milliseconds: capped.round());
  }
}
