import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/adaptive/device_form.dart';
import '../core/network/server_connection.dart';
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
  late final Session _session;

  @override
  void initState() {
    super.initState();
    _connection = ServerConnection();
    _session = Session(_connection);
  }

  @override
  void dispose() {
    _session.dispose();
    _connection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final themeMode = switch (_session.themeMode) {
          ThemeModePref.system => ThemeMode.system,
          ThemeModePref.light => ThemeMode.light,
          ThemeModePref.dark => ThemeMode.dark,
        };

        // Keep gesture bar / status bar transparent and icons matched to theme.
        final platformBrightness =
            View.of(context).platformDispatcher.platformBrightness;
        final effectiveBrightness = switch (themeMode) {
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
          ThemeMode.system => platformBrightness,
        };
        final iconBrightness =
            effectiveBrightness == Brightness.dark ? Brightness.light : Brightness.dark;
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            statusBarIconBrightness: iconBrightness,
            systemNavigationBarIconBrightness: iconBrightness,
          ),
        );

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
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
            builder: (context, child) => Material(
              type: MaterialType.transparency,
              child: child!,
            ),
            home: Builder(
              builder: (context) {
                final form = resolveDeviceForm(context);
                return AdaptiveScope(
                  form: form,
                  child: SessionScope(
                    session: _session,
                    child: RootView(session: _session),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: brightness,
    ).copyWith(
      surface: brightness == Brightness.dark
          ? AppColors.surfaceDark
          : AppColors.surfaceLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
