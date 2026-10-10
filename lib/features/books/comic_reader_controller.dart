import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/media_models.dart';
import '../../core/network/gateways.dart';
import '../../core/rules/watch_rules.dart';

/// Application-layer controller for comic chapter reading.
///
/// Owns page loading, mode, chrome visibility, and debounced progress —
/// the screen only paints and forwards gestures.
class ComicReaderController extends ChangeNotifier {
  ComicReaderController({
    required this.gateway,
    required this.comicId,
    required List<BookChapter> chapters,
    this.initialChapterIndex = 0,
    this.initialPageIndex = 0,
  }) : chapters = ([...chapters]
         ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex))) {
    final found = this.chapters.indexWhere(
      (c) => c.chapterIndex == initialChapterIndex,
    );
    _chapterPos = found >= 0 ? found : 0;
    _pageIndex = initialPageIndex < 0 ? 0 : initialPageIndex;
    _lastSavedChapter = this.chapters.isEmpty
        ? null
        : this.chapters[_chapterPos].chapterIndex;
    _lastSavedPage = _pageIndex;
  }

  final ComicGateway gateway;
  final int comicId;
  final List<BookChapter> chapters;

  static const readerModeScroll = 0;
  static const readerModePage = 1;

  int _chapterPos = 0;
  int _pageIndex = 0;
  int _mode = readerModeScroll;
  bool chromeVisible = true;
  bool loading = true;
  String? error;
  List<String> pageUrls = const [];

  Timer? _debounce;
  bool _dirty = false;
  bool _saving = false;
  int? _lastSavedChapter;
  int? _lastSavedPage;
  bool _disposed = false;

  final int initialChapterIndex;
  final int initialPageIndex;

  int get chapterPos => _chapterPos;
  int get pageIndex => _pageIndex;
  int get mode => _mode;
  BookChapter get chapter => chapters[_chapterPos];
  bool get hasPrevChapter => _chapterPos > 0;
  bool get hasNextChapter => _chapterPos < chapters.length - 1;
  String get chapterLabel => chapter.label;
  int get pageCount => pageUrls.length;

  Future<void> loadPages({bool initial = false}) async {
    if (chapters.isEmpty) {
      loading = false;
      error = '暂无章节';
      _notify();
      return;
    }
    loading = true;
    error = null;
    if (!initial) _pageIndex = 0;
    pageUrls = const [];
    _notify();
    try {
      final urls = await gateway.fetchChapterPages(chapter.id);
      pageUrls = urls;
      loading = false;
      if (urls.isEmpty) {
        error = '本话没有可读页面';
      } else {
        _pageIndex = WatchRules.clampPage(_pageIndex, urls.length);
      }
      _notify();
      if (urls.isNotEmpty) markProgressDirty();
    } catch (e) {
      error = '$e';
      loading = false;
      _notify();
    }
  }

  void toggleChrome() {
    chromeVisible = !chromeVisible;
    _notify();
  }

  void setMode(int mode) {
    if (_mode == mode) return;
    _mode = mode;
    chromeVisible = true;
    _notify();
  }

  void goToPage(int index) {
    if (pageUrls.isEmpty) return;
    _pageIndex = WatchRules.clampPage(index, pageUrls.length);
    markProgressDirty();
    _notify();
  }

  void onScrollPageCandidate(int index) {
    if (pageUrls.isEmpty) return;
    final clamped = WatchRules.clampPage(index, pageUrls.length);
    if (clamped == _pageIndex) return;
    _pageIndex = clamped;
    markProgressDirty();
    _notify();
  }

  Future<void> switchChapter(int pos) async {
    if (pos < 0 || pos >= chapters.length || pos == _chapterPos) return;
    await flushProgress();
    _chapterPos = pos;
    _pageIndex = 0;
    _lastSavedChapter = chapters[pos].chapterIndex;
    _lastSavedPage = 0;
    _notify();
    await loadPages();
  }

  void markProgressDirty() {
    if (chapters.isEmpty || pageUrls.isEmpty) return;
    final ci = chapter.chapterIndex;
    final pi = _pageIndex;
    if (ci == _lastSavedChapter && pi == _lastSavedPage) return;
    _dirty = true;
    _lastSavedChapter = ci;
    _lastSavedPage = pi;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), flushProgress);
  }

  Future<void> flushProgress() async {
    if (!_dirty) return;
    _dirty = false;
    final ci = _lastSavedChapter;
    final pi = _lastSavedPage;
    if (ci == null || pi == null || _saving) return;
    _saving = true;
    try {
      await gateway.saveReadingProgress(
        comicId,
        chapterIndex: ci,
        pageIndex: pi,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('save comic progress failed: $e');
    } finally {
      _saving = false;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    unawaited(flushProgress());
    super.dispose();
  }
}
