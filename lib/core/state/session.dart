import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_models.dart';
import '../network/api_client.dart';
import '../network/server_connection.dart';

/// Session: auth + real catalog from fryfrog-hub-api.
class Session extends ChangeNotifier {
  Session(this.connection);

  final ServerConnection connection;

  bool isLoading = false;
  bool isAuthenticated = false;
  bool isLoadingCatalog = false;
  String? error;
  String? catalogError;
  UserProfile? user;
  String? token;
  ApiClient? api;

  HomeContentMode contentMode = HomeContentMode.video;
  bool privacyEnabled = false;
  ThemeModePref themeMode = ThemeModePref.system;

  final List<LibrarySeriesGroup> videoGroups = [];
  final List<SeriesListDto> carouselItems = [];
  final List<MusicLibraryGroup> musicGroups = [];
  final List<MusicSong> songs = [];
  final Map<BookShelfKind, List<BookItem>> books = {
    BookShelfKind.ebook: [],
    BookShelfKind.comic: [],
    BookShelfKind.audiobook: [],
  };

  List<BookItem> booksOf(BookShelfKind kind) => books[kind] ?? const [];

  List<MusicAlbum> get albums =>
      musicGroups.expand((g) => g.albums).toList(growable: false);
  List<MusicArtist> get artists =>
      musicGroups.expand((g) => g.artists).toList(growable: false);

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

    if (token != null && token!.isNotEmpty && connection.activeBaseUrl != null) {
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

  Future<void> loadCatalog() async {
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

      // Books are independent — one kind failing must not block video/music.
      await Future.wait([
        for (final kind in BookShelfKind.values) _loadBooksSafe(client, kind),
      ]);

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
    notifyListeners();
  }

  void setContentMode(HomeContentMode mode) {
    if (contentMode == mode) return;
    contentMode = mode;
    notifyListeners();
  }

  void setPrivacy(bool value) {
    privacyEnabled = value;
    notifyListeners();
  }

  void setThemeMode(ThemeModePref mode) {
    themeMode = mode;
    notifyListeners();
  }
}

enum HomeContentMode { video, music }

enum ThemeModePref {
  system('跟随系统'),
  light('浅色'),
  dark('深色');

  const ThemeModePref(this.title);
  final String title;
}
