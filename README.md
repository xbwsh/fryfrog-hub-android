# Fryfrog Hub

Android 客户端，连接 [Fryfrog Hub](https://github.com/niubility-fryfrog/fryfrog-hub) 后端服务，提供视频、音乐、漫画、电子书的浏览与播放功能。

## 截图

<!-- TODO: 添加截图 -->

## 功能特性

- **视频** — 电影/电视剧浏览、详情查看、MPV 播放器播放、观看进度同步
- **音乐** — 专辑/歌曲浏览、后台播放、歌词显示、最近播放/添加
- **漫画** — 漫画系列浏览、角色信息、收藏管理
- **电子书** — 电子书系列浏览、阅读进度、统计信息
- **首页** — 自动轮播推荐、可自定义板块顺序与显隐
- **设置** — 主题切换（亮色/暗色）、隐私模式、媒体库管理、内容扫描
- **认证** — 密码登录、Token 鉴权、401 自动跳转登录

## 技术栈

| 类别 | 技术 |
|------|------|
| 语言 | Kotlin 2.0 |
| UI | Jetpack Compose + Material 3 |
| 导航 | Navigation Compose |
| 网络 | Retrofit 2 + OkHttp 4 + Gson |
| 图片 | Coil |
| 播放器 | MPV (via jniLibs) |
| 最低版本 | Android 7.0 (SDK 24) |
| 目标版本 | Android 15 (SDK 35) |

## 项目结构

```
app/src/main/java/com/fryfrog/hub/
├── data/
│   ├── model/          # 数据模型 (SeriesDTO, AlbumGroup, ComicDTO 等)
│   ├── remote/         # API 接口 (FryfrogApi) + Retrofit 配置
│   └── repository/     # 数据层
├── player/
│   ├── MpvPlayer.kt    # MPV 视频播放器封装
│   └── MusicPlayer.kt  # 音乐播放器
├── service/
│   └── MusicService.kt # 前台音乐播放服务
├── ui/
│   ├── components/     # 可复用 Compose 组件
│   ├── home/           # 首页 (轮播 + 板块)
│   ├── login/          # 登录页
│   ├── music/          # 音乐播放页
│   ├── player/         # 视频播放页
│   ├── settings/       # 设置页 + 媒体库管理
│   └── theme/          # 颜色、字体、尺寸定义
├── util/               # PrefsManager
├── FryfrogHubApplication.kt
└── MainActivity.kt
```

## 构建

```bash
# Debug 版本
./gradlew assembleDebug

# Release 版本
./gradlew assembleRelease
```

生成的 APK 位于 `app/build/outputs/apk/`，文件名格式为 `fryfrog-hub-<version>-arm64.apk`。

> 仅生成 `arm64-v8a` 架构的 APK。

## 配置

连接 Fryfrog Hub 后端服务，在登录页输入：

- **服务器地址** — 后端服务 URL（如 `http://192.168.1.100:20058`）
- **密码** — 服务端配置的访问密码

## 权限

| 权限 | 用途 |
|------|------|
| `INTERNET` | 访问后端 API |
| `ACCESS_NETWORK_STATE` | 网络状态检测 |
| `FOREGROUND_SERVICE` | 音乐后台播放 |
| `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | 媒体播放前台服务 |
| `POST_NOTIFICATIONS` | 通知栏控制 |

## License

<!-- TODO: 添加 License -->
