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

  final _items = <VideoItem>[];
  final _scrollCtrl = ScrollController();
  int _page = 0;
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
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loading || _loadingMore || _exhausted || _error != null) return;
    if (_scrollCtrl.position.extentAfter < 300) _loadMore();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
      _page = 0;
      _exhausted = false;
    });
    await _fetch();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    await _fetch();
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _fetch() async {
    final api = widget.session.api;
    if (api == null) {
      _error = '未登录';
      return;
    }
    try {
      final result = await api.fetchUnscrapedVideos(
        page: _page,
        size: _pageSize,
        libraryId: widget.libraryId,
      );
      _items.addAll(result.content);
      _exhausted = result.content.isEmpty || _page + 1 >= result.totalPages;
      _page += 1;
    } catch (e) {
      _error = '$e';
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
        builder: (_) => VideoDetailScreen(session: widget.session, item: item),
      ),
    );
    // A season bind clears tmdb_id across its episodes — drop scrubbed rows.
    if (mounted) await _reload();
    // 详情页 pop(true) 表示数据被改过：本页的行已由上面 `_reload()` 刷新，
    // 但目录（首页 / 库页）也要跟着重建，否则改完名字得杀进程才看得到。
    if (changed == true && mounted) {
      await widget.session.loadCatalog();
      if (mounted) widget.onChanged?.call();
    }
  }

  String? _subtitle(VideoItem v) {
    final series = v.seriesTitle;
    final parts = <String>[
      if (series != null && series.isNotEmpty && series != v.title) series,
      if (v.seasonNumber != null && v.episodeNumber != null) v.episodeLabel,
      if (v.year != null) '${v.year}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          '${widget.libraryName} · 未刮削',
          style: TextStyle(
            fontSize: 17 * form.typeScale,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _error != null && _items.isEmpty
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
                    FilledButton(onPressed: _reload, child: const Text('重试')),
                  ],
                ),
              ),
            )
          : _items.isEmpty
          ? Center(
              child: Text(
                '该库没有未刮削的视频',
                style: TextStyle(
                  fontSize: 15 * form.typeScale,
                  color: Theme.of(context).hintColor,
                ),
              ),
            )
          : ListView.separated(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(
                Dimens.spacingLg,
                Dimens.spacingSm,
                Dimens.spacingLg,
                Dimens.spacingXxl,
              ),
              itemCount: _items.length + (_loadingMore ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i >= _items.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: Dimens.spacingLg),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final v = _items[i];
                return ListTile(
                  key: ValueKey('unscraped-${v.id}'),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: Dimens.spacingXs,
                  ),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(Dimens.radiusSm),
                    child: SizedBox(
                      width: 56,
                      height: 84,
                      child: ServerImage(
                        url: v.coverUrl,
                        borderRadius: BorderRadius.circular(Dimens.radiusSm),
                      ),
                    ),
                  ),
                  title: Text(
                    v.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14 * form.typeScale,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: _subtitle(v) == null
                      ? null
                      : Text(
                          _subtitle(v)!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12 * form.typeScale,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: 20 * form.typeScale,
                    color: Theme.of(context).hintColor,
                  ),
                  onTap: () => _open(v),
                );
              },
            ),
    );
  }
}
