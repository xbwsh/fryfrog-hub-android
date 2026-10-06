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
  });

  final List<SeriesListDto> items;
  final bool portrait;
  final DeviceForm form;
  final Session session;

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
            (constraints.maxWidth -
                spacing * 2 -
                spacing * (cols - 1)) /
            cols;
        final imageH = portrait
            ? cellW * 1.5 // 2:3 poster
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
  });

  final SeriesListDto item;
  final bool portrait;
  final DeviceForm form;
  final Session session;

  @override
  Widget build(BuildContext context) {
    // Portrait uses the cover; landscape falls back to the cover when the
    // server has no fanart for this item.
    final url = portrait ? item.coverUrl : (item.fanartUrl ?? item.coverUrl);
    final radius = BorderRadius.circular(Dimens.radiusMd);

    return InkWell(
      borderRadius: radius,
      onTap: () async {
        // 详情页里绑定 TMDB / 改元数据后会 pop(true)；据此把「数据已变」
        // 继续往上传，让上层列表重载——否则要杀进程才看得到新名字。
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => VideoDetailScreen(session: session, item: item),
          ),
        );
        if (changed == true && context.mounted) {
          Navigator.of(context).pop(true);
        }
      },
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
                  // Rating / 18+ chips share the top-left slot with the
                  // home rails; the TV marker moves right to stay out of
                  // their way.
                  if (item.isAdult || (item.rating != null && item.rating! > 0))
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
    );
  }
}
