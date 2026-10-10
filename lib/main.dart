import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Edge-to-edge: content draws under status bar and gesture bar (小白条).
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    LiquidGlassWidgets.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      adaptiveQuality: true,
      theme: GlassThemeData.simple(
        blur: 14,
        thickness: 28,
        quality: GlassQuality.standard,
      ),
      child: const FryfrogHubApp(),
    ),
  );
}

/// Shared seed for material accents across glass chrome.
///
/// 实际定义在 [app_colors.dart]（与 AppColors 同模块，方便 AppPrefs 直接调用
/// [notifyGlobalAccent] 更新而不用反向依赖 main.dart）。
/// 玻璃控件请用 `kAppScheme`，Material 控件请用
/// `Theme.of(context).colorScheme.primary`。
