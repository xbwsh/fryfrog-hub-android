import 'package:flutter/material.dart';

/// 可选主题色。
///
/// 用枚举而不是裸 Color 字符串，是为了让「名称 + 色值 + 前景色」绑在一起，
/// 避免持久化时只存了颜色、忘了配套的文字色导致对比度不达标。
enum AppAccent {
  /// 经典蓝（默认，保持原有观感）。
  blue('经典蓝', Color(0xFF0A84FF)),

  /// 青绿 / 绿松石（#00c8b4）。
  teal('青绿', Color(0xFF00C8B4));

  const AppAccent(this.title, this.color);

  /// 展示给用户看的名称。
  final String title;

  /// 主题主色。
  final Color color;

  /// 主色上的前景色。
  ///
  /// 两个色值上都用**深色字**：#0A84FF 配白字只有 3.65:1（不达WCAG AA），
  /// #00C8B4 配白字约 2.4:1 更差，配深色字才能保证可读。
  /// 详见 test/theme_accent_test.dart 的对比度用例。
  Color get onColor => AppColors.backgroundDark;
}

/// Design tokens matching fryfrog-hub-apple Theme.swift.
class AppColors {
  const AppColors._();

  /// Soft charcoal background in dark mode (not pure black).
  static const Color backgroundDark = Color(0xFF1C1F26);
  static const Color surfaceDark = Color(0xFF292B33);
  static const Color backgroundLight = Color(0xFFF2F2F7);
  static const Color surfaceLight = Color(0xFFEDEDF2);

  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? backgroundDark
      : backgroundLight;

  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? surfaceDark
      : surfaceLight;

  /// **当前主题色**（随用户在「我的 → 外观 → 主题色」的选择变化）。
  ///
  /// 这是取accent 的正确方式：Material 控件一律用这个（或直接用
  /// `Theme.of(context).colorScheme.primary`，二者等价）。
  /// 只有拿不到 BuildContext 的地方才退回 [accent] 常量。
  static Color accentOf(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static const Color danger = Color(0xFFFF453A);
  static const Color success = Color(0xFF30D158);
  static const Color warning = Color(0xFFFF9F0A);

  /// 默认主题色（经典蓝）。
  ///
  /// ⚠️ 这是**兜底常量**，不是「当前主题色」。当前主题色请读
  /// `Theme.of(context).colorScheme.primary`，或 `AppPrefs.accentColor`。
  /// 只有那些拿不到 BuildContext 的地方（main.dart 的全局 scheme 等）才用它。
  static const Color accent = Color(0xFF0A84FF);

  /// Rating stars / score chips (IMDb-style gold).
  static const Color gold = Color(0xFFF5C518);

  /// 液态玻璃材质色（跨亮暗模式通用的白色玻璃）：
  /// `glassBar` 是底部 tabbar 的玻璃底色，`glassPill` 是选中 pill 的填充。
  static const Color glassBar = Color(0x52FFFFFF);
  static const Color glassPill = Color(0x2EFFFFFF);
}

/// 玻璃控件用的全局 ColorScheme（当前主题色）。
///
/// 三方 `liquid_glass_widgets`（GlassTabBar/GlassAppBar…）**不读** Material
/// 主题，只能靠这个顶层值拿颜色。它必须随主题色一起变，所以做成可重新赋值的
/// 全局量。变更统一走 [notifyGlobalAccent]，别直接赋值。
///
/// Material 控件不要用它——那些请读 `Theme.of(context).colorScheme.primary`。
ColorScheme kAppScheme = ColorScheme.fromSeed(
  seedColor: AppColors.accent,
  brightness: Brightness.dark,
);

/// 主题色变更后重算 [kAppScheme]，供玻璃控件即时换色。
///
/// `primary` 显式钉回种子色：`fromSeed` 会算出一整套近似色调板（实测暗色
/// 下 primary 变成 #AAC7FF），不钉回去就和 Material 主题对不上了。
void notifyGlobalAccent(Color accent) {
  kAppScheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.dark,
  ).copyWith(primary: accent, onPrimary: AppColors.backgroundDark);
}
