import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/media_models.dart';
import '../../core/network/gateways.dart';

/// Application-layer controller for TXT ebook reading.
///
/// Owns chapter loading, chrome visibility, scroll fraction, and debounced
/// progress — the screen only paints and forwards gestures.
class EbookReaderController extends ChangeNotifier {
  EbookReaderController({
    required this.gateway,
    required this.bookId,
    required List<BookChapter> chapters,
    this.initialChapterIndex = 0,
  }) : chapters = ([...chapters]
         ..sort((a, b) => a.chapterIndex - b.chapterIndex)) {
    final found = this.chapters.indexWhere(
      (c) => c.chapterIndex == initialChapterIndex,
    );
    _chapterPos = found >= 0 ? found : 0;
    _lastSavedChapter = this.chapters.isEmpty
        ? null
        : this.chapters[_chapterPos].chapterIndex;
    // Seed with the at-open position so merely opening the book does not
    // mark progress dirty (mirrors the comic reader's last-page seed).
    _lastSavedPercent = this.chapters.isEmpty
        ? -1
        : (_chapterPos / this.chapters.length) * 100;
  }

  final EbookGateway gateway;
  final int bookId;
  final List<BookChapter> chapters;

  int _chapterPos = 0;
  bool chromeVisible = true;
  bool loading = true;
  String? error;
  String content = '';
  double _scrollFraction = 0;

  Timer? _debounce;
  bool _dirty = false;
  bool _saving = false;
  double _lastSavedPercent = -1;
  int? _lastSavedChapter;
  bool _disposed = false;

  final int initialChapterIndex;

  int get chapterPos => _chapterPos;
  int get chapterCount => chapters.length;
  BookChapter get chapter => chapters[_chapterPos];
  bool get hasPrevChapter => _chapterPos > 0;
  bool get hasNextChapter => _chapterPos < chapters.length - 1;
  String get chapterLabel => chapter.label;

  /// Whole-book progress 0–100 (chapter position + in-chapter scroll).
  double get positionPercent {
    if (chapterCount == 0) return 0;
    return ((_chapterPos + _scrollFraction) / chapterCount) * 100;
  }

  Future<void> load({int? chapterIndex}) async {
    if (chapters.isEmpty) {
      loading = false;
      error = '暂无章节';
      _notify();
      return;
    }
    if (chapterIndex != null) {
      _chapterPos = chapterIndex.clamp(0, chapters.length - 1);
    }
    loading = true;
    error = null;
    _notify();
    try {
      final body = await gateway.fetchChapterContent(
        bookId,
        chapterIndex: chapter.chapterIndex,
      );
      content = body.text;
      _scrollFraction = 0;
      loading = false;
      _notify();
      markProgressDirty();
    } catch (e) {
      error = '$e';
      loading = false;
      _notify();
    }
  }

  Future<void> goToChapter(int pos) async {
    if (pos < 0 || pos >= chapters.length || pos == _chapterPos) return;
    await load(chapterIndex: pos);
  }

  void toggleChrome() {
    chromeVisible = !chromeVisible;
    _notify();
  }

  /// In-chapter scroll fraction in 0–1, reported by the screen.
  void onScrollFraction(double fraction) {
    final clamped = fraction.clamp(0.0, 1.0);
    if ((clamped - _scrollFraction).abs() < 0.001) return;
    _scrollFraction = clamped;
    markProgressDirty();
  }

  void markProgressDirty() {
    if (chapters.isEmpty) return;
    final pct = positionPercent;
    if ((pct - _lastSavedPercent).abs() < 0.3 &&
        chapter.chapterIndex == _lastSavedChapter) {
      return;
    }
    _dirty = true;
    _lastSavedChapter = chapter.chapterIndex;
    _lastSavedPercent = pct;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), flushProgress);
  }

  Future<void> flushProgress() async {
    if (!_dirty || _saving) return;
    _dirty = false;
    final pct = positionPercent;
    final ci = chapter.chapterIndex;
    _saving = true;
    try {
      await gateway.saveProgress(
        bookId,
        positionPercent: pct,
        chapterIndex: ci,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('save ebook progress failed: $e');
      _dirty = true;
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
