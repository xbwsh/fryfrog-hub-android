import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_models.dart';
import '../network/api_client.dart';
import '../network/server_connection.dart';
import 'app_prefs.dart';

/// Session: auth + real catalog from fryfrog-hub-api.
///
/// [prefs] rides along for UI access (profile screen); preference changes
/// notify [AppPrefs] only — never this notifier — so catalog updates don't
/// rebuild MaterialApp and vice versa.
class Session extends ChangeNotifier {
  Session(this.connection, this.prefs);

  final ServerConnection connection;
  final AppPrefs prefs;

  bool isLoading = false;
  bool isAuthenticated = false;
  bool isLoadingCatalog = false;
  String? error;
  String? catalogError;
  UserProfile? user;
  String? token;
  ApiClient? api;

  final List<LibrarySeriesGroup> videoGroups = [];
  final List<SeriesListDto> carouselItems = [];
  final List<MusicLibraryGroup> musicGroups = [];
  final List<MusicSong> songs = [];
  final Map<BookShelfKind, List<BookItem>> books = {
    BookShelfKind.ebook: [],
    BookShelfKind.comic: [],
    BookShelfKind.audiobook: [],
  };

  /// Bumped whenever catalog data is replaced; lets widgets memoize
  /// derived stats without recomputing on every unrelated notify.
  int catalogVersion = 0;

  List<BookItem> booksOf(BookShelfKind kind) => books[kind] ?? const [];

  List<MusicAlbum> _albums = const [];
  List<MusicArtist> _artists = const [];

  /// Cached expansions of [musicGroups] — rebuilt on load/logout instead
  /// of on every build (the old getters allocated two lists per notify).
  List<MusicAlbum> get albums => _albums;
  List<MusicArtist> get artists => _artists;

  void _rebuildMusicCaches() {
    _albums = musicGroups.expand((g) => g.albums).toList(growable: false);
    _artists = musicGroups.expand((g) => g.artists).toList(growable: false);
  }

  static const _kToken = 'auth.token';
  static const _kPublic = 'server.publicHost';
  static const _kLan = 'server.lanHost';
  static const _kPort = 'server.port';
  static const _kScheme = 'server.scheme';
  static const _kUser = 'auth.username';

  String? resolveImage(String? path) {
    final client = api;
    if (client != null) return client.resolveUrl(path);
    final base = connection.activeBaseUrl;
    if (base == null || path == null || path.isEmpty) return path;
    if (path.startsWith('http')) return path;
    return '$base${path.startsWith('/') ? '' : '/'}$path';
  }

  /// 登录页回填用：返回已保存的服务器配置与上次用户名，
  /// 从未保存过时使用默认值（frostine.top / 20058 / http / admin）。
  Future<({String publicHost, String lanHost, String port, String scheme, String username})>
      savedLoginDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      publicHost: prefs.getString(_kPublic) ?? 'frostine.top',
      lanHost: prefs.getString(_kLan) ?? '',
      port: prefs.getString(_kPort) ?? '20058',
      scheme: prefs.getString(_kScheme) ?? 'http',
      username: prefs.getString(_kUser) ?? 'admin',
    );
  }

  Future<void> restoreSessionDeferred() async {
    isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_kToken);
    final publicHost = prefs.getString(_kPublic) ?? '';
    final lanHost = prefs.getString(_kLan) ?? '';
    final port = prefs.getString(_kPort) ?? '20058';
    final scheme = prefs.getString(_kScheme) ?? 'http';
    if (publicHost.isNotEmpty || lanHost.isNotEmpty) {
      connection.apply(
        scheme: scheme,
        port: port,
        publicHost: publicHost,
        lanHost: lanHost,
      );
    }

    if (token != null &&
        token!.isNotEmpty &&
        connection.activeBaseUrl != null) {
      // 恢复会话前先探测 LAN：换网/IP 变了导致 LAN 不可达时，
      // 自动退回公网而不是直接掉登录。
      await connection.refreshActiveMode();
      api = ApiClient(connection.activeBaseUrl!, token: token);
      try {
        user = await api!.me();
        isAuthenticated = true;
        isLoading = false;
        notifyListeners();
        await loadCatalog();
        return;
      } catch (e) {
        debugPrint('restoreSession failed: $e');
        isAuthenticated = false;
        token = null;
        api = null;
      }
    }

    isLoading = false;
    notifyListeners();
  }

  void restoreSession() {
    Future.microtask(restoreSessionDeferred);
  }

  Future<bool> login({
    required String publicHost,
    String lanHost = '',
    required String scheme,
    required String port,
    required String username,
    required String password,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();

    connection.apply(
      scheme: scheme,
      port: port,
      publicHost: publicHost,
      lanHost: lanHost,
    );

    // LAN 可达优先走 LAN，不可达自动退回公网（对齐 iOS）。
    await connection.refreshActiveMode();

    final base = connection.activeBaseUrl;
    if (base == null) {
      error = '请填写服务器地址';
      isLoading = false;
      notifyListeners();
      return false;
    }

    api = ApiClient(base);

    try {
      final result = await api!.login(
        username: username.trim(),
        password: password,
      );
      token = result.token;
      user = result.user;
      isAuthenticated = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kToken, result.token);
      await prefs.setString(_kPublic, publicHost.trim());
      await prefs.setString(_kLan, lanHost.trim());
      await prefs.setString(_kPort, port.trim());
      await prefs.setString(_kScheme, scheme);
      await prefs.setString(_kUser, username.trim());

      isLoading = false;
      notifyListeners();
      await loadCatalog();
      return true;
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = '登录失败：$e';
    }

    isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void>? _loadCatalogInflight;

  Future<void> loadCatalog() {
    // Retry button, scan completion etc. can race — share one in-flight
    // request instead of double-fetching and fighting over the lists.
    final inflight = _loadCatalogInflight;
    if (inflight != null) return inflight;
    late Future<void> future;
    future = _loadCatalogBody().whenComplete(() {
      if (identical(_loadCatalogInflight, future)) {
        _loadCatalogInflight = null;
      }
    });
    _loadCatalogInflight = future;
    return future;
  }

  Future<void> _loadCatalogBody() async {
    final client = api;
    if (client == null) return;
    isLoadingCatalog = true;
    catalogError = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        client.fetchGroupedSeries(),
        client.fetchMusicHome(),
        client.fetchMusicSongs(page: 0, size: 50),
      ]);

      videoGroups
        ..clear()
        ..addAll(results[0] as List<LibrarySeriesGroup>);
      musicGroups
        ..clear()
        ..addAll(results[1] as List<MusicLibraryGroup>);
      songs
        ..clear()
        ..addAll((results[2] as PageResponse<MusicSong>).content);
      _rebuildMusicCaches();

      // Books are independent — one kind failing must not block video/music.
      await Future.wait([
        for (final kind in BookShelfKind.values) _loadBooksSafe(client, kind),
      ]);

      catalogVersion++;
      _rollCarousel();
    } catch (e) {
      catalogError = '$e';
      debugPrint('loadCatalog failed: $e');
    }

    isLoadingCatalog = false;
    notifyListeners();
  }

  Future<void> _loadBooksSafe(ApiClient client, BookShelfKind kind) async {
    try {
      final page = await client.fetchBooks(kind);
      books[kind]!
        ..clear()
        ..addAll(page.content);
    } catch (e) {
      debugPrint('loadBooks $kind failed: $e');
    }
  }

  /// Reload a single shelf kind (e.g. after a scrape bind changed covers).
  Future<void> refreshBooks(BookShelfKind kind) async {
    final client = api;
    if (client == null) return;
    await _loadBooksSafe(client, kind);
    notifyListeners();
  }

  void _rollCarousel() {
    final seen = <int>{};
    final withFanart = <SeriesListDto>[];
    final without = <SeriesListDto>[];
    for (final g in videoGroups) {
      for (final item in g.allItems) {
        if (!seen.add(item.id)) continue;
        if (item.fanartUrl != null && item.fanartUrl!.isNotEmpty) {
          withFanart.add(item);
        } else {
          without.add(item);
        }
      }
    }
    withFanart.shuffle();
    without.shuffle();
    carouselItems
      ..clear()
      ..addAll([...withFanart, ...without].take(10));
  }

  Future<void> logout() async {
    try {
      await api?.logout();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    token = null;
    api = null;
    user = null;
    isAuthenticated = false;
    videoGroups.clear();
    carouselItems.clear();
    musicGroups.clear();
    songs.clear();
    for (final list in books.values) {
      list.clear();
    }
    _rebuildMusicCaches();
    catalogVersion++;
    notifyListeners();
  }

  /// 从服务端刷新当前用户信息（改昵称/角色后同步顶部展示）。
  Future<void> refreshUser() async {
    final client = api;
    if (client == null) return;
    try {
      user = await client.me();
      notifyListeners();
    } catch (e) {
      debugPrint('refreshUser failed: $e');
    }
  }
}
