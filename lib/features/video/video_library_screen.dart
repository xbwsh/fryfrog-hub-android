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

  /// 本库「文件已不在磁盘上」的残留；>0 才显示清理入口。
  StaleRecords _stale = const StaleRecords();

  @override
  void initState() {
    super.initState();
    _probeUnscraped();
    _probeStale();
  }

  /// 残留体检：文件已被移走/改名时旧记录会滞留到宽限期结束，期间新旧并存、
  /// 旧的点开会失败。这里探测一次，给管理员一个主动清理的入口。
  Future<void> _probeStale() async {
    if (widget.session.user?.isAdmin != true) return;
    final api = widget.session.api;
    if (api == null) return;
    try {
      final stale = await api.fetchStaleRecords(widget.group.libraryId);
      if (mounted) setState(() => _stale = stale);
    } catch (_) {
      // 探测失败就不显示入口，不影响正常浏览
    }
  }

  Future<void> _purgeStale() async {
    final api = widget.session.api;
    if (api == null) return;
    final samples = _stale.samples;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('清理残留记录（${_stale.total}）'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '这些记录指向的文件已不在磁盘上（多半是改名/删除后的旧条目）。'
                '清理只删数据库记录，不动磁盘上的任何文件；'
                '磁盘异常时后端会拒绝执行。',
              ),
              if (samples.isNotEmpty) ...[
                const SizedBox(height: Dimens.spacingMd),
                Text(
                  _stale.total > samples.length
                      ? '以下为前 ${samples.length} 条：'
                      : '以下为全部条目：',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                const SizedBox(height: Dimens.spacingXs),
                // 名称 + 路径都给出：只看名字分不清是哪个文件被改过名
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final s in samples)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: Dimens.spacingSm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.displayName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if ((s.filePath ?? '').isNotEmpty)
                                  Text(
                                    s.filePath!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).hintColor,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清理'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final removed = await api.purgeStaleRecords(widget.group.libraryId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(removed > 0 ? '已清理 $removed 条残留记录' : '没有可清理的记录'),
        ),
      );
      await _probeStale();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('清理失败：$e')));
    }
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
          // 有残留（文件已不存在的旧记录）时才出现，避免平时占位
          if (_stale.total > 0)
            IconButton(
              tooltip: '清理残留记录（${_stale.total}）',
              icon: Badge(
                label: Text('${_stale.total}'),
                child: const Icon(Icons.cleaning_services_rounded),
              ),
              onPressed: _purgeStale,
            ),
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
              columns: _portrait
                  ? null
                  : (form.overviewCrossAxisCount - 1).clamp(2, 12),
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
