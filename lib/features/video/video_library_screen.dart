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

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);
    final items = widget.group.allItems;
    // Admin entry into this library's unscraped backlog — same cell as a
    // poster, placeholder art, first grid position.
    final showUnscraped = widget.session.user?.isAdmin == true;

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
      // Unscraped-only libraries still need the grid: the admin entry card
      // is the only door into their backlog.
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
              leading: showUnscraped
                  ? _UnscrapedEntryCard(
                      key: const ValueKey('unscraped-entry'),
                      form: form,
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
  });

  final DeviceForm form;
  final VoidCallback onTap;

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
            '未刮削',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13 * form.typeScale,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
