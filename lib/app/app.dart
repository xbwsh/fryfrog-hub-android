import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/adaptive/device_form.dart';
import '../core/network/server_connection.dart';
import '../core/state/app_prefs.dart';
import '../core/state/session.dart';
import '../core/theme/app_colors.dart';
import '../widgets/server_image.dart';
import 'root_view.dart';

class FryfrogHubApp extends StatefulWidget {
  const FryfrogHubApp({super.key});

  @override
  State<FryfrogHubApp> createState() => _FryfrogHubAppState();
}

class _FryfrogHubAppState extends State<FryfrogHubApp> {
  late final ServerConnection _connection;
  late final AppPrefs _prefs;
  late final Session _session;

  /// Last style pushed through the platform channel — preference notifies
  /// are rare now, but theme flips still shouldn't hit the channel twice.
  Brightness? _lastIconBrightness;

  @override
  void initState() {
    super.initState();
    _connection = ServerConnection();
    _prefs = AppPrefs()..load();
    _session = Session(_connection, _prefs);
  }

  @override
  void dispose() {
    _session.dispose();
    _prefs.dispose();
    _connection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      // Only preference changes should rebuild MaterialApp — Session's
      // catalog/auth notifies must not re-mount the whole tree above.
      listenable: _prefs,
      builder: (context, _) {
        final themeMode = switch (_prefs.themeMode) {
          ThemeModePref.system => ThemeMode.system,
          ThemeModePref.light => ThemeMode.light,
          ThemeModePref.dark => ThemeMode.dark,
        };

        // Keep gesture bar / status bar transparent and icons matched to theme.
        // systemNavigationBarContrastEnforced=false must ride along every
        // style: when the IME shows the engine re-applies this style, and
        // Android re-adds an opaque scrim behind the gesture pill otherwise.
        final platformBrightness = View.of(context)
            .platformDispatcher
            .platformBrightness;
        final effectiveBrightness = switch (themeMode) {
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
          ThemeMode.system => platformBrightness,
        };
        final iconBrightness = effectiveBrightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark;
        if (iconBrightness != _lastIconBrightness) {
          _lastIconBrightness = iconBrightness;
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarDividerColor: Colors.transparent,
              systemNavigationBarContrastEnforced: false,
              statusBarIconBrightness: iconBrightness,
              systemNavigationBarIconBrightness: iconBrightness,
            ),
          );
        }

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
            statusBarIconBrightness: iconBrightness,
            systemNavigationBarIconBrightness: iconBrightness,
          ),
          child: MaterialApp(
            title: 'Fryfrog Hub',
            debugShowCheckedModeBanner: false,
            themeMode: themeMode,
            theme: _buildTheme(Brightness.light),
            darkTheme: _buildTheme(Brightness.dark),
            // liquid_glass_widgets is Material-free; provide a transparent
            // Material ancestor so Text paints without yellow underlines.
            // SessionScope/AdaptiveScope must sit ABOVE the Navigator:
            // pushed routes (e.g. BookDetailScreen) are siblings of `home`,
            // and cannot see inherited widgets declared inside it.
            builder: (context, child) {
              final form = resolveDeviceForm(context);
              return Material(
                type: MaterialType.transparency,
                child: AdaptiveScope(
                  form: form,
                  child: SessionScope(session: _session, child: child!),
                ),
              );
            },
            home: RootView(session: _session),
          ),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    // `fromSeed` **不会**把 primary 设成种子色：它会算出一整套色调板，
    // 实测暗色主题下 primary = #AAC7FF（浅蓝），而轮播图的播放按钮用的是
    // AppColors.accent = #0A84FF（亮蓝）——两个播放按钮颜色不一致就是这么来的。
    // 这里显式把 primary 钉回 accent，让「详情页播放按钮」与轮播图统一。
    //
    // tabbar 不走这里：底部/顶部用的是三方 GlassTabBar，它不读 Material 主题，
    // 颜色在 main_shell.dart 里显式给（同样是 accent）。
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: brightness,
        ).copyWith(
          primary: AppColors.accent,
          // accent(#0A84FF) 上配**白字只有 3.65:1**，达不到 WCAG AA(4.5)；
          // 配深色字是 4.52:1，达标。深色底亮蓝按钮配深字也是 iOS 亮色主题的
          // 常见观感，所以选它而不是把蓝改暗（用户要的就是这个蓝）。
          onPrimary: AppColors.backgroundDark,
          surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
