import 'package:flutter/material.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/video.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../widgets/server_image.dart';
import '../home/home_carousel.dart' show ResolutionBadges, SlideBadge;
import 'video_detail_screen.dart';

/// 海报网格，库详情与库内搜索共用同一套卡片渲染与网格布局。
class LibraryPosterGrid extends StatelessWidget {
  const LibraryPosterGrid({
    super.key,
    required this.items,
    required this.portrait,
    required this.form,
    required this.session,
    this.leading,
    this.columns,
    this.onChanged,
  });

  final List<SeriesListDto> items;
  final bool portrait;
  final DeviceForm form;
  final Session session;

  /// 详情页改完数据（绑 TMDB / 改元数据）返回 `true` 后回调。
  /// 容器（库页 / 搜索页）用它刷新**自己**那份数据；目录本身由卡片
  /// 内部 `session.loadCatalog()` 统一重载。
  final VoidCallback? onChanged;

  /// 覆盖列数：横屏封面（16:9）单张更占地方，库页会传更少的列数。
  final int? columns;

  /// 网格首格的自定义入口卡（如库详情的“未刮削”入口），搜索页不传。
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = columns ?? form.overviewCrossAxisCount;
        const spacing = Dimens.spacingLg;
        final cellW =
            (constraints.maxWidth - spacing * 2 - spacing * (cols - 1)) / cols;
        final imageH = portrait
            ? cellW *
                  1.5 // 2:3 poster
            : cellW * 9 / 16; // wide fanart
        final cellAspect = cellW / (imageH + Dimens.videoMetaExtent);

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(
            Dimens.spacingLg,
            Dimens.spacingSm,
            Dimens.spacingLg,
            Dimens.spacingXxl,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: cellAspect,
          ),
          itemCount: items.length + (leading != null ? 1 : 0),
          itemBuilder: (context, i) {
            if (leading != null && i == 0) {
              return leading!;
            }
            final item = items[leading != null ? i - 1 : i];
            return LibraryPosterCard(
              key: ValueKey(item.id),
              item: item,
              portrait: portrait,
              form: form,
              session: session,
              onChanged: onChanged,
            );
          },
        );
      },
    );
  }
}

/// 竖屏海报（cover）或横屏背景（fanart）的系列/单片卡片。
class LibraryPosterCard extends StatelessWidget {
  const LibraryPosterCard({
    super.key,
    required this.item,
    required this.portrait,
    required this.form,
    required this.session,
    this.onChanged,
  });

  final SeriesListDto item;
  final bool portrait;
  final DeviceForm form;
  final Session session;

  /// 见 [LibraryPosterGrid.onChanged]。
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    // Portrait uses the cover; landscape falls back to the cover when the
    // server has no fanart for this item.
    final url = portrait ? item.coverUrl : (item.fanartUrl ?? item.coverUrl);
    final radius = BorderRadius.circular(Dimens.radiusMd);
    // 文件已不在磁盘上（改名/删除后等清理的旧记录）：置灰 + 不可点，
    // 避免误点开一条注定播放失败的条目。
    final stale = item.fileMissing;

    return InkWell(
      borderRadius: radius,
      onTap: stale
          ? () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('这条记录的文件已不存在，可用右上角「清理残留记录」移除')),
            )
          : () async {
              // 详情页里绑定 TMDB / 改元数据后会 pop(true)。
              // 但此时详情页**已经 pop 掉了**，顶上就是容器自己——所以这里
              // 不能再 `Navigator.pop(true)` 往上传，否则库页/搜索页会把自己
              // 关掉（用户被弹回首页），而首页那个 push 没人 await，`true`
              // 又直接丢，两边都不刷新：改完名字得杀进程才看得到。
              // 改成卡片自己重载目录（首页与库页都订阅 session），
              // 再用 onChanged 让容器刷它**自己**那份数据（搜索结果不在
              // session 里，只能搜索页自己重查）。
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) =>
                      VideoDetailScreen(session: session, item: item),
                ),
              );
              if (changed == true && context.mounted) {
                await session.loadCatalog();
                if (context.mounted) onChanged?.call();
              }
            },
      child: Opacity(
        opacity: stale ? 0.45 : 1,
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
                    ServerImage(url: url, borderRadius: radius),
                    if (stale)
                      Center(
                        child: Icon(
                          Icons.error_outline_rounded,
                          size: 32 * form.typeScale,
                          color: AppColors.danger,
                        ),
                      ),
                    // Rating / 18+ chips share the top-left slot with the
                    // home rails; the TV marker moves right to stay out of
                    // their way.
                    if (item.isAdult ||
                        (item.rating != null && item.rating! > 0))
                      Positioned(
                        left: Dimens.spacingXs,
                        top: Dimens.spacingXs,
                        child: Wrap(
                          spacing: Dimens.spacingXs,
                          children: [
                            // 评分在前、18+ 在后
                            if (item.rating != null && item.rating! > 0)
                              SlideBadge(
                                text: '★ ${item.rating!.toStringAsFixed(1)}',
                                color: AppColors.gold,
                              ),
                            if (item.isAdult)
                              const SlideBadge(
                                text: '18+',
                                color: AppColors.danger,
                              ),
                          ],
                        ),
                      ),
                    // 剧集标识：区分「剧」与「单片」。原来只在横屏封面模式显示
                    // （!portrait 写反了），导致竖屏海报下看不出是剧还是单片。
                    if (item.isTv)
                      Positioned(
                        right: Dimens.spacingSm,
                        top: Dimens.spacingSm,
                        child: Icon(
                          Icons.tv_rounded,
                          size: 16 * form.typeScale,
                          color: Colors.white,
                          shadows: const [
                            Shadow(color: Colors.black54, blurRadius: 6),
                          ],
                        ),
                      ),
                    Positioned(
                      right: Dimens.spacingXs,
                      bottom: Dimens.spacingXs,
                      child: ResolutionBadges(resolutions: item.resolutions),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Dimens.spacingXs),
            Text(
              item.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13 * form.typeScale,
                fontWeight: FontWeight.w600,
              ),
            ),
            // 年份行**始终**占位：卡片高度由网格固定，缺这一行会让海报区域变高，
            // 导致有年份/无年份的卡片高度不齐（"未刮削"入口卡同理）。
            Text(
              item.year == null ? '\u00A0' : '${item.year}',
              maxLines: 1,
              style: TextStyle(
                fontSize: 11 * form.typeScale,
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
