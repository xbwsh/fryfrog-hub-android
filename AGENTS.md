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

## Release（打 tag 发版）
推送 `v*` 标签触发 CI（`.github/workflows/build.yml`）：校验标签格式 → 解码
`KEYSTORE_*` Secrets 签名 → analyze + test → 按标签构建（`--build-name` 取自标签，
`--build-number` = CI 流水号）→ 自动创建 GitHub Release 并挂 `fryfrog-hub-vX.Y.Z.apk`。

### 步骤
1. **先确认 HEAD 是绿的**（仓库常有其他会话的提交，必须在当前 HEAD 上验证）：
   ```powershell
   [Environment]::SetEnvironmentVariable('ProgramFiles(x86)', 'C:\Program Files (x86)', 'Process')
   flutter analyze   # 必须 0 issues
   flutter test      # 必须全过
   ```
2. 升 `pubspec.yaml`：`version: X.Y.(Z+1)+N`，提交信息 `chore(release): bump version to X.Y.Z+N`，push main。
3. `git tag vX.Y.Z`（打在 bump 提交上）&& `git push origin vX.Y.Z`
4. 轮询到 Release 出现（**查不到 run 时要继续等，不能退出循环**）：
   ```powershell
   $sha = (git rev-parse vX.Y.Z); $deadline = (Get-Date).AddMinutes(9); $run = $null
   do {
     Start-Sleep -Seconds 25
     $runs = Invoke-RestMethod "https://api.github.com/repos/<owner>/<repo>/actions/runs?head_sha=$sha&per_page=5"
     if ($runs.total_count -gt 0) {
       $run = $runs.workflow_runs | Sort-Object created_at -Descending | Select-Object -First 1
       Write-Host ("run#{0} {1}/{2}" -f $run.run_number, $run.status, $run.conclusion)
     } else { Write-Host 'no run yet' }
   } while (($null -eq $run -or $run.status -ne 'completed') -and (Get-Date) -lt $deadline)
   ```
5. 校验 `GET /releases/latest`：tag 正确 + 资产 `fryfrog-hub-vX.Y.Z.apk` 存在。

### 红线与教训
- **标签必须是 `v` + `X.Y.Z`**（工作流正则校验）；包内版本号来自标签，与 pubspec 无关（pubspec 只是惯例性同步）。
- **打标签前必须在当前 HEAD 本地跑绿 analyze+test**——教训：v2.1.11 标签指向的提交测试是坏的（修复在下一个提交），且该 tag 推送没有触发任何 CI run（`head_sha` 查询为 0），只能改发 v2.1.12。
- **绝不移动/覆盖已有标签**（`git tag -f` 会被沙箱拦截且危险）；若标签已存在但没有 Release → 直接发下一个版本号，留下悬空标签无害。
- 轮询循环写法：`while (($null -eq $run -or $run.status -ne 'completed') -and ...)`；写成 `$run -and ...` 会在查不到 run 时提前退出（只等一轮）。
- 签名 Secrets：仓库需 `KEYSTORE_BASE64 / KEYSTORE_PASSWORD / KEY_ALIAS / KEY_PASSWORD`；缺失时 **tag 构建直接失败**，普通 push 回退 debug 签名。
- 本机 `flutter test` 若报 `%PROGRAMFILES(X86)% not found`，先执行上面的 `SetEnvironmentVariable`。
- **后端发版与此无关**：fryfrog-hub-api push master 自动构建 ghcr 镜像，NAS 上 `docker compose pull && docker compose up -d` 部署（可能还需对媒体库跑一次扫描使数据修复生效）。

## Architecture
```
lib/
├── main.dart
├── app/           # RootView, MainShell（四端外壳）
├── core/
│   ├── adaptive/  # DeviceForm + AdaptiveScope
│   ├── theme/     # AppColors, Dimens
│   ├── models/    # 按域拆分：video/books/music/user/common + media_models barrel
│   ├── rules/     # WatchRules 等纯业务规则（可单测）
│   ├── network/   # ServerConnection, ApiClient, gateways（端口）+ gateways_impl
│   └── state/     # session.dart
├── features/
│   ├── auth/      # login_screen.dart
│   ├── home/      # home_screen.dart
│   ├── books/     # books_screen + comic_reader(_controller)
│   ├── music/     # music_screen.dart
│   ├── video/     # detail/player + video_detail_controller
│   └── profile/   # profile_screen.dart
└── widgets/       # server_image, mini_player
```

依赖方向：`features → core/rule|gateway 端口 → ApiClient 适配器 → http`。
UI 只渲染 Controller 状态；业务编排在 `*Controller`，进度规则在 `WatchRules`。

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
