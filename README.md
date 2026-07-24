# Fryfrog Hub Android

[English](#english) | 简体中文

## 项目简介

Fryfrog Hub Android 是 [Fryfrog Hub](https://github.com/fryfrog-hub) 媒体中心的 Android 客户端应用。支持浏览和播放视频、音乐，阅读漫画和电子书。

### 主要功能

- **视频播放** — 支持电视剧和电影浏览，集成 libVLC 播放器，支持 ASS/SSA 字幕
- **音乐播放** — 专辑浏览、收藏列表、最近添加，支持歌词显示（内嵌歌词 + LRC 文件）
- **漫画阅读** — 漫画系列浏览、卷数详情、角色信息
- **电子书阅读** — 电子书系列浏览、卷数详情
- **用户认证** — 密码登录，支持多服务器保存与快速切换
- **隐私模式** — 可隐藏成人内容
- **深色主题** — 默认深色，支持主题切换
- **本地化** — 中文/英文双语支持

## 技术栈

| 组件 | 技术 |
|------|------|
| 语言 | Kotlin 2.0.21 |
| UI 框架 | Jetpack Compose + Material3 |
| 网络 | Retrofit 2.11 + OkHttp 4.12 |
| 图片加载 | Coil 2.7 |
| 视频/音频 | libVLC 3.6.2 |
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
├── ui/
│   ├── components/  # 可复用 Compose 组件
│   ├── home/        # 首页 + ViewModel
│   ├── login/       # 登录页 + ViewModel
│   ├── player/      # 播放器页
│   ├── music/       # 音乐页
│   ├── comic/       # 漫画页
│   ├── ebook/       # 电子书页
│   └── theme/       # 主题配置（颜色、字体、尺寸）
├── util/            # 工具类（PrefsManager）
└── service/         # 前台服务（MusicService）
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

## License

MIT License

---

# English

## Overview

Fryfrog Hub Android is the Android client for [Fryfrog Hub](https://github.com/fryfrog-hub) media center. Browse and play videos, music, comics, and ebooks.

### Features

- **Video** — TV shows and movies with libVLC player and ASS/SSA subtitle support
- **Music** — Album browsing, favorites, recently added, lyrics display (embedded + LRC)
- **Comics** — Series browsing with volume details and character info
- **Ebooks** — Series browsing with volume details
- **Auth** — Password login with multi-server support
- **Privacy** — Hide adult content option
- **Theme** — Dark theme default with toggle support
- **Localization** — Chinese and English

## Tech Stack

| Component | Technology |
|-----------|------------|
| Language | Kotlin 2.0.21 |
| UI | Jetpack Compose + Material3 |
| Networking | Retrofit 2.11 + OkHttp 4.12 |
| Image Loading | Coil 2.7 |
| Media | libVLC 3.6.2 |
| JSON | Gson |
| Min SDK | 24 (Android 7.0) |
| Target SDK | 35 (Android 15) |

## Build

```bash
./gradlew assembleDebug    # Debug APK
./gradlew assembleRelease  # Release APK
./gradlew lint             # Lint checks
```

## License

MIT License
