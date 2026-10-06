import 'package:flutter/material.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/video.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import 'in_library_search_screen.dart';
import 'library_poster_grid.dart';
import 'unscraped_screen.dart';

/// All items of one home library rail ("电影" / "电视剧" / …) in a grid,
/// with a portrait-poster / landscape-backdrop display toggle.
class VideoLibraryScreen extends StatefulWidget {
  const VideoLibraryScreen({
    super.key,
    required this.session,
    required this.group,
  });

  final Session session;
  final LibrarySeriesGroup group;

  @override
  State<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends State<VideoLibraryScreen> {
  /// true = 竖屏海报 (cover) · false = 横屏海报 (fanart backdrop).
  bool _portrait = true;

  /// 本库未刮削条数：null = 还在探测（先不显示入口卡，避免闪一下又消失）。
  int? _unscrapedCount;

  @override
  void initState() {
    super.initState();
    _probeUnscraped();
  }

  /// 只有真有未刮削内容时才显示入口卡——否则点进去是空列表，很怪。
  /// size=1 只为拿 totalElements，开销可忽略。
  Future<void> _probeUnscraped() async {
    if (widget.session.user?.isAdmin != true) return;
    final api = widget.session.api;
    if (api == null) return;
    try {
      final page = await api.fetchUnscrapedVideos(
        page: 0,
        size: 1,
        libraryId: widget.group.libraryId,
      );
      if (mounted) setState(() => _unscrapedCount = page.totalElements);
    } catch (_) {
      // 探测失败就按「有」处理，保证管理员仍能进入后台
      if (mounted) setState(() => _unscrapedCount = 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);
    final items = widget.group.allItems;
    // 管理员 + 本库确实有未刮削内容，才给入口
    final showUnscraped =
        widget.session.user?.isAdmin == true && (_unscrapedCount ?? 0) > 0;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.group.name,
              style: TextStyle(
                fontSize: 17 * form.typeScale,
                fontWeight: FontWeight.w700,
              ),
            ),
            // 库统计：系列数 / 视频数（纯单片库只显示视频数）
            Text(
              widget.group.statsLabel,
              style: TextStyle(
                fontSize: 12 * form.typeScale,
                color: Theme.of(context).hintColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '搜索本库',
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => InLibrarySearchScreen(
                    session: widget.session,
                    libraryId: widget.group.libraryId,
                    libraryName: widget.group.name,
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: Dimens.spacingLg),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.crop_portrait_rounded, size: 18),
                  tooltip: '竖屏海报',
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.crop_landscape_rounded, size: 18),
                  tooltip: '横屏海报',
                ),
              ],
              selected: {_portrait},
              onSelectionChanged: (s) => setState(() => _portrait = s.first),
            ),
          ),
        ],
      ),
      // 有无未刮削入口卡由 _unscrapedCount 决定（非管理员/无内容时不显示）
      body: items.isEmpty && !showUnscraped
          ? Center(
              child: Text(
                '暂无内容',
                style: TextStyle(
                  fontSize: 15 * form.typeScale,
                  color: Theme.of(context).hintColor,
                ),
              ),
            )
          : LibraryPosterGrid(
              items: items,
              portrait: _portrait,
              form: form,
              session: widget.session,
              // 横屏封面是 16:9，比竖屏海报占横向空间；少一列让单张明显更大
              columns: _portrait ? null : (form.overviewCrossAxisCount - 1).clamp(2, 12),
              leading: showUnscraped
                  ? _UnscrapedEntryCard(
                      key: const ValueKey('unscraped-entry'),
                      form: form,
                      count: _unscrapedCount,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<bool>(
                            builder: (_) => UnscrapedScreen(
                              session: widget.session,
                              libraryId: widget.group.libraryId,
                              libraryName: widget.group.name,
                            ),
                          ),
                        );
                      },
                    )
                  : null,
            ),
    );
  }
}

/// Placeholder cell the size of a poster card: opens the library's
/// unscraped backlog. No cover art by design.
class _UnscrapedEntryCard extends StatelessWidget {
  const _UnscrapedEntryCard({
    super.key,
    required this.form,
    required this.onTap,
    this.count,
  });

  final DeviceForm form;
  final VoidCallback onTap;

  /// 本库未刮削条数；显示出来比光写「未刮削」有用。
  final int? count;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(Dimens.radiusMd);

    return InkWell(
      borderRadius: radius,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SizedBox.expand(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: radius,
                    ),
                  ),
                  Center(
                    child: Icon(
                      Icons.search_off_rounded,
                      size: 44 * form.typeScale,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Dimens.spacingXs),
          Text(
            count != null && count! > 0 ? '未刮削 ($count)' : '未刮削',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13 * form.typeScale,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          // 与海报卡片对齐：年份行始终占位，否则这张卡比别的卡高
          Text(
            '\u00A0',
            maxLines: 1,
            style: TextStyle(fontSize: 11 * form.typeScale),
          ),
        ],
      ),
    );
  }
}
