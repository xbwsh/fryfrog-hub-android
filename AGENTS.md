# AGENTS.md - Fryfrog Hub Flutter

## Project Overview
跨端媒体中心客户端（Flutter rewrite），对接 Fryfrog Hub 后端。展示视频、音乐、书籍。

## Tech Stack
- **Language**: Dart 3.13+ / Flutter 3.47+
- **UI**: Material 3 + `liquid_glass_widgets`（液态玻璃）
- **状态**: ChangeNotifier + ListenableBuilder
- **图片**: cached_network_image
- **适配**: 手机 / 平板竖屏 / 平板横屏 / TV（`core/adaptive/device_form.dart`）

## Build Commands
```bash
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk
flutter build ios
```

## Architecture
```
lib/
├── main.dart
├── app/           # RootView, MainShell（四端外壳）
├── core/
│   ├── adaptive/  # DeviceForm + AdaptiveScope
│   ├── theme/     # AppColors, Dimens
│   ├── models/    # media_models.dart
│   ├── network/   # server_connection.dart
│   └── state/     # session.dart
├── features/
│   ├── auth/      # login_screen.dart
│   ├── home/      # home_screen.dart
│   ├── books/     # books_screen.dart
│   ├── music/     # music_screen.dart
│   └── profile/   # profile_screen.dart
└── widgets/       # server_image, mini_player
```

## Key Conventions

### Dimensions
所有尺寸写在 `core/theme/dimens.dart`，禁止在页面里硬编码魔法数。

### Adaptive
用 `AdaptiveScope.of(context)` 取 `DeviceForm`，分支：
- `phone`：底部 GlassTabBar
- `tabletPortrait`：顶部标题 + 底部 Dock
- `tabletLandscape`：左侧展开侧栏
- `tv`：大号侧栏 + 焦点环（`Focus` + `LogicalKeyboardKey`）

### Liquid Glass
- 顶部/底部导航用 `GlassScaffold` + `GlassAppBar` / `GlassTabBar.bottom`
- 卡片面板用 `GlassCard`，交互用 `GlassButton` / `GlassSegmentedControl`
- **不要**把玻璃控件嵌进 `GlassCard` 内部
- 初始化：`LiquidGlassWidgets.initialize()` + `LiquidGlassWidgets.wrap(brightnessResolver: Theme.maybeBrightnessOf)`

### Colors & Typography
使用 `Theme.of(context)` / `AppColors` / `Dimens`，禁止硬编码颜色与字号。

### API
- Base URL 默认 `http://192.168.31.127:20058`
- Auth: `POST /api/v1/auth/login` `{"password":"..."}` → `{"success":true,"token":"..."}`
- Token: `Authorization: Bearer <token>`
- 分页: `{"success":true,"data":{"content":[...]}}`
- 图片相对路径由 `ServerConnection.imageUrl()` 拼接

## Localization
用户可见文案当前写在代码中（中文），后续抽 l10n。

## Platforms
Android / iOS / macOS / Web。TV 通过 `--dart-define=FROG_TV=true` 或 Android TV 环境识别。
