import 'dart:math' as math;

/// 拖动手势的纯规则（可单测）：先定轴，再算快进预览位置。
///
/// 抽出来是因为播放器 State 无法在测试里跑（media_kit 要原生 mpv），
/// 而轴判定/预览换算是"横滑不会误触发亮度音量、退几秒能精准把握"
/// 这件事的全部依据。
class SeekRules {
  const SeekRules._();

  /// 位移攒够 slop 之前不许动手：进度、亮度、音量都还没开始改。
  static bool readyToDecide(double dx, double dy, {double slop = 8}) =>
      dx.abs() + dy.abs() >= slop;

  /// 横向位移更大 → 快进快退；否则走纵向的亮度/音量。
  static bool isHorizontal(double dx, double dy) => dx.abs() >= dy.abs();

  // ── 位移 → 时间 的换算（旧版"整屏=整集"已废弃：45 分钟的集约 7 秒/像素，
  //    手指抖 2px 预览就跳十几秒，"退回几秒"根本没法操作）──────────────
  //
  // 精细段 |dx| ≤ [kFinePx]：[kFineMsPerPx] ≈ 0.1s/px —— 20px 即 2 秒，
  //   几秒级的微调 = 手指挪一两厘米，指哪打哪。
  // 加速段 |dx| > [kFinePx]：超出部分 [kFastMsPerPx] ≈ 0.75s/px（7.5 倍），
  //   整屏（~400px）一划 ≈ 3 分半，长跳不用磨。
  // 结果按 **1 秒** 量化：读数永远是整秒，"退了 3 秒"就是 3 秒。
  static const double kFinePx = 150;
  static const double kFineMsPerPx = 100;
  static const double kFastMsPerPx = 750;

  /// 横滑位移换算出的预览位置，clamp 在 `[0, duration]`，整秒量化。
  ///
  /// 时长未知（`duration` 为 0）时退回起点，不产生跳转。
  static Duration preview({
    required Duration start,
    required Duration duration,
    required double deltaPx,
  }) {
    if (duration <= Duration.zero) return start;
    final sign = deltaPx < 0 ? -1.0 : 1.0;
    final mag = deltaPx.abs();
    final fine = math.min(mag, kFinePx);
    final fast = math.max(0.0, mag - kFinePx);
    // 位移先按秒量化，再叠加起点：从 7:23 出发滑 10px 精确得到 7:24/7:22。
    final movedMs =
        ((fine * kFineMsPerPx + fast * kFastMsPerPx) / 1000).round() * 1000 *
        sign;
    final ms = start.inMilliseconds + movedMs;
    final capped = ms.clamp(0.0, duration.inMilliseconds.toDouble());
    return Duration(milliseconds: capped.round());
  }
}
