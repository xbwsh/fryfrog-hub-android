# AGENTS.md - Fryfrog Hub Android

## Project Overview
Android media center client for Fryfrog Hub backend. Displays videos, music, comics, and ebooks.

## Tech Stack
- **Language**: Kotlin 2.0.21
- **UI**: Jetpack Compose + Material3
- **Networking**: Retrofit 2.11 + OkHttp 4.12 + Gson
- **Images**: Coil 2.7
- **Min SDK**: 24 (Android 7.0)
- **Target SDK**: 35

## Build Commands
```bash
./gradlew assembleDebug      # Build debug APK
./gradlew assembleRelease    # Build release APK
./gradlew lint               # Run lint checks
```

## Architecture
```
app/src/main/java/com/fryfrog/hub/
├── data/
│   ├── model/      # API response models (Models.kt)
│   ├── remote/     # Retrofit API interface + client
│   └── repository/ # Data layer (MediaRepository.kt)
├── ui/
│   ├── components/ # Reusable composables (MediaCard.kt)
│   ├── home/       # Home screen + ViewModel
│   ├── login/      # Login screen + ViewModel
│   ├── navigation/ # (reserved)
│   └── theme/      # Colors, Typography, Dimens
├── util/           # PrefsManager
├── FryfrogHubApplication.kt
└── MainActivity.kt
```

## Key Conventions

### Dimensions
All dimensions centralized in `ui/theme/Dimens.kt`. Never hardcode `.dp` or `.sp` values in composables.
```kotlin
// Use Dimens constants
Spacer(modifier = Modifier.height(Dimens.spacingLg))
RoundedCornerShape(Dimens.radiusMd)

// NOT this
Spacer(modifier = Modifier.height(16.dp))
```

### Strings
All user-facing strings in `res/values/strings.xml` (English default) and `res/values-zh/strings.xml` (Chinese). Use `stringResource(R.string.xxx)`.

### Colors & Typography
Always use `MaterialTheme.colorScheme` and `MaterialTheme.typography`. Never hardcode colors or text styles.

### API Response Format
Backend returns paginated responses:
```json
{"success": true, "data": {"content": [...], "page": 0, "size": 20, ...}}
```
Access data via: `api.getVideoSeries().data?.content`

### Image URLs
API returns relative paths (e.g., `/api/v1/video/2/cover`). Repository layer prepends base URL via `fixUrl()`.

## Backend
- **Base URL**: `http://192.168.31.127:20058`
- **Auth**: POST `/api/v1/auth/login` with `{"password": "xxx"}` returns `{"success": true, "token": "..."}`
- **Token**: `Authorization: Bearer <token>` header required for all endpoints
- **API Docs**: `http://192.168.31.127:20058/api-docs`

## Localization
- Default locale: English (`values/strings.xml`)
- Chinese: `values-zh/strings.xml`
- System auto-selects based on device language

## Android Skills

本项目集成了 [Android Skills](https://github.com/android/skills)，提供 AI 优化的 Android 开发最佳实践指南。

### 已安装的 Skills

| 类别 | Skill | 用途 |
|------|-------|------|
| 构建 | `agp-9-upgrade` | AGP 9 升级指南 |
| 相机 | `camerax` | CameraX 使用 |
| 设备 AI | `appfunctions` | App Functions |
| 开发工具 | `android-cli` | Android CLI |
| 身份验证 | `verified-email` | 验证邮箱 |
| **Compose** | `jetpack-compose/theming/styles` | Compose 主题样式 |
| **Compose** | `jetpack-compose/migration` | XML 迁移到 Compose |
| **Compose** | `jetpack-compose/adaptive` | 自适应布局 |
| 导航 | `navigation-3` | Navigation 3 |
| 性能 | `r8-analyzer` | R8 代码分析 |
| Play | `play/engage-sdk-integration` | Play SDK 集成 |
| Play | `play/play-policy-insights` | Play 政策 |
| Play | `play/play-billing-library-version-upgrade` | 计费库升级 |
| 分析器 | `profilers/perfetto-trace-analysis` | Perfetto 跟踪分析 |
| 分析器 | `profilers/perfetto-sql` | Perfetto SQL |
| 安全 | `android-intent-security` | Intent 安全 |
| 系统 | `edge-to-edge` | 全屏适配 |
| 测试 | `testing-setup` | 测试配置 |
| Wear | `wear-compose-m3` | Wear Compose M3 |
| XR | `display-glasses-with-jetpack-compose-glimmer` | XR 显示 |

### 更新 Skills

如需更新到最新版本，重新克隆仓库并覆盖：

```bash
cd /tmp
git clone --depth 1 https://github.com/android/skills.git
rm -rf .opencode/skills/*
cp -r android-skills/* .opencode/skills/
rm -rf android-skills
```

### 自动调用规则

执行以下任务时，必须先加载对应的 Skill：

| 任务场景 | 加载的 Skill |
|---------|-------------|
| 修改主题颜色、字体、样式 | `jetpack-compose/theming/styles` |
| 将 XML 布局迁移到 Compose | `jetpack-compose/migration` |
| 实现响应式/自适应布局 | `jetpack-compose/adaptive` |
| 添加或修改导航 | `navigation-3` |
| 添加相机功能 | `camerax` |
| 实现全屏/沉浸式显示 | `edge-to-edge` |
| 配置测试环境 | `testing-setup` |
| 分析 R8 混淆问题 | `r8-analyzer` |
| 使用 Perfetto 分析性能 | `profilers/perfetto-trace-analysis` |
| 编写 Perfetto SQL 查询 | `profilers/perfetto-sql` |
| 处理 Intent 安全问题 | `android-intent-security` |
| 集成 Play SDK | `play/engage-sdk-integration` |
| 升级 AGP 版本 | `agp-9-upgrade` |

加载方式：使用 `skill` 工具，例如 `skill(name="jetpack-compose/theming/styles")`
