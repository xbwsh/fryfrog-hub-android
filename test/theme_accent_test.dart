import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fryfrog_hub/core/theme/app_colors.dart';

/// 主题色统一：详情页播放按钮（`FilledButton` 吃 `colorScheme.primary`）与
/// 轮播图播放按钮（显式 `AppColors.accent`）必须是同一个蓝。
///
/// 坑：`ColorScheme.fromSeed` **不会**把 primary 设成种子色，而是算出一整套
/// 色调板——实测暗色主题下 primary 会变成 #AAC7FF（浅蓝），和 #0A84FF 明显不同。
/// 所以 app.dart 里显式把 primary 钉回 accent，这个测试守住它。
///
/// tabbar 不走主题：底部/顶部用的是三方 `GlassTabBar`，它不读 Material 主题，
/// 颜色在 main_shell.dart 里显式给（同一个 accent）。
void main() {
  // 与 lib/app/app.dart 的 _buildTheme 保持同一套关键约束
  // （不复用私有方法：那是 State 的私有实现，这里复刻约束即可）
  ColorScheme schemeFor(Brightness b) => ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: b,
  ).copyWith(primary: AppColors.accent, onPrimary: AppColors.backgroundDark);

  test('primary 就是 accent，不是 fromSeed 算出的近似色', () {
    for (final b in Brightness.values) {
      expect(
        schemeFor(b).primary,
        AppColors.accent,
        reason: '$b 主题下 primary 必须是 accent，否则播放按钮颜色会与轮播图不一致',
      );
    }
  });

  test('fromSeed 的原始 primary 确实不等于 accent（说明这个覆盖有必要）', () {
    for (final b in Brightness.values) {
      final seeded = ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: b,
      );
      expect(
        seeded.primary,
        isNot(AppColors.accent),
        reason: '$b：若哪天 fromSeed 直接返回种子色，这个覆盖就可以删掉了',
      );
    }
  });

  test('onPrimary 在 accent 上达到 WCAG AA 对比度', () {
    for (final b in Brightness.values) {
      final s = schemeFor(b);
      // 为什么不用白字：accent(#0A84FF) 配白字只有 3.65:1，不达标；
      // 配深色字（backgroundDark）是 4.52:1。分集选择 chip 也是这个组合
      // （选中态 primary 底 + onPrimary 字，字号 14），所以必须守这条。
      expect(s.onPrimary, AppColors.backgroundDark);
      expect(
        _contrastRatio(s.primary, s.onPrimary),
        greaterThanOrEqualTo(4.5),
        reason: '$b：accent 底上的字色需要 ≥4.5:1',
      );
    }
  });

  test('白字在 accent 上确实不达标（说明不能用白色）', () {
    final ratio = _contrastRatio(AppColors.accent, Colors.white);
    expect(ratio, lessThan(4.5), reason: '若哪天 accent 变暗到白字达标，这条约束就可以放宽了');
  });
}

/// WCAG 相对亮度对比度。
double _contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

double _luminance(Color c) {
  double channel(int byte) {
    final v = byte / 255;
    return v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  final argb = c.toARGB32();
  return 0.2126 * channel((argb >> 16) & 0xFF) +
      0.7152 * channel((argb >> 8) & 0xFF) +
      0.0722 * channel(argb & 0xFF);
}
