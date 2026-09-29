import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UI preferences (theme, privacy) split out of [Session].
///
/// Session notifies on every catalog/auth update; if MaterialApp listened to
/// it, each of those would rebuild the entire app tree. Listening to this
/// notifier instead limits that cost to actual preference changes.
class AppPrefs extends ChangeNotifier {
  AppPrefs();

  static const _kTheme = 'prefs.themeMode';

  ThemeModePref themeMode = ThemeModePref.system;
  bool privacyEnabled = false;

  /// Restores the persisted theme. Safe to fire-and-forget at startup.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kTheme);
    if (saved == null) return;
    final restored = ThemeModePref.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeModePref.system,
    );
    if (restored == themeMode) return;
    themeMode = restored;
    notifyListeners();
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
}

enum ThemeModePref {
  system('跟随系统'),
  light('浅色'),
  dark('深色');

  const ThemeModePref(this.title);
  final String title;
}
