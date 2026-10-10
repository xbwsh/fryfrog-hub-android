import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';

/// UI preferences (theme, accent, privacy) split out of [Session].
///
/// Session notifies on every catalog/auth update; if MaterialApp listened to
/// it, each of those would rebuild the entire app tree. Listening to this
/// notifier instead limits that cost to actual preference changes.
class AppPrefs extends ChangeNotifier {
  AppPrefs();

  static const _kTheme = 'prefs.themeMode';
  static const _kAccent = 'prefs.accent';

  ThemeModePref themeMode = ThemeModePref.system;

  /// 主题色。改动会经 [notifyListeners] 驱动 MaterialApp 重建，全局即时生效。
  AppAccent accent = AppAccent.blue;

  bool privacyEnabled = false;

  /// 当前主题主色。代码里凡是要用accent 的地方一律读这个（或
  /// `Theme.of(context).colorScheme.primary`），不要直接写 `AppColors.accent`。
  Color get accentColor => accent.color;

  /// Restores the persisted theme/accent. Safe to fire-and-forget at startup.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAccent = prefs.getString(_kAccent);
    if (savedAccent != null) {
      accent = AppAccent.values.firstWhere(
        (a) => a.name == savedAccent,
        // 持久化里存了已下线的色值（以后删枚举项会出现）→ 回退默认，别崩。
        orElse: () => AppAccent.blue,
      );
      // 启动时也要刷新玻璃控件用的全局 scheme（否则重启后 tabbar 还是旧色）。
      notifyGlobalAccent(accent.color);
    }
    final saved = prefs.getString(_kTheme);
    if (saved == null) return;
    final restored = ThemeModePref.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeModePref.system,
    );
    if (restored != themeMode) {
      themeMode = restored;
      notifyListeners();
    } else if (savedAccent != null) {
      // 主题色变了但明暗模式没变，也要通知一次让 UI 重建。
      notifyListeners();
    }
  }

  void setPrivacy(bool value) {
    if (privacyEnabled == value) return;
    privacyEnabled = value;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeModePref mode) async {
    if (themeMode != mode) {
      themeMode = mode;
      notifyListeners();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTheme, mode.name);
  }

  /// 切换主题色：立即生效（notifyListeners）并持久化。
  ///
  /// 顺带刷新玻璃控件用的全局 scheme——三方 GlassTabBar 等不读 Material 主题。
  Future<void> setAccent(AppAccent value) async {
    if (accent != value) {
      accent = value;
      notifyGlobalAccent(value.color);
      notifyListeners();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccent, value.name);
  }
}

enum ThemeModePref {
  system('跟随系统'),
  light('浅色'),
  dark('深色');

  const ThemeModePref(this.title);
  final String title;
}
