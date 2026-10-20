import 'package:flutter/material.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/media_models.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../widgets/server_image.dart';
import '../../widgets/mini_player.dart';
import 'comic_reader_screen.dart';
import 'ebook_reader_screen.dart';

/// Detail for a shelf item: metadata, chapters and (admin) scrape binding.
class BookDetailScreen extends StatefulWidget {
  const BookDetailScreen({
    super.key,
    required this.kind,
    required this.bookId,
    required this.session,
  });

  final BookShelfKind kind;
  final int bookId;
  final Session session;

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  BookDetail? _detail;
  String? _error;
  bool _loading = true;

  /// 电子书目录已加载的章数（详情页只加载第一页，其余按"加载更多"追加）。
  int _loadedChapters = 0;
  bool _loadingMore = false;
  AudiobookDetail? _audioDetail;
  String? _audioError;
  bool _audioLoading = false;
  bool _audioStarting = false;
  int _audioRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.kind == BookShelfKind.audiobook) _loadAudioDetail();
  }

  Future<void> _loadAudioDetail() async {
    final api = widget.session.api;
    if (api == null) {
      if (mounted) setState(() => _audioError = '未登录');
      return;
    }
    setState(() {
      _audioLoading = true;
      _audioError = null;
    });
    try {
      final detail = await api.fetchAudiobookDetail(widget.bookId);
      if (!mounted) return;
      setState(() {
        _audioDetail = detail;
        _audioLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _audioError = '$e';
        _audioLoading = false;
      });
    }
  }

  Future<void> _playAudiobook({int? chapterIndex}) async {
    final api = widget.session.api;
    if (api == null || _audioStarting) return;
    final audio = widget.session.audioController;
    if (chapterIndex == null &&
        _audioDetail?.progress?.completed != true &&
        audio?.activeAudiobookId == widget.bookId &&
        (audio?.canResumeAudiobook ?? false)) {
      await audio!.resumeAudiobook();
      return;
    }
    final requestVersion = ++_audioRequestVersion;
    setState(() => _audioStarting = true);
    try {
      // Fetch a fresh signed stream URL on each user selection.
      final detail = await api.fetchAudiobookDetail(widget.bookId);
      if (!mounted || requestVersion != _audioRequestVersion) return;
      setState(() => _audioDetail = detail);
      await widget.session.playAudiobook(detail, chapterIndex: chapterIndex);
      if (!mounted || requestVersion != _audioRequestVersion) return;
      final error = widget.session.audioController?.error;
      if (error != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('播放失败：$error')));
      }
    } catch (e) {
      if (!mounted || requestVersion != _audioRequestVersion) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('开始收听失败：$e')));
    } finally {
      if (mounted && requestVersion == _audioRequestVersion) {
        setState(() => _audioStarting = false);
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final client = widget.session.api;
    if (client == null) {
      setState(() {
        _error = '未登录';
        _loading = false;
      });
      return;
    }
    try {
      final detail = await client.fetchBookDetail(widget.kind, widget.bookId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loadedChapters = detail.chapters.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  /// 电子书目录追加下一页（章节多时避免一次性全量渲染导致滚动卡顿）。
  Future<void> _loadMoreChapters() async {
    final detail = _detail;
    final client = widget.session.api;
    if (detail == null || client == null || _loadingMore) return;
    if (widget.kind != BookShelfKind.ebook) return;
    final total = detail.totalChapters;
    if (total != null && _loadedChapters >= total) return;
    final page = _loadedChapters ~/ 300;
    setState(() => _loadingMore = true);
    try {
      final next = await client.fetchEbookChapterPage(detail.id, page: page);
      if (!mounted) return;
      final merged = <BookChapter>[
        ...detail.chapters,
        ...next.content.where(
          (c) => !detail.chapters.any((e) => e.chapterIndex == c.chapterIndex),
        ),
      ];
      setState(() {
        _detail = detail.withChapters(
          merged,
          totalChapters: next.totalElements,
        );
        _loadedChapters = merged.length;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  /// 阅读器需要完整目录跳章；详情页只加载了第一页时，打开前补拉全量。
  Future<List<BookChapter>> _readerChapters(BookDetail detail) async {
    final chapters = detail.chapters;
    final total = detail.totalChapters;
    if (total == null || chapters.length >= total) return chapters;
    try {
      final all = await widget.session.api!.fetchEbookChapters(detail.id);
      if (!mounted) return chapters;
      if (all.isNotEmpty && all.length > chapters.length) {
        setState(() {
          _detail = detail.withChapters(all, totalChapters: all.length);
          _loadedChapters = all.length;
        });
        return all;
      }
    } catch (_) {
      // 补拉失败用已加载的部分目录，阅读器仍可读已加载章节。
    }
    return chapters;
  }

  Future<void> _openScrapeSheet() async {
    final detail = _detail;
    if (detail == null) return;
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => ScrapeDialog(
        kind: widget.kind,
        bookId: detail.id,
        session: widget.session,
      ),
    );
    if (changed == true) {
      await widget.session.refreshBooks(widget.kind);
      await _load();
    }
  }

  Future<void> _unbind() async {
    final detail = _detail;
    if (detail == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解除绑定'),
        content: const Text('将清除刮削元数据来源，保留现有信息。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('解除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.session.api!.unbindScrape(widget.kind, id: detail.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已解除绑定')));
      await widget.session.refreshBooks(widget.kind);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('解绑失败：$e')));
    }
  }

  Future<void> _openReader({int? chapterIndex, int? pageIndex}) async {
    final detail = _detail;
    if (detail == null || detail.chapters.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('暂无章节，无法阅读')));
      return;
    }
    final chapters = widget.kind == BookShelfKind.ebook
        ? await _readerChapters(detail)
        : detail.chapters;
    if (!mounted) return;
    if (chapters.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('暂无章节，无法阅读')));
      return;
    }
    final progress = detail.progress;
    final startOver = chapterIndex == null && (progress?.completed ?? false);
    final resumeChapter =
        chapterIndex ??
        ((progress != null && !startOver) ? progress.chapterIndex : null) ??
        chapters.first.chapterIndex;

    if (widget.kind == BookShelfKind.ebook) {
      await Navigator.of(context).push(
        MaterialPageRoute<bool>(
          builder: (_) => EbookReaderScreen(
            session: widget.session,
            bookId: detail.id,
            title: detail.displayTitle,
            chapters: chapters,
            initialChapterIndex: resumeChapter,
          ),
        ),
      );
    } else {
      final resumePage =
          pageIndex ??
          ((progress != null && !startOver) ? progress.pageIndex : null) ??
          0;
      await Navigator.of(context).push(
        MaterialPageRoute<bool>(
          builder: (_) => ComicReaderScreen(
            session: widget.session,
            comicId: detail.id,
            title: detail.displayTitle,
            chapters: chapters,
            initialChapterIndex: resumeChapter,
            initialPageIndex: resumePage,
          ),
        ),
      );
    }
    if (!mounted) return;
    await _load();
    await widget.session.refreshBooks(widget.kind);
  }

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);
    final isAdmin = widget.session.user?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(_detail?.displayTitle ?? '详情'),
        actions: [
          if (isAdmin && _detail != null) ...[
            IconButton(
              tooltip: '解绑',
              icon: const Icon(Icons.link_off_rounded),
              onPressed: _unbind,
            ),
            IconButton(
              icon: const Icon(Icons.auto_fix_high_rounded),
              tooltip: '刮削绑定',
              onPressed: _openScrapeSheet,
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accentOf(context),
                      strokeWidth: 2.5,
                    ),
                  )
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Dimens.spacingXl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14 * form.typeScale,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                          const SizedBox(height: Dimens.spacingLg),
                          FilledButton(
                            onPressed: _load,
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(
                      bottom: Dimens.audioRouteScrollClearance,
                    ),
                    child: _DetailView(
                      detail: _detail!,
                      form: form,
                      kind: widget.kind,
                      onRead:
                          widget.kind == BookShelfKind.comic ||
                              widget.kind == BookShelfKind.ebook
                          ? _openReader
                          : null,
                      onReadChapter:
                          widget.kind == BookShelfKind.comic ||
                              widget.kind == BookShelfKind.ebook
                          ? (chapterIndex) => _openReader(
                              chapterIndex: chapterIndex,
                              pageIndex: 0,
                            )
                          : null,
                      onLoadMore:
                          widget.kind == BookShelfKind.ebook &&
                              (_detail!.totalChapters == null ||
                                  _detail!.totalChapters! >
                                      _detail!.chapters.length)
                          ? _loadMoreChapters
                          : null,
                      loadingMore: _loadingMore,
                      audioDetail: _audioDetail,
                      audioLoading: _audioLoading,
                      audioError: _audioError,
                      audioStarting: _audioStarting,
                      onPlayAudio: widget.kind == BookShelfKind.audiobook
                          ? () => _playAudiobook()
                          : null,
                      onPlayAudioChapter: widget.kind == BookShelfKind.audiobook
                          ? (index) => _playAudiobook(chapterIndex: index)
                          : null,
                      onRetryAudio: _loadAudioDetail,
                    ),
                  ),
          ),
          Positioned(
            left: Dimens.audioRoutePlayerInset,
            right: Dimens.audioRoutePlayerInset,
            bottom: Dimens.audioRoutePlayerInset,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: Dimens.audioRoutePlayerMaxWidth,
                ),
                child: MiniPlayerBar(session: widget.session),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView({
    required this.detail,
    required this.form,
    required this.kind,
    this.onRead,
    this.onReadChapter,
    this.onLoadMore,
    this.loadingMore = false,
    this.audioDetail,
    this.audioLoading = false,
    this.audioError,
    this.audioStarting = false,
    this.onPlayAudio,
    this.onPlayAudioChapter,
    this.onRetryAudio,
  });

  final BookDetail detail;
  final DeviceForm form;
  final BookShelfKind kind;
  final Future<void> Function()? onRead;
  final Future<void> Function(int chapterIndex)? onReadChapter;
  final Future<void> Function()? onLoadMore;
  final bool loadingMore;
  final AudiobookDetail? audioDetail;
  final bool audioLoading;
  final String? audioError;
  final bool audioStarting;
  final VoidCallback? onPlayAudio;
  final ValueChanged<int>? onPlayAudioChapter;
  final VoidCallback? onRetryAudio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover =
        detail.coverPath ?? (detail.id > 0 ? kind.coverPath(detail.id) : null);

    return ListView(
      padding: const EdgeInsets.all(Dimens.spacingLg),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120 * form.posterScale * 0.8,
              child: AspectRatio(
                aspectRatio: kind.coverAspect,
                // Same policy as the shelf grid: comics show the source
                // cover uncropped, other kinds fill the cell.
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Dimens.radiusMd),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                        ),
                      ),
                      ServerImage(
                        url: cover,
                        fit: kind == BookShelfKind.comic
                            ? BoxFit.contain
                            : BoxFit.cover,
                        borderRadius: BorderRadius.zero,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: Dimens.spacingLg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.displayTitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20 * form.typeScale,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  if (detail.subtitle.isNotEmpty) ...[
                    const SizedBox(height: Dimens.spacingSm),
                    Text(
                      detail.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14 * form.typeScale,
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                  const SizedBox(height: Dimens.spacingSm),
                  Wrap(
                    spacing: Dimens.spacingSm,
                    runSpacing: Dimens.spacingSm,
                    children: [
                      if (detail.pubYear != null)
                        _MetaChip(text: '${detail.pubYear}'),
                      if (detail.rating != null && detail.rating! > 0)
                        _MetaChip(
                          icon: Icons.star_rounded,
                          text: detail.rating!.toStringAsFixed(1),
                        ),
                      if (detail.totalChapters != null &&
                          detail.totalChapters! > 0)
                        _MetaChip(
                          text:
                              '${detail.totalChapters} '
                              '${kind == BookShelfKind.ebook ? '章' : '话'}',
                        ),
                      _MetaChip(text: detail.metadataSourceText),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (onRead != null && detail.chapters.isNotEmpty) ...[
          const SizedBox(height: Dimens.spacingXl),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: Size(0, 46 * form.posterScale),
            ),
            onPressed: onRead,
            icon: const Icon(Icons.menu_book_rounded, size: 20),
            label: Text(_readLabel(detail, kind)),
          ),
          if (detail.progress != null &&
              detail.progress!.hasPosition &&
              detail.progress!.completed) ...[
            const SizedBox(height: Dimens.spacingSm),
            Text(
              '已读完',
              style: TextStyle(
                fontSize: 12 * form.typeScale,
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
        if (detail.overview != null && detail.overview!.isNotEmpty) ...[
          const SizedBox(height: Dimens.spacingXl),
          Text(
            '简介',
            style: TextStyle(
              fontSize: 16 * form.typeScale,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Dimens.spacingSm),
          Text(
            detail.overview!,
            style: TextStyle(
              fontSize: 14 * form.typeScale,
              height: 1.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ],
        if (kind == BookShelfKind.audiobook)
          AudiobookListenSection(
            detail: audioDetail,
            loading: audioLoading,
            error: audioError,
            starting: audioStarting,
            onPlay: onPlayAudio,
            onPlayChapter: onPlayAudioChapter,
            onRetry: onRetryAudio,
            typeScale: form.typeScale,
          ),
        if (kind != BookShelfKind.audiobook && detail.chapters.isNotEmpty) ...[
          const SizedBox(height: Dimens.spacingXl),
          Row(
            children: [
              Text(
                '章节',
                style: TextStyle(
                  fontSize: 16 * form.typeScale,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: Dimens.spacingSm),
              Text(
                detail.totalChapters != null &&
                        detail.totalChapters! > detail.chapters.length
                    ? '已加载 ${detail.chapters.length}/${detail.totalChapters}'
                    : '${detail.chapters.length}',
                style: TextStyle(
                  fontSize: 13 * form.typeScale,
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimens.spacingSm),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(Dimens.radiusLg),
            ),
            child: Column(
              children: [
                for (final c in detail.chapters)
                  ListTile(
                    dense: !form.isTv,
                    onTap: onReadChapter == null
                        ? null
                        : () => onReadChapter!(c.chapterIndex),
                    leading: Text(
                      '${c.chapterIndex + 1}',
                      style: TextStyle(
                        fontSize: 14 * form.typeScale,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      (c.title != null && c.title!.isNotEmpty)
                          ? c.title!
                          : '第 ${c.chapterIndex + 1} '
                                '${kind == BookShelfKind.ebook ? '章' : '话'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14 * form.typeScale),
                    ),
                    subtitle: onReadChapter != null
                        ? Text(
                            '点击阅读',
                            style: TextStyle(
                              fontSize: 11 * form.typeScale,
                              color: theme.hintColor,
                            ),
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (c.pageCount != null)
                          Text(
                            '${c.pageCount}P',
                            style: TextStyle(
                              fontSize: 12 * form.typeScale,
                              color: theme.hintColor,
                            ),
                          ),
                        if (onReadChapter != null) ...[
                          const SizedBox(width: Dimens.spacingXs),
                          Icon(
                            Icons.play_circle_outline_rounded,
                            size: 20 * form.posterScale,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                if (onLoadMore != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimens.spacingLg,
                      vertical: Dimens.spacingSm,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: loadingMore
                          ? const Padding(
                              padding: EdgeInsets.all(Dimens.spacingMd),
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                ),
                              ),
                            )
                          : OutlinedButton.icon(
                              onPressed: onLoadMore,
                              icon: const Icon(Icons.expand_more_rounded),
                              label: Text(
                                '加载更多章节',
                                style: TextStyle(fontSize: 13 * form.typeScale),
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Dimens.spacingXxl),
      ],
    );
  }
}

String _readLabel(BookDetail detail, BookShelfKind kind) {
  final p = detail.progress;
  if (p == null || !p.hasPosition || p.completed) return '开始阅读';
  final chapter = (p.chapterIndex ?? 0) + 1;
  if (kind == BookShelfKind.ebook) return '继续阅读 · 第 $chapter 章';
  final page = (p.pageIndex ?? 0) + 1;
  return '继续阅读 · 第 $chapter 话 · 第 $page 页';
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimens.spacingSm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Dimens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 13, color: theme.colorScheme.primary),
          if (icon != null) const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class AudiobookListenSection extends StatelessWidget {
  const AudiobookListenSection({
    super.key,
    required this.detail,
    required this.loading,
    required this.error,
    required this.starting,
    required this.onPlay,
    required this.onPlayChapter,
    required this.onRetry,
    required this.typeScale,
  });

  final AudiobookDetail? detail;
  final bool loading;
  final String? error;
  final bool starting;
  final VoidCallback? onPlay;
  final ValueChanged<int>? onPlayChapter;
  final VoidCallback? onRetry;
  final double typeScale;

  String _playLabel(AudiobookDetail value) {
    final progress = value.progress;
    if (progress == null ||
        progress.completed ||
        progress.positionSeconds <= 0) {
      return '开始收听';
    }
    final chapter = value.chapters
        .where(
          (item) =>
              item.trackIndex == progress.trackIndex &&
              item.startInTrack <= progress.positionSeconds,
        )
        .fold<AudiobookChapter?>(null, (best, item) {
          if (best == null || item.startInTrack > best.startInTrack) {
            return item;
          }
          return best;
        });
    return chapter == null ? '继续收听' : '继续收听 · ${chapter.label}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Dimens.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '收听',
                style: TextStyle(
                  fontSize: 16 * typeScale,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(width: Dimens.spacingSm),
                Text(
                  '${detail!.tracks.length} 条音轨 · ${detail!.chapters.length} 章',
                  style: TextStyle(
                    fontSize: 12 * typeScale,
                    color: theme.hintColor,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Dimens.spacingSm),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(Dimens.spacingLg),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '音频信息加载失败：$error',
                    style: TextStyle(
                      fontSize: 13 * typeScale,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
                TextButton(onPressed: onRetry, child: const Text('重试')),
              ],
            )
          else if (detail == null || detail!.tracks.isEmpty)
            Text(
              '暂无可播放音轨',
              style: TextStyle(
                fontSize: 13 * typeScale,
                color: theme.hintColor,
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(Dimens.spacingMd),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(Dimens.radiusLg),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) => Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: FilledButton.icon(
                      onPressed: starting ? null : onPlay,
                      icon: starting
                          ? const SizedBox.square(
                              dimension: Dimens.audioInlineProgressSize,
                              child: CircularProgressIndicator(
                                strokeWidth: Dimens.audioInlineProgressStroke,
                              ),
                            )
                          : const Icon(Icons.headphones_rounded),
                      label: Text(
                        detail!.progress?.completed == true
                            ? '从头开始收听'
                            : _playLabel(detail!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (detail!.chapters.isNotEmpty) ...[
              const SizedBox(height: Dimens.spacingMd),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(Dimens.radiusLg),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      for (final chapter in detail!.chapters)
                        ListTile(
                          dense: true,
                          leading: Text(
                            '${chapter.chapterIndex + 1}',
                            style: TextStyle(
                              fontSize: 13 * typeScale,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            chapter.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14 * typeScale),
                          ),
                          subtitle: Text(
                            '音轨 ${chapter.trackIndex + 1}',
                            style: TextStyle(
                              fontSize: 11 * typeScale,
                              color: theme.hintColor,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.play_circle_outline_rounded,
                          ),
                          onTap: starting
                              ? null
                              : () => onPlayChapter?.call(chapter.chapterIndex),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Source picker + search + one-tap bind.
class ScrapeDialog extends StatefulWidget {
  const ScrapeDialog({
    super.key,
    required this.kind,
    required this.bookId,
    required this.session,
  });

  final BookShelfKind kind;
  final int bookId;
  final Session session;

  @override
  State<ScrapeDialog> createState() => _ScrapeDialogState();
}

class _ScrapeDialogState extends State<ScrapeDialog> {
  final _keywordCtrl = TextEditingController();
  List<ScrapeProviderInfo> _providers = const [];
  String? _selectedSource;
  List<ScrapeResult> _results = const [];
  bool _searching = false;
  bool _binding = false;
  String? _error;

  void _selectSource(String? source) {
    setState(() {
      _selectedSource = source;
      _results = const [];
      _error = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    try {
      final providers = await widget.session.api!.fetchScrapeProviders(
        widget.kind,
      );
      if (!mounted) return;
      setState(() {
        _providers = providers;
        _selectedSource = null; // null = all sources
      });
    } catch (_) {
      // providers are optional sugar; search still works with null source
    }
  }

  Future<void> _search() async {
    final q = _keywordCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
      _results = const [];
    });
    try {
      final results = await widget.session.api!.searchScrape(
        widget.kind,
        q: q,
        source: _selectedSource,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _results = const [];
        _searching = false;
      });
    }
  }

  Future<void> _bind(ScrapeResult r) async {
    setState(() => _binding = true);
    try {
      await widget.session.api!.bindScrape(
        widget.kind,
        id: widget.bookId,
        source: r.source,
        sourceId: r.sourceId,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _binding = false;
        _error = '绑定失败：$e';
      });
    }
  }

  @override
  void dispose() {
    _keywordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAudiobook = widget.kind == BookShelfKind.audiobook;
    final isXimalaya = isAudiobook && _selectedSource == 'ximalaya';
    return Dialog(
      backgroundColor: AppColors.surface(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(Dimens.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '刮削绑定',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
              const SizedBox(height: Dimens.spacingSm),
              if (_providers.isNotEmpty)
                Wrap(
                  spacing: Dimens.spacingSm,
                  children: [
                    ChoiceChip(
                      label: const Text('全部'),
                      selected: _selectedSource == null,
                      onSelected: _searching || _binding
                          ? null
                          : (_) => _selectSource(null),
                    ),
                    for (final p in _providers)
                      ChoiceChip(
                        label: Text(p.displayName),
                        selected: _selectedSource == p.source,
                        onSelected: _searching || _binding
                            ? null
                            : (_) => _selectSource(p.source),
                      ),
                  ],
                ),
              const SizedBox(height: Dimens.spacingSm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _keywordCtrl,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: isXimalaya
                            ? '关键词 / 专辑链接 / ID'
                            : isAudiobook && _selectedSource == null
                            ? '标题 / 作者 / 喜马拉雅专辑链接'
                            : '标题 / 作者 / 车号',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: Dimens.spacingSm),
                  FilledButton.icon(
                    onPressed: _searching ? null : _search,
                    icon: _searching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search_rounded, size: 18),
                    label: const Text('搜索'),
                  ),
                ],
              ),
              const SizedBox(height: Dimens.spacingSm),
              if (isXimalaya)
                Padding(
                  padding: const EdgeInsets.only(bottom: Dimens.spacingSm),
                  child: Text(
                    '搜索受限时，请粘贴喜马拉雅专辑链接或 ID',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: Dimens.spacingSm),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              Flexible(
                child: _results.isEmpty && !_searching
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: Dimens.spacingXl,
                        ),
                        child: Center(
                          child: Text(
                            _keywordCtrl.text.isEmpty ? '输入关键词搜索目标站点' : '无结果',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.hintColor,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = _results[i];
                          return ListTile(
                            dense: true,
                            title: Text(
                              r.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              [
                                if (r.author != null && r.author!.isNotEmpty)
                                  r.author!,
                                if (r.narrator != null &&
                                    r.narrator!.isNotEmpty)
                                  '演播：${r.narrator!}',
                                if (r.pubYear != null) '${r.pubYear}',
                                if (r.rating != null && r.rating! > 0)
                                  '★ ${r.rating!.toStringAsFixed(1)}',
                                r.source == 'ximalaya' ? '喜马拉雅' : r.source,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.hintColor,
                              ),
                            ),
                            trailing: _binding
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 20,
                                  ),
                            onTap: _binding ? null : () => _bind(r),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
