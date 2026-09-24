# Fryfrog Hub (Flutter)

个人 NAS 媒体库的跨端客户端（Flutter + liquid_glass_widgets）。对接服务端 `fryfrog-hub-api`，布局对齐 `fryfrog-hub-apple`，并适配 **手机 / 平板竖屏 / 平板横屏 / TV** 四种形态。

## 技术栈

| 层 | 选型 |
|---|---|
| UI | Flutter 3.47+ / Material 3 |
| 液态玻璃 | `liquid_glass_widgets`（GlassScaffold / GlassTabBar / GlassCard） |
| 状态 | ChangeNotifier + ListenableBuilder |
| 图片 | cached_network_image |
| 存储 | shared_preferences |
| 网络 | http（对接 fryfrog-hub-api） |

## 布局适配

| 形态 | 判定 | 导航 | 内容 |
|---|---|---|---|
| 手机 | shortSide &lt; 600 | 底部 GlassTabBar 胶囊 Dock | 单列滚动 + 横向海报轨 |
| 平板竖屏 | shortSide ≥ 600 且竖屏 | 顶部 GlassAppBar + 底部 Dock | 收窄内容列（max 720） |
| 平板横屏 | shortSide ≥ 600 且横屏 | 左侧展开玻璃侧栏 | 宽内容 + 更密网格 |
| TV | `-FROG_TV=true` / Android TV | 大号左侧导航 + 焦点描边 | 大字大卡（D-pad / Enter） |

切换形态后自适应重建，无需分包。

## 工程结构

```
lib/
  main.dart                 # LiquidGlassWidgets.initialize + wrap
  app/                      # RootView / MainShell（四端外壳）
  core/
    adaptive/               # DeviceForm 判定
    theme/                  # colors / dimens
    models/                 # DTO
    network/                # ServerConnection（局域网优先）
    state/                  # Session
  features/
    auth/ home/ books/ music/ profile/
  widgets/
```

## 运行

```bash
flutter pub get
flutter run                 # 手机
flutter run -d chrome       # Web 预览
flutter run --dart-define=FROG_TV=true   # TV 布局
```

## 构建

```bash
flutter analyze
flutter test
flutter build apk
flutter build ios
```
