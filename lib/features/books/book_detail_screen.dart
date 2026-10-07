import 'package:flutter/material.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/media_models.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../widgets/server_image.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
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
        ...next.content.where((c) =>
            !detail.chapters.any((e) => e.chapterIndex == c.chapterIndex)),
      ];
      setState(() {
        _detail = detail.withChapters(merged, totalChapters: next.totalElements);
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
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.accent,
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
                    FilledButton(onPressed: _load, child: const Text('重试')),
                  ],
                ),
              ),
            )
          : _DetailView(
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
                  ? (chapterIndex) =>
                        _openReader(chapterIndex: chapterIndex, pageIndex: 0)
                  : null,
              onLoadMore:
                  widget.kind == BookShelfKind.ebook &&
                      (_detail!.totalChapters == null ||
                          _detail!.totalChapters! > _detail!.chapters.length)
                  ? _loadMoreChapters
                  : null,
              loadingMore: _loadingMore,
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
  });

  final BookDetail detail;
  final DeviceForm form;
  final BookShelfKind kind;
  final Future<void> Function()? onRead;
  final Future<void> Function(int chapterIndex)? onReadChapter;
  final Future<void> Function()? onLoadMore;
  final bool loadingMore;

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
        if (detail.chapters.isNotEmpty) ...[
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
                                style: TextStyle(
                                  fontSize: 13 * form.typeScale,
                                ),
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
                      onSelected: (_) => setState(() => _selectedSource = null),
                    ),
                    for (final p in _providers)
                      ChoiceChip(
                        label: Text(p.displayName),
                        selected: _selectedSource == p.source,
                        onSelected: (_) =>
                            setState(() => _selectedSource = p.source),
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
                      decoration: const InputDecoration(
                        hintText: '标题 / 作者 / 车号',
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
                                if (r.pubYear != null) '${r.pubYear}',
                                if (r.rating != null && r.rating! > 0)
                                  '★ ${r.rating!.toStringAsFixed(1)}',
                                r.source,
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
