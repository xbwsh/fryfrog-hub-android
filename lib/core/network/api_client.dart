import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/media_models.dart';

/// Bodies above this size decode on a background isolate — grouped-series
/// and music-home payloads are hundreds of KB and jsonDecode on the UI
/// thread shows up as dropped frames at startup.
const int _kBigJsonBytes = 64 * 1024;

/// REST client for fryfrog-hub-api. Unwraps `{success,message,data}`.
class ApiClient {
  ApiClient(this.baseUrl, {this.token});

  final String baseUrl;
  String? token;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalized$path').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> _send(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    final uri = _uri(path, query);
    final limit = timeout ?? const Duration(seconds: 15);
    final res = switch (method) {
      'POST' =>
        await http
            .post(uri, headers: _headers, body: jsonEncode(body ?? {}))
            .timeout(limit),
      'PUT' =>
        await http
            .put(uri, headers: _headers, body: jsonEncode(body ?? {}))
            .timeout(limit),
      'DELETE' => await http.delete(uri, headers: _headers).timeout(limit),
      _ => await http.get(uri, headers: _headers).timeout(limit),
    };

    Map<String, dynamic> map;
    try {
      map = res.body.isEmpty
          ? <String, dynamic>{}
          : res.body.length > _kBigJsonBytes
          ? (await Isolate.run(() => jsonDecode(res.body))
                as Map<String, dynamic>)
          : jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(res.statusCode, '响应格式错误 (${res.statusCode})');
    }

    if (res.statusCode == 401) {
      throw ApiException(res.statusCode, _messageOf(map, '登录已过期'));
    }
    if (res.statusCode >= 400) {
      throw ApiException(
        res.statusCode,
        _messageOf(map, '请求失败 (${res.statusCode})'),
      );
    }
    return map;
  }

  /// 业务信封校验。
  ///
  /// 后端 `ApiResponse{success,message,data}` 用 `ApiResponse.error()` 返回
  /// 校验失败时是 **HTTP 200 + success=false**（FastAPI 异常处理器那条路径才是
  /// 4xx/5xx），所以 HTTP 层的 [ApiException] 根本拦不到——必须再看一眼信封。
  void _ensureSuccess(Map<String, dynamic> json) {
    if (json['success'] == false) {
      throw ApiException(400, json['message'] as String? ?? '请求失败');
    }
  }

  /// 错误体里可直接展示的文案。
  /// FastAPI 的 `detail` 既可能是字符串，也可能是校验错误数组——
  /// 直接 `as String?` 会抛类型错误，把真正的业务异常盖掉。
  static String _messageOf(Map<String, dynamic> json, String fallback) {
    final raw = json['message'] ?? json['detail'];
    if (raw is String && raw.isNotEmpty) return raw;
    if (raw is List) {
      final parts = <String>[
        for (final e in raw)
          if (e is Map && e['msg'] is String) e['msg'] as String,
      ];
      if (parts.isNotEmpty) return parts.join('; ');
    }
    return fallback;
  }

  /// [_send] + [_ensureSuccess]。
  ///
  /// **所有 `Future<void>` 写接口必须走这里**：只 `await _send(...)` 时，
  /// 后端把业务校验失败包在 200 里（如「filePath 不能为空」「系列没有 TMDB ID」）
  /// 会一路静默通过，UI 照样提示"已设置/已保存"，实际什么都没写。
  Future<void> _sendChecked(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    final json = await _send(
      path,
      method: method,
      body: body,
      query: query,
      timeout: timeout,
    );
    _ensureSuccess(json);
  }

  T _unwrap<T>(Map<String, dynamic> json, T? Function(Object? raw) parse) {
    _ensureSuccess(json);
    final data = parse(json['data']);
    if (data == null) {
      // 后端 `ApiResponse` 带 `exclude_none`：`ApiResponse.ok(null)` 只回
      // `{"success":true}`，`data` 键整个消失（删进度、解绑、`ok(None)` 一堆）。
      // 声明成可空返回的调用点（`Future<WatchProgress?>` …）要的就是 null，
      // 只有非空 T 才是「响应真的少了字段」。
      if (null is T) return null as T;
      throw ApiException(500, '响应缺少 data');
    }
    return data;
  }

  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    final json = await _send(
      '/api/v1/auth/login',
      method: 'POST',
      body: {'username': username, 'password': password},
    );
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      if (map == null) return null;
      final token = map['token'] as String?;
      if (token == null || token.isEmpty) return null;
      this.token = token;
      final userJson = map['user'] as Map<String, dynamic>?;
      return LoginResult(
        token: token,
        user: userJson == null
            ? UserProfile(id: 0, username: username)
            : UserProfile.fromJson(userJson),
      );
    });
  }

  Future<UserProfile> me() async {
    final json = await _send('/api/v1/auth/me');
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      return map == null ? null : UserProfile.fromJson(map);
    });
  }

  Future<void> logout() async {
    await _sendChecked('/api/v1/auth/logout', method: 'POST');
  }

  /// 修改自己的密码，成功后 token 会被后端作废，需要重新登录。
  /// Backend: `PUT /api/v1/users/me/password`.
  Future<void> changeMyPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _sendChecked(
      '/api/v1/users/me/password',
      method: 'PUT',
      body: {'oldPassword': oldPassword, 'newPassword': newPassword},
    );
  }

  /// 管理员重置指定用户的密码（无需旧密码）。
  /// Backend: `PUT /api/v1/users/{userId}/password`.
  Future<void> resetUserPassword({
    required int userId,
    required String newPassword,
  }) async {
    await _sendChecked(
      '/api/v1/users/$userId/password',
      method: 'PUT',
      body: {'newPassword': newPassword},
    );
  }

  /// 用户列表（管理员）。
  /// Backend: `GET /api/v1/users`.
  Future<List<UserProfile>> fetchUsers() async {
    final json = await _send('/api/v1/users');
    return _unwrap(json, (raw) {
      final list = raw as List? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(UserProfile.fromJson)
          .toList(growable: true);
    });
  }

  /// 创建用户（管理员）。role: `USER` / `ADMIN`.
  /// Backend: `POST /api/v1/users`.
  Future<UserProfile> createUser({
    required String username,
    required String password,
    String? nickname,
    String? role,
  }) async {
    final json = await _send(
      '/api/v1/users',
      method: 'POST',
      body: {
        'username': username,
        'password': password,
        if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
        'role': ?role,
      },
    );
    return _unwrap(
      json,
      (raw) => raw is Map<String, dynamic> ? UserProfile.fromJson(raw) : null,
    );
  }

  /// 更新用户（管理员）。空字段保留原值。
  /// Backend: `PUT /api/v1/users/{userId}`.
  Future<UserProfile> updateUser(
    int userId, {
    String? nickname,
    String? avatar,
    String? role,
    bool? enabled,
  }) async {
    final json = await _send(
      '/api/v1/users/$userId',
      method: 'PUT',
      body: {
        'nickname': ?nickname,
        'avatar': ?avatar,
        'role': ?role,
        'enabled': ?enabled,
      },
    );
    return _unwrap(
      json,
      (raw) => raw is Map<String, dynamic> ? UserProfile.fromJson(raw) : null,
    );
  }

  /// 删除用户（管理员）。
  /// Backend: `DELETE /api/v1/users/{userId}`.
  Future<void> deleteUser(int userId) async {
    await _sendChecked('/api/v1/users/$userId', method: 'DELETE');
  }

  /// 查询用户被分配的媒体库 ID（管理员）。
  /// Backend: `GET /api/v1/users/{userId}/libraries`.
  Future<List<int>> fetchUserLibraries(int userId) async {
    final json = await _send('/api/v1/users/$userId/libraries');
    return _unwrap(json, (raw) {
      final list = raw as List? ?? const [];
      return [for (final e in list) (e as num?)?.toInt() ?? 0];
    });
  }

  /// 保存用户的媒体库授权（全量替换）。
  /// Backend: `PUT /api/v1/users/{userId}/libraries`.
  Future<List<int>> assignUserLibraries(
    int userId,
    List<int> libraryIds,
  ) async {
    final json = await _send(
      '/api/v1/users/$userId/libraries',
      method: 'PUT',
      body: {'libraryIds': libraryIds},
    );
    return _unwrap(json, (raw) {
      final list = raw as List? ?? const [];
      return [for (final e in list) (e as num?)?.toInt() ?? 0];
    });
  }

  /// Grouped series are paged **per library** (backend slices every library
  /// with the same page/size, size clamped to 1..100). Walking all pages is
  /// required — a single call silently truncates each library at `size`
  /// items, which cut a 516-card library view down to 151.
  Future<List<LibrarySeriesGroup>> fetchGroupedSeries() async {
    const size = 100;
    final info = <int, LibrarySeriesGroup>{};
    final seriesByLib = <int, List<SeriesListDto>>{};
    final standaloneByLib = <int, List<SeriesListDto>>{};

    for (var page = 0; page < 100; page++) {
      final json = await _send(
        '/api/v1/video/series/grouped-by-library',
        query: {'page': '$page', 'size': '$size'},
      );
      final batch = _unwrap(json, (raw) {
        final list = raw as List? ?? const [];
        return list
            .whereType<Map<String, dynamic>>()
            .map(LibrarySeriesGroup.fromJson)
            .toList(growable: true);
      });
      if (batch.isEmpty) break;
      for (final g in batch) {
        info.putIfAbsent(g.libraryId, () => g);
        seriesByLib
            .putIfAbsent(g.libraryId, () => <SeriesListDto>[])
            .addAll(g.series);
        standaloneByLib
            .putIfAbsent(g.libraryId, () => <SeriesListDto>[])
            .addAll(g.standaloneVideos);
      }
    }

    return [
      for (final lib in info.values)
        LibrarySeriesGroup(
          libraryId: lib.libraryId,
          libraryName: lib.libraryName,
          libraryPath: lib.libraryPath,
          subType: lib.subType,
          series: seriesByLib[lib.libraryId] ?? const [],
          standaloneVideos: standaloneByLib[lib.libraryId] ?? const [],
        ),
    ];
  }

  /// 单库搜索，返回与首页库分组同构的结果（series + standaloneVideos）。
  /// Backend: `GET /api/v1/video/search/library?libraryId=&q=&page=&size=`.
  /// 两段各自按 size 截断，搜索场景一次取首页即可覆盖绝大多数命中。
  Future<LibrarySeriesGroup> searchInLibrary({
    required int libraryId,
    required String q,
    int page = 0,
    int size = 100,
  }) async {
    final json = await _send(
      '/api/v1/video/search/library',
      query: {
        'libraryId': '$libraryId',
        'q': q,
        'page': '$page',
        'size': '$size',
      },
    );
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      return map == null ? null : LibrarySeriesGroup.fromJson(map);
    });
  }

  Future<List<MusicLibraryGroup>> fetchMusicHome() async {
    final json = await _send('/api/v1/music/home');
    return _unwrap(json, (raw) {
      final list = raw as List? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(MusicLibraryGroup.fromJson)
          .toList(growable: false);
    });
  }

  Future<PageResponse<MusicSong>> fetchMusicSongs({
    int page = 0,
    int size = 50,
  }) async {
    final json = await _send(
      '/api/v1/music/songs',
      query: {'page': '$page', 'size': '$size'},
    );
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      return map == null
          ? null
          : PageResponse.fromJson(map, MusicSong.fromJson);
    });
  }

  /// List ebooks / comics / audiobooks. Backend: `GET /api/v1/{ebooks|comics|audiobooks}`.
  Future<PageResponse<BookItem>> fetchBooks(
    BookShelfKind kind, {
    String? q,
    int page = 0,
    int size = 50,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'size': '$size',
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
    };
    final json = await _send(kind.basePath, query: query);
    return _unwrap(json, (raw) {
      if (raw is List) {
        final items = raw
            .whereType<Map<String, dynamic>>()
            .map(BookItem.fromJson)
            .toList(growable: false);
        return PageResponse(
          content: items,
          page: page,
          size: size,
          totalElements: items.length,
          totalPages: items.isEmpty ? 0 : 1,
        );
      }
      final map = raw as Map<String, dynamic>?;
      return map == null ? null : PageResponse.fromJson(map, BookItem.fromJson);
    });
  }

  Future<BookDetail> fetchBookDetail(BookShelfKind kind, int id) async {
    final json = await _send(kind.detailPath(id));
    final detail = _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      return map == null ? null : BookDetail.fromJson(map);
    });
    // Ebook detail has no embedded TOC — TXT reads via a side endpoint.
    // 只取第一页目录（默认 300 章），避免几千章的网文一次性全量渲染卡顿；
    // 阅读器打开时再按需补拉完整目录（见 _loadReaderChapters）。
    if (kind == BookShelfKind.ebook &&
        detail.chapters.isEmpty &&
        detail.isReadableText) {
      try {
        final page = await fetchEbookChapterPage(id, page: 0);
        if (page.content.isNotEmpty) {
          return detail.withChapters(page.content, totalChapters: page.totalElements);
        }
      } catch (_) {
        // TOC failure must not break the detail page — just no read entry.
      }
    }
    return detail;
  }

  /// TXT online reading: paginated chapter TOC (character offsets live server-side).
  /// Backend: `GET /api/v1/ebooks/{id}/chapters?page=&size=`.
  Future<PageResponse<BookChapter>> fetchEbookChapterPage(
    int bookId, {
    int page = 0,
    int size = 300,
  }) async {
    final json = await _send(
      '/api/v1/ebooks/$bookId/chapters',
      query: {'page': '$page', 'size': '$size'},
    );
    return _unwrap(json, (raw) {
      if (raw is List) {
        // 旧后端没有分页参数：整包返回数组，包装成单页保持兼容。
        final items = raw
            .whereType<Map<String, dynamic>>()
            .map(_chapterFromJson)
            .toList(growable: false);
        return PageResponse(
          content: items,
          page: page,
          size: size,
          totalElements: items.length,
          totalPages: items.isEmpty ? 0 : 1,
        );
      }
      final map = raw as Map<String, dynamic>?;
      return map == null
          ? null
          : PageResponse.fromJson(map, _chapterFromJson);
    });
  }

  static BookChapter _chapterFromJson(Map<String, dynamic> m) {
    final index = (m['index'] as num?)?.toInt() ?? 0;
    return BookChapter(
      id: index,
      chapterIndex: index,
      title: m['title'] as String?,
    );
  }

  /// TXT online reading: chapter TOC (character offsets live server-side).
  /// Backend: `GET /api/v1/ebooks/{id}/chapters`.
  Future<List<BookChapter>> fetchEbookChapters(int bookId) async {
    final json = await _send('/api/v1/ebooks/$bookId/chapters');
    return _unwrap(json, (raw) {
      final list = raw as List? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(_chapterFromJson)
          .toList(growable: false);
    });
  }

  /// TXT online reading: one chapter's body.
  /// Backend: `GET /api/v1/ebooks/{id}/content?chapterIndex=`.
  Future<EbookChapterContent> fetchEbookChapterContent(
    int bookId, {
    required int chapterIndex,
  }) async {
    final json = await _send(
      '/api/v1/ebooks/$bookId/content',
      query: {'chapterIndex': '$chapterIndex'},
    );
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      return map == null ? null : EbookChapterContent.fromJson(map);
    });
  }

  /// Backend: `PUT /api/v1/ebooks/{id}/progress`.
  Future<void> saveEbookProgress(
    int bookId, {
    required double positionPercent,
    required int chapterIndex,
  }) async {
    await _sendChecked(
      '/api/v1/ebooks/$bookId/progress',
      method: 'PUT',
      body: {'positionPercent': positionPercent, 'chapterIndex': chapterIndex},
    );
  }

  Future<List<ScrapeProviderInfo>> fetchScrapeProviders(
    BookShelfKind kind,
  ) async {
    final json = await _send('${kind.basePath}/scrape/providers');
    return _unwrap(json, (raw) {
      final list = raw as List? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(ScrapeProviderInfo.fromJson)
          .toList(growable: false);
    });
  }

  /// Admin-only. `source` null = aggregate all providers.
  Future<List<ScrapeResult>> searchScrape(
    BookShelfKind kind, {
    required String q,
    String? source,
  }) async {
    final json = await _send(
      '${kind.basePath}/scrape/search',
      query: {
        'q': q.trim(),
        if (source != null && source.isNotEmpty) 'source': source,
      },
    );
    return _unwrap(json, (raw) {
      final list = raw as List? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(ScrapeResult.fromJson)
          .toList(growable: false);
    });
  }

  Future<void> bindScrape(
    BookShelfKind kind, {
    required int id,
    required String source,
    required String sourceId,
  }) async {
    await _sendChecked(
      '${kind.detailPath(id)}/scrape/bind',
      method: 'POST',
      body: {'source': source, 'sourceId': sourceId},
    );
  }

  Future<void> unbindScrape(BookShelfKind kind, {required int id}) async {
    await _sendChecked('${kind.detailPath(id)}/scrape/unbind', method: 'POST');
  }

  /// Signed page URLs for one comic chapter.
  /// Backend: `GET /api/v1/comics/chapters/{chapterId}/pages`.
  Future<List<String>> fetchComicChapterPages(int chapterId) async {
    final json = await _send('/api/v1/comics/chapters/$chapterId/pages');
    return _unwrap(json, (raw) {
      final list = raw as List? ?? const [];
      return list.whereType<String>().toList(growable: false);
    });
  }

  /// Backend: `PUT /api/v1/comics/{id}/progress`.
  Future<ReadingProgress?> saveComicProgress(
    int comicId, {
    int? chapterIndex,
    int? pageIndex,
  }) async {
    final body = <String, dynamic>{};
    if (chapterIndex != null) body['chapterIndex'] = chapterIndex;
    if (pageIndex != null) body['pageIndex'] = pageIndex;
    final json = await _send(
      '/api/v1/comics/$comicId/progress',
      method: 'PUT',
      body: body,
    );
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      return map == null ? null : ReadingProgress.fromJson(map);
    });
  }

  /// Series or standalone movie/TV detail.
  /// Backend: `GET /api/v1/video/series/{id}?type=series|standalone`.
  Future<SeriesDetail> fetchSeriesDetail(int id, {String? type}) async {
    final json = await _send(
      '/api/v1/video/series/$id',
      query: {if (type != null && type.isNotEmpty) 'type': type},
    );
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      return map == null ? null : SeriesDetail.fromJson(map);
    });
  }

  /// Backend: `GET /api/v1/video/{id}`.
  Future<VideoItem> fetchVideoDetail(int id) async {
    final json = await _send('/api/v1/video/$id');
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      return map == null ? null : VideoItem.fromJson(map);
    });
  }

  Future<List<VideoActorDto>> fetchVideoActors(int id) async {
    final json = await _send('/api/v1/video/$id/actors');
    return _unwrap(json, (raw) {
      final list = raw as List? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(VideoActorDto.fromJson)
          .toList(growable: false);
    });
  }

  /// Backend: `PUT /api/v1/video/{id}/progress` `{position, duration}`.
  Future<WatchProgress?> saveWatchProgress(
    int videoId, {
    required double position,
    double? duration,
  }) async {
    final body = <String, dynamic>{'position': position};
    if (duration != null) body['duration'] = duration;
    final json = await _send(
      '/api/v1/video/$videoId/progress',
      method: 'PUT',
      body: body,
    );
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      return map == null ? null : WatchProgress.fromJson(map);
    });
  }

  /// Backend: `PUT /api/v1/video/{id}/watched`.
  Future<WatchProgress?> setWatched(
    int videoId, {
    required bool completed,
  }) async {
    final json = await _send(
      '/api/v1/video/$videoId/watched',
      method: 'PUT',
      body: {'completed': completed},
    );
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      return map == null ? null : WatchProgress.fromJson(map);
    });
  }

  Future<void> deleteWatchProgress(int videoId) async {
    await _sendChecked('/api/v1/video/$videoId/progress', method: 'DELETE');
  }

  /// Backend: `PUT /api/v1/video/{id}/favorite?status=true`.
  Future<void> setVideoFavorite(int id, {required bool status}) async {
    await _sendChecked(
      '/api/v1/video/$id/favorite',
      method: 'PUT',
      query: {'status': '$status'},
    );
  }

  /// Backend: `PUT /api/v1/video/series/{id}/favorite?status=true`.
  Future<void> setSeriesFavorite(int id, {required bool status}) async {
    await _sendChecked(
      '/api/v1/video/series/$id/favorite',
      method: 'PUT',
      query: {'status': '$status'},
    );
  }

  /// Prefer DTO-provided signed stream URL; fall back to unsigned path.
  String videoStreamUrl(VideoItem video) {
    final signed = video.streamUrl;
    if (signed != null && signed.isNotEmpty) return resolveUrl(signed);
    return resolveUrl('/api/v1/video/${video.id}/stream');
  }

  /// Relative paths like `/api/v1/video/2/cover` → absolute URL.
  String resolveUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return '$normalized${path.startsWith('/') ? '' : '/'}$path';
  }

  // ── Media library admin ──────────────────────────────────────────────

  /// Backend: `GET /api/v1/media-libraries`.
  Future<List<MediaLibrary>> fetchMediaLibraries() async {
    final json = await _send('/api/v1/media-libraries');
    return _unwrap(json, (raw) {
      final list = raw as List? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(MediaLibrary.fromJson)
          .toList(growable: false);
    });
  }

  /// Backend: `POST /api/v1/media-libraries`.
  Future<MediaLibrary> createMediaLibrary({
    required String name,
    required String path,
    String type = 'VIDEO',
    String? subType,
    bool enabled = true,
    bool enableScraping = true,
    bool isAdult = false,
    String? description,
  }) async {
    final json = await _send(
      '/api/v1/media-libraries',
      method: 'POST',
      body: {
        'name': name,
        'path': path,
        'type': type,
        'subType': ?subType,
        'enabled': enabled,
        'enableScraping': enableScraping,
        'isAdult': isAdult,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      return map == null ? null : MediaLibrary.fromJson(map);
    });
  }

  /// Backend: `PUT /api/v1/media-libraries/{id}`. Null fields keep old value.
  Future<MediaLibrary> updateMediaLibrary(
    int id, {
    String? name,
    String? path,
    String? type,
    String? subType,
    bool? enabled,
    bool? enableScraping,
    bool? isAdult,
    String? description,
    int? sortOrder,
  }) async {
    final json = await _send(
      '/api/v1/media-libraries/$id',
      method: 'PUT',
      body: {
        'name': ?name,
        'path': ?path,
        'type': ?type,
        'subType': ?subType,
        'enabled': ?enabled,
        'enableScraping': ?enableScraping,
        'isAdult': ?isAdult,
        'description': ?description,
        'sortOrder': ?sortOrder,
      },
    );
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      return map == null ? null : MediaLibrary.fromJson(map);
    });
  }

  /// Backend: `DELETE /api/v1/media-libraries/{id}`.
  Future<void> deleteMediaLibrary(int id) async {
    await _sendChecked('/api/v1/media-libraries/$id', method: 'DELETE');
  }

  /// Backend: `PUT /api/v1/media-libraries/{id}/toggle`.
  Future<MediaLibrary> toggleMediaLibrary(int id) async {
    final json = await _send(
      '/api/v1/media-libraries/$id/toggle',
      method: 'PUT',
    );
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      return map == null ? null : MediaLibrary.fromJson(map);
    });
  }

  /// Backend: `POST /api/v1/media-libraries/scan`. Returns enabled count.
  Future<int> scanAllMediaLibraries() async {
    final json = await _send('/api/v1/media-libraries/scan', method: 'POST');
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      return (map?['libraryCount'] as num?)?.toInt() ?? 0;
    });
  }

  /// Backend: `POST /api/v1/media-libraries/{id}/scan`.
  Future<void> scanMediaLibrary(int id) async {
    await _sendChecked('/api/v1/media-libraries/$id/scan', method: 'POST');
  }

  /// Backend: `GET /api/v1/media-libraries/scan/progress`.
  Future<List<LibraryScanProgress>> fetchLibraryScanProgress() async {
    final json = await _send('/api/v1/media-libraries/scan/progress');
    return _unwrap(json, (raw) {
      final list = raw as List? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(LibraryScanProgress.fromJson)
          .toList(growable: false);
    });
  }

  /// Backend: `GET /api/v1/media-libraries/{id}/pipeline-progress`.
  Future<LibraryPipelineProgress> fetchLibraryPipelineProgress(int id) async {
    final json = await _send('/api/v1/media-libraries/$id/pipeline-progress');
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      return map == null ? null : LibraryPipelineProgress.fromJson(map);
    });
  }

  /// Backend: `GET /api/v1/media-libraries/{id}/stale-records`.
  /// 残留体检：总数 + 样本（含文件名与路径，供清理前确认）。
  Future<StaleRecords> fetchStaleRecords(int libraryId) async {
    final json = await _send(
      '/api/v1/media-libraries/$libraryId/stale-records',
    );
    return _unwrap(json, (raw) {
          final map = raw as Map<String, dynamic>?;
          return map == null ? null : StaleRecords.fromJson(map);
        }) ??
        const StaleRecords();
  }

  /// Backend: `POST /api/v1/media-libraries/{id}/purge-stale`.
  /// 返回删除条数；[dryRun] 只统计。后端带磁盘护栏，异常时会拒绝并返回 0。
  Future<int> purgeStaleRecords(int libraryId, {bool dryRun = false}) async {
    final json = await _send(
      '/api/v1/media-libraries/$libraryId/purge-stale',
      method: 'POST',
      query: {'dryRun': '$dryRun'},
    );
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      return (map?['deleted'] as num?)?.toInt() ?? 0;
    });
  }

  /// Backend: `POST /api/v1/video/tmdb/rescrape-library/{id}`.
  /// 安全刷新：只处理已绑定视频，用已有 TMDB ID 拉取，不搜索、不清绑定。
  Future<String> refreshLibraryMetadata(int libraryId) async {
    final json = await _send(
      '/api/v1/video/tmdb/rescrape-library/$libraryId',
      method: 'POST',
    );
    return _unwrap(json, (raw) => raw is String ? raw : '已启动') ?? '已启动';
  }

  /// Backend: `POST /api/v1/video/nfo/regenerate-all?libraryId=`.
  /// 后台任务，立即返回提示语；进度走 `fetchPipelineProgress`。
  Future<String> regenerateNfo({int? libraryId}) async {
    final json = await _send(
      '/api/v1/video/nfo/regenerate-all',
      method: 'POST',
      query: {if (libraryId != null) 'libraryId': '$libraryId'},
    );
    return _unwrap(json, (raw) => raw is String ? raw : '已启动') ?? '已启动';
  }

  /// Backend: `GET /api/v1/media-libraries/browse?path=`.
  /// Null/empty path lists the server's disk roots.
  Future<List<LibraryDirItem>> browseLibraryDirs({String? path}) async {
    final json = await _send(
      '/api/v1/media-libraries/browse',
      query: path == null || path.isEmpty ? null : {'path': path},
    );
    return _unwrap(json, (raw) {
      final list = raw as List? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(LibraryDirItem.fromJson)
          .toList(growable: false);
    });
  }

  // ── Video admin (TMDB / covers / logo) ───────────────────────────────

  /// Backend: `GET /api/v1/video/unscraped` — videos with `tmdbId == null`,
  /// same page shape as the search results (`_page_videos`); [libraryId]
  /// scopes the backlog to a single library.
  Future<PageResponse<VideoItem>> fetchUnscrapedVideos({
    int page = 0,
    int size = 20,
    int? libraryId,
  }) async {
    final json = await _send(
      '/api/v1/video/unscraped',
      query: {
        'page': '$page',
        'size': '$size',
        if (libraryId != null) 'libraryId': '$libraryId',
      },
    );
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      return map == null
          ? null
          : PageResponse.fromJson(map, VideoItem.fromJson);
    });
  }

  /// Backend: `GET /api/v1/video/tmdb/search?q=`.
  Future<List<TmdbSearchItem>> searchTmdb(String q) async {
    final json = await _send(
      '/api/v1/video/tmdb/search',
      query: {'q': q.trim()},
    );
    return _unwrap(json, (raw) {
      final list = raw as List? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(TmdbSearchItem.fromJson)
          .toList(growable: false);
    });
  }

  /// Async bind job — poll `fetchScrapeProgress('bind:{videoId}')` after this.
  /// Backend: `POST /api/v1/video/{id}/tmdb/bind`.
  Future<void> bindTmdb(
    int videoId, {
    required int tmdbId,
    required String mediaType,
  }) async {
    await _sendChecked(
      '/api/v1/video/$videoId/tmdb/bind',
      method: 'POST',
      body: {'tmdbId': tmdbId, 'mediaType': mediaType},
    );
  }

  /// Backend: `POST /api/v1/video/{id}/tmdb/unbind` → `{tmdbId?, unbound}`.
  Future<int> unbindTmdb(int videoId) async {
    final json = await _send(
      '/api/v1/video/$videoId/tmdb/unbind',
      method: 'POST',
    );
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      return (map?['unbound'] as num?)?.toInt() ?? 0;
    });
  }

  /// Backend: `GET /api/v1/video/scrape/progress?module=`.
  Future<ScrapeProgress> fetchScrapeProgress(String module) async {
    final json = await _send(
      '/api/v1/video/scrape/progress',
      query: {'module': module},
    );
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      return map == null ? null : ScrapeProgress.fromJson(map);
    });
  }

  /// Backend: `PUT /api/v1/video/series/{id}/metadata`. Null fields unchanged.
  Future<void> updateSeriesMetadata(int id, Map<String, dynamic> body) async {
    await _sendChecked(
      '/api/v1/video/series/$id/metadata',
      method: 'PUT',
      body: body,
    );
  }

  /// Backend: `PUT /api/v1/video/{id}/metadata`. Null fields unchanged.
  Future<void> updateVideoMetadata(int id, Map<String, dynamic> body) async {
    await _sendChecked('/api/v1/video/$id/metadata', method: 'PUT', body: body);
  }

  /// Re-download covers from TMDB. `data.success` is a **string**.
  /// Backend: `POST /api/v1/video/{id}/covers`.
  Future<bool> downloadVideoCovers(int videoId) async {
    // 路径是 refresh-covers 而非 covers：后端中间件把 `.*/cover` 当静态图片
    // 资源提前放行（不写当前用户），旧路径 /covers 的管理员校验永远失败。
    final json = await _send(
      '/api/v1/video/$videoId/refresh-covers',
      method: 'POST',
    );
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      final success = map?['success'];
      if (success is bool) return success;
      return success?.toString() == 'true';
    });
  }

  /// 本集在 TMDB 的横屏图（本集剧照 still）候选。
  /// Backend: `GET /api/v1/video/{id}/cover-options`.
  Future<List<CoverOption>> fetchVideoCoverOptions(int videoId) async {
    final json = await _send('/api/v1/video/$videoId/cover-options');
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      final list = map?['options'] as List? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(CoverOption.fromJson)
          .toList(growable: false);
    });
  }

  /// 把选中的 TMDB 图应用为本集横屏封面。
  /// Backend: `POST /api/v1/video/{id}/cover` `{filePath}`.
  Future<void> setVideoCover(int videoId, {required String filePath}) async {
    await _sendChecked(
      '/api/v1/video/$videoId/cover',
      method: 'POST',
      body: {'filePath': filePath},
    );
  }

  /// 某层级的 TMDB 图片候选。
  /// Backend: `GET /api/v1/video/{id}/tmdb-images?level=series|season|episode`.
  Future<TmdbImageOptions> fetchTmdbImages(
    int videoId, {
    required String level,
  }) async {
    final json = await _send(
      '/api/v1/video/$videoId/tmdb-images',
      query: {'level': level},
    );
    return _unwrap(json, (raw) {
          final map = raw as Map<String, dynamic>?;
          return map == null ? null : TmdbImageOptions.fromJson(map);
        }) ??
        const TmdbImageOptions(level: 'episode');
  }

  /// 把选中的 TMDB 图落到指定层级。
  /// Backend: `POST /api/v1/video/{id}/tmdb-image` `{filePath, level, kind}`.
  Future<void> applyTmdbImage(
    int videoId, {
    required String filePath,
    required String level,
    required String kind,
  }) async {
    await _sendChecked(
      '/api/v1/video/$videoId/tmdb-image',
      method: 'POST',
      body: {'filePath': filePath, 'level': level, 'kind': kind},
    );
  }

  /// Generate frame screenshot candidates (sync, a few seconds).
  /// Backend: `POST /api/v1/video/{id}/frames`.
  Future<List<FrameCandidate>> generateFrameCandidates(int videoId) async {
    final json = await _send('/api/v1/video/$videoId/frames', method: 'POST');
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      final list = map?['candidates'] as List? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(FrameCandidate.fromJson)
          .toList(growable: false);
    });
  }

  /// `type` = poster (cover) | fanart (backdrop).
  /// Backend: `POST /api/v1/video/{id}/frames/select`.
  Future<void> selectFrame(
    int videoId, {
    required int index,
    required String type,
  }) async {
    await _sendChecked(
      '/api/v1/video/$videoId/frames/select',
      method: 'POST',
      body: {'index': index, 'type': type},
    );
  }

  /// 下载一张需要鉴权的图片（帧截图等）为字节。
  ///
  /// 帧图的 URL 走签名 + Bearer，不能直接用 `NetworkAsset`；裁剪器又只吃本地
  /// 文件，所以先落一份到缓存目录。
  Future<Uint8List> fetchImageBytes(String path) async {
    final uri = _uri(path);
    // 没 token 时别发 "Bearer null"（会得到含义不明的 401）
    final auth = token;
    if (auth == null || auth.isEmpty) {
      throw ApiException(401, '登录已过期，请重新登录');
    }
    final res = await http
        .get(uri, headers: {'Authorization': 'Bearer $auth'})
        .timeout(const Duration(seconds: 60));
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, '图片下载失败 (${res.statusCode})');
    }
    return res.bodyBytes;
  }

  /// 上传本地图片作为封面/背景。
  ///
  /// [level] = series（总览）| season（季）| episode（单集）；
  /// [kind] = poster（竖版）| backdrop|still（横版）。
  /// 后端会校验格式/大小并统一转 JPEG，失败时 message 可直接展示给用户。
  /// Backend: `POST /api/v1/video/{id}/cover-upload`（multipart）。
  Future<String> uploadCover(
    int videoId, {
    required Uint8List bytes,
    required String filename,
    required String level,
    required String kind,
  }) async {
    final req =
        http.MultipartRequest(
            'POST',
            _uri('/api/v1/video/$videoId/cover-upload'),
          )
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['level'] = level
          ..fields['kind'] = kind
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: filename),
          );

    final streamed = await req.send().timeout(const Duration(seconds: 120));
    final body = await streamed.stream.bytesToString();
    Map<String, dynamic> map;
    try {
      map = body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(streamed.statusCode, '上传响应格式错误');
    }
    // 这条路径没走 `_send`，HTTP 状态码得自己看：401/403/413 的错误体是
    // FastAPI 的 `{detail: ...}`，既没有 `success` 也没有 `data`，`_unwrap`
    // 只会回一句 500「响应缺少 data」——真实状态码和文案全丢了。
    if (streamed.statusCode >= 400) {
      throw ApiException(
        streamed.statusCode,
        _messageOf(map, '上传失败 (${streamed.statusCode})'),
      );
    }
    // 后端校验失败走 success=false + 中文 message，直接透出
    return _unwrap(
      map,
      (raw) => (raw as Map<String, dynamic>?)?['path'] as String?,
    );
  }

  /// Slow (all seasons) — uses a 300s timeout instead of the default 15s.
  /// Backend: `POST /api/v1/video/series/{id}/refresh-season-covers`.
  Future<SeasonRefreshResult> refreshSeasonCovers(int seriesId) async {
    final json = await _send(
      '/api/v1/video/series/$seriesId/refresh-season-covers',
      method: 'POST',
      timeout: const Duration(seconds: 300),
    );
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      return map == null ? null : SeasonRefreshResult.fromJson(map);
    });
  }

  /// Backend: `POST /api/v1/video/{id}/refresh-logo` → `{downloaded}`.
  Future<bool> refreshVideoLogo(int videoId) async {
    final json = await _send(
      '/api/v1/video/$videoId/refresh-logo',
      method: 'POST',
    );
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      return map?['downloaded'] == true;
    });
  }

  /// Backend: `POST /api/v1/video/series/{id}/refresh-logo` → `{downloaded}`.
  Future<bool> refreshSeriesLogo(int seriesId) async {
    final json = await _send(
      '/api/v1/video/series/$seriesId/refresh-logo',
      method: 'POST',
    );
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      return map?['downloaded'] == true;
    });
  }

  /// Backend: `GET /api/v1/video/{id}/logo-options`.
  Future<List<LogoOption>> fetchVideoLogoOptions(int videoId) async {
    final json = await _send('/api/v1/video/$videoId/logo-options');
    return _unwrap(json, (raw) {
      final list = raw as List? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(LogoOption.fromJson)
          .toList(growable: false);
    });
  }

  /// Backend: `GET /api/v1/video/series/{id}/logo-options`.
  Future<List<LogoOption>> fetchSeriesLogoOptions(int seriesId) async {
    final json = await _send('/api/v1/video/series/$seriesId/logo-options');
    return _unwrap(json, (raw) {
      final list = raw as List? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(LogoOption.fromJson)
          .toList(growable: false);
    });
  }

  /// Backend: `POST /api/v1/video/{id}/logo` `{filePath}`.
  Future<void> setVideoLogo(int videoId, {required String filePath}) async {
    await _sendChecked(
      '/api/v1/video/$videoId/logo',
      method: 'POST',
      body: {'filePath': filePath},
    );
  }

  /// Backend: `POST /api/v1/video/series/{id}/logo` `{filePath}`.
  Future<void> setSeriesLogo(int seriesId, {required String filePath}) async {
    await _sendChecked(
      '/api/v1/video/series/$seriesId/logo',
      method: 'POST',
      body: {'filePath': filePath},
    );
  }
}

class LoginResult {
  const LoginResult({required this.token, required this.user});
  final String token;
  final UserProfile user;
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => message;
}
