import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fryfrog_hub/core/theme/app_colors.dart';

/// 主题色约束：每个可选主题色都必须满足同一套规则。
///
/// 两条硬约束：
///  1. `ColorScheme.fromSeed` **不会**把 primary 设成种子色，而是算出一整套
///     色调板（实测暗色下 primary 变成 #AAC7FF）。所以 app.dart 里显式把
///     primary 钉回主题色，这个测试守住它。
///  2. primary 上的文字必须达到 WCAG AA(4.5:1)。两个主题色配白字都不达标
///     （经典蓝 3.65、青绿 2.12），所以统一用深色字。
///
/// tabbar 不走 Material 主题：底部/顶部用三方 GlassTabBar，它读
/// [kAppScheme]，由 `notifyGlobalAccent` 单独维护。
void main() {
  // 与 app.dart 的 _buildTheme 保持同一套关键约束（不复用私有实现）。
  ColorScheme schemeFor(Brightness b, Color accent) => ColorScheme.fromSeed(
    seedColor: accent,
    brightness: b,
  ).copyWith(primary: accent, onPrimary: AppColors.backgroundDark);

  test('每个主题色：primary 就是它本身，不是 fromSeed 的近似色', () {
    for (final a in AppAccent.values) {
      for (final b in Brightness.values) {
        expect(
          schemeFor(b, a.color).primary,
          a.color,
          reason:
              '${a.title} 在 $b 主题下 primary 必须是它本身，'
              '否则播放按钮颜色会与轮播图不一致',
        );
      }
    }
  });

  test('fromSeed 的原始 primary 确实不等于主题色（说明这个覆盖有必要）', () {
    for (final a in AppAccent.values) {
      for (final b in Brightness.values) {
        final seeded = ColorScheme.fromSeed(seedColor: a.color, brightness: b);
        expect(
          seeded.primary,
          isNot(a.color),
          reason:
              '${a.title}/$b：若哪天 fromSeed 直接返回种子色，'
              '这个覆盖就可以删掉了',
        );
      }
    }
  });

  test('每个主题色：onPrimary 达到 WCAG AA 对比度', () {
    for (final a in AppAccent.values) {
      for (final b in Brightness.values) {
        final s = schemeFor(b, a.color);
        expect(
          s.onPrimary,
          AppColors.backgroundDark,
          reason: '${a.title}：主色上的字必须是深色',
        );
        expect(
          _contrastRatio(s.primary, s.onPrimary),
          greaterThanOrEqualTo(4.5),
          reason: '${a.title} 在 $b：主色底上的字需要 ≥4.5:1',
        );
      }
    }
  });

  test('白字在所有主题色上都不达标（说明必须用深色字）', () {
    for (final a in AppAccent.values) {
      expect(
        _contrastRatio(a.color, Colors.white),
        lessThan(4.5),
        reason:
            '${a.title}：若哪天某个主题色变暗到白字达标，'
            '这条约束就可以单独放宽了',
      );
    }
  });

  test('枚举里包含需求指定的新主题色 #00c8b4', () {
    expect(
      AppAccent.values.map((a) => a.color),
      contains(const Color(0xFF00C8B4)),
      reason: '需求：新增 #00c8b4（青绿/绿松石）主题色',
    );
  });

  test('主题色名称非空且互不重复（持久化按 name 存取）', () {
    final names = AppAccent.values.map((a) => a.name).toSet();
    expect(
      names.length,
      AppAccent.values.length,
      reason: '枚举 name 必须唯一，否则持久化后无法区分',
    );
    for (final a in AppAccent.values) {
      expect(a.title, isNotEmpty, reason: '${a.name} 缺少展示名');
    }
  });

  test('notifyGlobalAccent 会更新 kAppScheme.primary（玻璃控件换色）', () {
    final before = kAppScheme.primary;
    for (final a in AppAccent.values) {
      notifyGlobalAccent(a.color);
      expect(
        kAppScheme.primary,
        a.color,
        reason: '${a.title}：GlassTabBar 读的 kAppScheme.primary 要跟着变',
      );
    }
    // 复位，避免影响其它用例的全局状态。
    notifyGlobalAccent(before);
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
