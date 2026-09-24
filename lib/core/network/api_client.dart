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
        if (token != null && token!.isNotEmpty)
          'Authorization': 'Bearer $token',
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
      'POST' => await http
          .post(uri, headers: _headers, body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 15)),
      'PUT' => await http
          .put(uri, headers: _headers, body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 15)),
      'DELETE' =>
        await http.delete(uri, headers: _headers).timeout(const Duration(seconds: 15)),
      _ => await http.get(uri, headers: _headers).timeout(const Duration(seconds: 15)),
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

  T _unwrap<T>(
    Map<String, dynamic> json,
    T? Function(Object? raw) parse,
  ) {
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

  /// Relative paths like `/api/v1/video/2/cover` → absolute URL.
  String resolveUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return '$normalized${path.startsWith('/') ? '' : '/'}$path';
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
