import 'package:flutter/material.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/media_models.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../widgets/server_image.dart';
import 'video_detail_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);
    final items = widget.group.allItems;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.group.name,
          style: TextStyle(
            fontSize: 17 * form.typeScale,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
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
      body: items.isEmpty
          ? Center(
              child: Text(
                '暂无内容',
                style: TextStyle(
                  fontSize: 15 * form.typeScale,
                  color: Theme.of(context).hintColor,
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final cols = form.overviewCrossAxisCount;
                const spacing = Dimens.spacingLg;
                final cellW =
                    (constraints.maxWidth -
                        spacing * 2 -
                        spacing * (cols - 1)) /
                    cols;
                final imageH = _portrait
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
                  itemCount: items.length,
                  itemBuilder: (context, i) => _LibraryPosterCard(
                    item: items[i],
                    portrait: _portrait,
                    form: form,
                    session: widget.session,
                  ),
                );
              },
            ),
    );
  }
}

class _LibraryPosterCard extends StatelessWidget {
  const _LibraryPosterCard({
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
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<bool>(
            builder: (_) => VideoDetailScreen(session: session, item: item),
          ),
        );
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
                  if (!portrait && item.isTv)
                    Positioned(
                      left: Dimens.spacingSm,
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
          if (item.year != null)
            Text(
              '${item.year}',
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
