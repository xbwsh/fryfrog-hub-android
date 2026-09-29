import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/media_models.dart';

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
  }) async {
    final uri = _uri(path, query);
    final res = switch (method) {
      'POST' =>
        await http
            .post(uri, headers: _headers, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 15)),
      'PUT' =>
        await http
            .put(uri, headers: _headers, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 15)),
      'DELETE' =>
        await http
            .delete(uri, headers: _headers)
            .timeout(const Duration(seconds: 15)),
      _ =>
        await http
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 15)),
    };

    Map<String, dynamic> map;
    try {
      map = res.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(res.statusCode, '响应格式错误 (${res.statusCode})');
    }

    if (res.statusCode == 401) {
      throw ApiException(401, map['message'] as String? ?? '登录已过期');
    }
    if (res.statusCode >= 400) {
      throw ApiException(
        res.statusCode,
        map['message'] as String? ?? '请求失败 (${res.statusCode})',
      );
    }
    return map;
  }

  T _unwrap<T>(Map<String, dynamic> json, T? Function(Object? raw) parse) {
    if (json['success'] == false) {
      throw ApiException(400, json['message'] as String? ?? '请求失败');
    }
    final data = parse(json['data']);
    if (data == null) {
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
    await _send('/api/v1/auth/logout', method: 'POST');
  }

  Future<List<LibrarySeriesGroup>> fetchGroupedSeries() async {
    final json = await _send('/api/v1/video/series/grouped-by-library');
    return _unwrap(json, (raw) {
      final list = raw as List? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(LibrarySeriesGroup.fromJson)
          .toList(growable: false);
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
    return _unwrap(json, (raw) {
      final map = raw as Map<String, dynamic>?;
      return map == null ? null : BookDetail.fromJson(map);
    });
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
    await _send(
      '${kind.detailPath(id)}/scrape/bind',
      method: 'POST',
      body: {'source': source, 'sourceId': sourceId},
    );
  }

  Future<void> unbindScrape(BookShelfKind kind, {required int id}) async {
    await _send('${kind.detailPath(id)}/scrape/unbind', method: 'POST');
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
    await _send('/api/v1/video/$videoId/progress', method: 'DELETE');
  }

  /// Backend: `PUT /api/v1/video/{id}/favorite?status=true`.
  Future<void> setVideoFavorite(int id, {required bool status}) async {
    await _send(
      '/api/v1/video/$id/favorite',
      method: 'PUT',
      query: {'status': '$status'},
    );
  }

  /// Backend: `PUT /api/v1/video/series/{id}/favorite?status=true`.
  Future<void> setSeriesFavorite(int id, {required bool status}) async {
    await _send(
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
    await _send('/api/v1/media-libraries/$id', method: 'DELETE');
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
    await _send('/api/v1/media-libraries/$id/scan', method: 'POST');
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
