import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/media_models.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../widgets/server_image.dart';
import 'video_detail_screen.dart';

/// One library's unscraped backlog (tmdb_id == null), paginated.
///
/// Entered from the synthetic "未刮削" card in [VideoLibraryScreen]; each row
/// opens the video detail — the admin menu there binds TMDB, and a season
/// bind clears the whole season's rows after reload.
class UnscrapedScreen extends StatefulWidget {
  const UnscrapedScreen({
    super.key,
    required this.session,
    required this.libraryId,
    required this.libraryName,
    this.onChanged,
  });

  final Session session;
  final int libraryId;
  final String libraryName;

  /// 详情页改完数据（绑 TMDB / 改元数据）后回调，供库页重探入口卡。
  /// 目录本身由本页调 `session.loadCatalog()` 重载。
  final VoidCallback? onChanged;

  @override
  State<UnscrapedScreen> createState() => _UnscrapedScreenState();
}

class _UnscrapedScreenState extends State<UnscrapedScreen> {
  static const _pageSize = 20;
  static const _searchDelay = Duration(milliseconds: 300);

  final _items = <VideoItem>[];
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  int _requestVersion = 0;
  int _page = 0;
  int? _total;
  bool _loading = true;
  bool _loadingMore = false;
  bool _exhausted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loading || _loadingMore || _exhausted || _error != null) return;
    if (_scrollCtrl.position.extentAfter < Dimens.unscrapedLoadMoreThreshold) {
      unawaited(_loadMore());
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    ++_requestVersion;
    setState(() {
      _loading = true;
      _total = null;
    });
    _searchDebounce = Timer(_searchDelay, () => unawaited(_reload()));
  }

  Future<void> _reload({bool resetScroll = true}) async {
    _searchDebounce?.cancel();
    final version = ++_requestVersion;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      if (resetScroll) _items.clear();
      _page = 0;
      if (resetScroll) _total = null;
      _exhausted = false;
    });
    if (resetScroll && _scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    await _fetch(version);
    if (mounted && version == _requestVersion) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _exhausted) return;
    final version = _requestVersion;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    await _fetch(version);
    if (mounted && version == _requestVersion) {
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _fetch(int version) async {
    final api = widget.session.api;
    if (api == null) {
      _error = '未登录';
      return;
    }
    final page = _page;
    try {
      final result = await api.fetchUnscrapedVideos(
        page: page,
        size: _pageSize,
        libraryId: widget.libraryId,
        query: _searchCtrl.text.trim(),
      );
      if (!mounted || version != _requestVersion) return;
      if (page == 0) _items.clear();
      _items.addAll(result.content);
      _total = result.totalElements;
      _exhausted = result.content.isEmpty || page + 1 >= result.totalPages;
      _page = page + 1;
    } catch (e) {
      if (mounted && version == _requestVersion) _error = '$e';
    }
  }

  Future<void> _open(VideoItem v) async {
    // Episodes open their series detail (where the TMDB menu lives);
    // standalone movies open as standalone.
    final item = SeriesListDto(
      id: v.seriesId ?? v.id,
      type: v.seriesId != null ? 'series' : 'standalone',
      title: v.seriesTitle ?? v.title,
      coverUrl: v.coverUrl,
      fanartUrl: v.fanartUrl,
      rating: v.rating,
      year: v.year,
      mediaType: v.mediaType,
    );
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => VideoDetailScreen(
          session: widget.session,
          item: item,
          initialVideoId: v.id,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _reload(resetScroll: false);
      if (!mounted) return;
      await widget.session.loadCatalog();
      if (mounted) widget.onChanged?.call();
    }
  }

  String get _query => _searchCtrl.text.trim();
  void _clearSearch() {
    _searchCtrl.clear();
    unawaited(_reload());
  }

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('未刮削'),
        actions: [
          IconButton(
            tooltip: '刷新待处理列表',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: form.contentMaxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimens.spacingLg),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const gap = Dimens.spacingMd;
                  final maxColumns = switch (form) {
                    DeviceForm.tabletPortrait => 2,
                    DeviceForm.tabletLandscape => 3,
                    _ => 1,
                  };
                  final columns =
                      ((constraints.maxWidth + gap) /
                              (Dimens.unscrapedColumnMinWidth + gap))
                          .floor()
                          .clamp(1, maxColumns);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: Dimens.spacingMd),
                      Text.rich(
                        TextSpan(
                          text: widget.libraryName,
                          style: textTheme.titleMedium,
                          children: [
                            if (_total case final total?)
                              TextSpan(
                                text: _query.isNotEmpty
                                    ? '  ·  匹配 $total 项'
                                    : '  ·  待处理 $total 项',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: Dimens.spacingMd),
                      _searchField(),
                      const SizedBox(height: Dimens.spacingMd),
                      Expanded(child: _results(columns)),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchField() => TextField(
    controller: _searchCtrl,
    textInputAction: TextInputAction.search,
    onChanged: _onSearchChanged,
    onSubmitted: (_) => unawaited(_reload()),
    decoration: InputDecoration(
      hintText: '搜索标题或文件名',
      prefixIcon: const Icon(Icons.search_rounded),
      suffixIcon: _searchCtrl.text.isEmpty
          ? null
          : IconButton(
              tooltip: '清除搜索',
              onPressed: _clearSearch,
              icon: const Icon(Icons.close_rounded),
            ),
      filled: true,
      fillColor: AppColors.surface(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Dimens.radiusMd),
        borderSide: BorderSide.none,
      ),
    ),
  );

  Widget _results(int columns) {
    if (_items.isEmpty) {
      if (_loading) {
        return const Center(child: CircularProgressIndicator.adaptive());
      }
      final message = _error ?? (_query.isNotEmpty ? '没有匹配的视频' : '该库没有未刮削的视频');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Dimens.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              if (_error != null || _query.isNotEmpty) ...[
                const SizedBox(height: Dimens.spacingMd),
                OutlinedButton(
                  onPressed: _error != null ? _reload : _clearSearch,
                  child: Text(_error != null ? '重试' : '清除搜索'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return RefreshIndicator(
      onRefresh: () => _reload(resetScroll: false),
      child: CustomScrollView(
        controller: _scrollCtrl,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: Dimens.spacingMd,
              mainAxisSpacing: Dimens.spacingMd,
              mainAxisExtent:
                  Dimens.unscrapedRowHeight * textScale.clamp(1.0, 2.0),
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final video = _items[index];
              return _UnscrapedTile(
                key: ValueKey('unscraped-${video.id}'),
                video: video,
                onTap: () => _open(video),
              );
            }, childCount: _items.length),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Dimens.spacingLg),
              child: Center(
                child: _loadingMore
                    ? const CircularProgressIndicator.adaptive()
                    : _exhausted
                    ? const SizedBox.shrink()
                    : Column(
                        children: [
                          if (_error case final error?)
                            Text(error, textAlign: TextAlign.center),
                          OutlinedButton(
                            onPressed: _loadMore,
                            child: Text(_error == null ? '加载更多' : '重试加载'),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnscrapedTile extends StatelessWidget {
  const _UnscrapedTile({super.key, required this.video, required this.onTap});

  final VideoItem video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final fileName = video.fileName;
    final title = video.title.isEmpty ? fileName ?? '未命名视频' : video.title;
    final showFileName =
        fileName != null && fileName.isNotEmpty && fileName != title;
    final details = [
      if (video.episodeNumber != null) video.episodeLabel,
      if (video.year != null) '${video.year}',
      if (video.resolutionLabel case final resolution?
          when resolution.isNotEmpty)
        resolution,
    ];
    return Material(
      color: AppColors.surface(context),
      borderRadius: BorderRadius.circular(Dimens.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Dimens.spacingMd),
          child: Row(
            children: [
              SizedBox(
                height: Dimens.unscrapedCoverHeight,
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: ServerImage(
                    url: video.coverUrl,
                    borderRadius: BorderRadius.circular(Dimens.radiusSm),
                  ),
                ),
              ),
              const SizedBox(width: Dimens.spacingMd),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (details.isNotEmpty || showFileName)
                      const SizedBox(height: Dimens.spacingXs),
                    if (details.isNotEmpty)
                      Text(
                        details.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(color: secondary),
                      ),
                    if (showFileName)
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(color: secondary),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: Dimens.spacingXs),
              Icon(Icons.chevron_right_rounded, color: secondary),
            ],
          ),
        ),
      ),
    );
  }
}
