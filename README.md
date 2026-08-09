# Fryfrog Hub Android

[English](#english) | 简体中文

## 项目简介

Fryfrog Hub Android 是 [Fryfrog Hub](https://github.com/fryfrog-hub) 媒体中心的 Android 客户端应用。支持浏览和播放视频（电视剧 / 电影）。

### 主要功能

- **视频播放** — 电视剧和电影浏览，集成 MPV 播放器，支持 ASS/SSA 字幕、音轨切换、倍速播放、硬解（MediaCodec）
- **系列详情** — 分季分集浏览、播放进度记忆、集封面 / 季海报展示
- **追更日历** — 查看系列下一集更新时间
- **收藏** — 系列 / 独立视频收藏列表
- **TMDB 刮削** — 搜索绑定 / 解绑 / 刷新元数据，候选帧选封面
- **季海报管理** — 单系列 / 批量刷新季海报、集封面、演员信息
- **元数据编辑** — 标题、简介、评分、年份、类型等
- **媒体库管理** — 多媒体库配置、扫描、补全刮削
- **用户认证** — 密码登录，Bearer Token 鉴权
- **隐私模式** — 可隐藏成人内容
- **深色主题** — 三档主题（跟随系统 / 浅色 / 深色），悬浮导航栏
- **本地化** — 中文/英文双语支持

## 技术栈

| 组件 | 技术 |
|------|------|
| 语言 | Kotlin 2.0.21 |
| UI 框架 | Jetpack Compose + Material3 |
| 网络 | Retrofit 2.11 + OkHttp 4.12 |
| 图片加载 | Coil 2.7 |
| 视频播放 | MPV (jniLibs) |
| JSON 序列化 | Gson |
| 最低版本 | Android 7.0 (SDK 24) |
| 目标版本 | Android 15 (SDK 35) |

## 架构

```
app/src/main/java/com/fryfrog/hub/
├── data/
│   ├── model/       # API 响应模型
│   ├── remote/      # Retrofit API 接口 + 客户端
│   └── repository/  # 数据层
├── player/          # MPV 播放器封装
├── service/         # 后台服务
├── ui/
│   ├── components/  # 可复用 Compose 组件
│   ├── home/        # 首页 + ViewModel
│   ├── videos/      # 视频列表 / 系列详情
│   ├── calendar/    # 追更日历
│   ├── favorites/   # 收藏
│   ├── player/      # 播放器页
│   ├── settings/    # 设置 / 媒体库管理
│   ├── navigation/  # 导航（悬浮底部导航栏）
│   └── theme/       # 主题配置（颜色、字体、尺寸）
├── util/            # 工具类（PrefsManager）
└── MainActivity.kt
```

## 构建

### 环境要求

- Android Studio Ladybug 或更高版本
- JDK 17+
- Android SDK 35

### 编译运行

```bash
# 构建 Debug APK
./gradlew assembleDebug

# 构建 Release APK
./gradlew assembleRelease

# 代码检查
./gradlew lint
```

### 签名配置

Release 构建需要签名。在 `local.properties` 或环境变量中配置：

```
KEYSTORE_PASSWORD=your_password
KEY_ALIAS=your_alias
KEY_PASSWORD=your_key_password
```

默认使用项目自带的 `app/release.jks` 签名文件。

## 后端服务

本客户端需要 Fryfrog Hub 后端服务支持。

- **默认地址**: `http://192.168.31.127:20058`
- **API 文档**: 后端提供 Swagger/OpenAPI 文档
- **认证方式**: Bearer Token（密码登录获取）

### 关键接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `/api/v1/video/series` | GET | 系列列表（分页） |
| `/api/v1/video/series/{id}` | GET | 系列详情（含季封面 URL） |
| `/api/v1/video/series/{id}/refresh-season-covers` | POST | 刷新单个系列的季资源（季海报 / 集封面 / 演员） |
| `/api/v1/video/series/refresh-all-season-covers` | POST | 批量刷新所有系列的季资源 |
| `/api/v1/video/refresh-all-movie-actors` | POST | 批量刷新所有电影的演员 |
| `/api/v1/video/{id}/tmdb/bind` | POST | 绑定 TMDB 元数据 |
| `/api/v1/video/{id}/tmdb/refresh` | POST | 刷新 TMDB 元数据 |

## License

MIT License

---

# English

## Overview

Fryfrog Hub Android is the Android client for [Fryfrog Hub](https://github.com/fryfrog-hub) media center. Browse and play videos (TV shows & movies).

### Features

- **Video playback** — TV shows and movies with MPV player, ASS/SSA subtitles, audio track switching, playback speed, hardware decoding (MediaCodec)
- **Series details** — Season/episode browsing, watch progress memory, episode covers & season posters
- **Upcoming calendar** — Track next episode release dates
- **Favorites** — Favorite series and standalone videos
- **TMDB scraping** — Search/bind/unbind/refresh metadata, pick cover from candidate frames
- **Season poster management** — Refresh season posters, episode covers and actors for a single series or all series
- **Metadata editing** — Title, overview, rating, year, genre, etc.
- **Media library management** — Multiple libraries, scanning, supplemental scraping
- **Auth** — Password login with Bearer token
- **Privacy mode** — Hide adult content option
- **Theme** — System/light/dark modes, floating bottom navigation bar
- **Localization** — Chinese and English

## Tech Stack

| Component | Technology |
|-----------|------------|
| Language | Kotlin 2.0.21 |
| UI | Jetpack Compose + Material3 |
| Networking | Retrofit 2.11 + OkHttp 4.12 |
| Image Loading | Coil 2.7 |
| Video | MPV (jniLibs) |
| JSON | Gson |
| Min SDK | 24 (Android 7.0) |
| Target SDK | 35 (Android 15) |

## Build

```bash
./gradlew assembleDebug    # Debug APK
./gradlew assembleRelease  # Release APK
./gradlew lint             # Lint checks
```

## Backend

Requires the Fryfrog Hub backend service.

- **Default address**: `http://192.168.31.127:20058`
- **API docs**: backend provides Swagger/OpenAPI docs
- **Auth**: Bearer token (obtained via password login)

## License

MIT License
