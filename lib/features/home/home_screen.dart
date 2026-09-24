import 'package:flutter/material.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/media_models.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../widgets/server_image.dart';

/// Home mirrors apple HomeView: carousel → overview stats → library rails.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.session});

  final Session session;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _overview = false;

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);
    final session = widget.session;

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: session.isLoadingCatalog && session.videoGroups.isEmpty
                ? const Center(child: CircularProgressIndicator.adaptive())
                : session.catalogError != null &&
                        session.videoGroups.isEmpty &&
                        session.musicGroups.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(Dimens.spacingXl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '内容加载失败',
                                style: TextStyle(
                                  fontSize: 17 * form.typeScale,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: Dimens.spacingSm),
                              Text(
                                session.catalogError!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13 * form.typeScale,
                                  color: Theme.of(context).hintColor,
                                ),
                              ),
                              const SizedBox(height: Dimens.spacingLg),
                              FilledButton(
                                onPressed: session.loadCatalog,
                                child: const Text('重试'),
                              ),
                            ],
                          ),
                        ),
                      )
                    // ListView (not CustomScrollView) — avoids sliver type crashes
                    // when a child fails and becomes ErrorWidget.
                    : ListView(
              padding: EdgeInsets.zero,
              children: [
                if (form.prefersTopTabs || form.isTv)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Dimens.spacingLg,
                      Dimens.spacingMd,
                      Dimens.spacingLg,
                      0,
                    ),
                    child: _HomeToolbar(session: session, form: form),
                  ),
                _Carousel(
                  items: session.carouselItems,
                  height: form.isTv
                      ? Dimens.carouselHeightTv
                      : form.isTablet
                          ? Dimens.carouselHeightTablet
                          : Dimens.carouselHeightPhone,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimens.spacingLg,
                    vertical: Dimens.spacingLg,
                  ),
                  child: _OverviewStats(
                    groups: session.videoGroups,
                    form: form,
                  ),
                ),
                if (session.contentMode == HomeContentMode.video) ...[
                  if (!_overview)
                    for (final g in session.videoGroups)
                      _LibraryRail(group: g, form: form)
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimens.spacingLg,
                      ),
                      child: _OverviewGrid(
                        groups: session.videoGroups,
                        form: form,
                      ),
                    ),
                ] else
                  Padding(
                    padding: const EdgeInsets.all(Dimens.spacingLg),
                    child: _MusicHomeSection(
                      albums: session.albums,
                      artists: session.artists,
                      form: form,
                    ),
                  ),
                const SizedBox(
                  height: Dimens.dockHeight + Dimens.spacingXxl,
                ),
              ],
            ),
          ),
          floatingActionButton: form.isPhone
              ? FloatingActionButton.small(
                  heroTag: 'home-mode',
                  backgroundColor: AppColors.accent,
                  onPressed: () => setState(() => _overview = !_overview),
                  child: Icon(
                    _overview
                        ? Icons.view_agenda_rounded
                        : Icons.grid_view_rounded,
                    color: Colors.white,
                  ),
                )
              : null,
        );
      },
    );
  }
}

class _HomeToolbar extends StatelessWidget {
  const _HomeToolbar({required this.session, required this.form});

  final Session session;
  final DeviceForm form;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '首页',
          style: TextStyle(
            fontSize: 28 * form.typeScale,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        SegmentedButton<HomeContentMode>(
          segments: const [
            ButtonSegment(value: HomeContentMode.video, label: Text('视频')),
            ButtonSegment(value: HomeContentMode.music, label: Text('音乐')),
          ],
          selected: {session.contentMode},
          onSelectionChanged: (s) => session.setContentMode(s.first),
        ),
      ],
    );
  }
}

class _Carousel extends StatefulWidget {
  const _Carousel({required this.items, required this.height});

  final List<SeriesListDto> items;
  final double height;

  @override
  State<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<_Carousel> {
  final _controller = PageController(viewportFraction: 0.92);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: Text('暂无推荐内容')),
      );
    }

    return SizedBox(
      height: widget.height,
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.items.length,
        itemBuilder: (context, i) {
          final item = widget.items[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimens.spacingSm),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Dimens.radiusLg),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ServerImage(
                    url: item.fanartUrl ?? item.coverUrl,
                    borderRadius: BorderRadius.zero,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.05),
                          Colors.black.withValues(alpha: 0.72),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: Dimens.spacingLg,
                    right: Dimens.spacingLg,
                    bottom: Dimens.spacingLg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.displayTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (item.year != null)
                          Text(
                            '${item.year}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OverviewStats extends StatelessWidget {
  const _OverviewStats({required this.groups, required this.form});

  final List<LibrarySeriesGroup> groups;
  final DeviceForm form;

  @override
  Widget build(BuildContext context) {
    final items = groups.expand((g) => g.allItems).toList();
    final movies = items.where((e) => e.isStandalone && !e.isTv).length;
    final shows = items.where((e) => e.isTv).length;
    final other = items.length - movies - shows;

    final cells = [
      ('全部', items.length),
      ('电影', movies),
      ('电视剧', shows),
      ('其他', other),
    ];

    return Row(
      children: [
        for (final (label, count) in cells)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: Dimens.spacingXs),
              padding: const EdgeInsets.symmetric(vertical: Dimens.spacingMd),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(Dimens.radiusLg),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 22 * form.typeScale,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12 * form.typeScale,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _LibraryRail extends StatelessWidget {
  const _LibraryRail({required this.group, required this.form});

  final LibrarySeriesGroup group;
  final DeviceForm form;

  @override
  Widget build(BuildContext context) {
    final posterW =
        (form.isTv ? Dimens.posterWidthTv : Dimens.posterWidth) *
            form.posterScale;
    final posterH = posterW * 1.5;

    return Padding(
      padding: const EdgeInsets.only(bottom: Dimens.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimens.spacingLg),
            child: Row(
              children: [
                Text(
                  group.name,
                  style: TextStyle(
                    fontSize: 20 * form.typeScale,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: Dimens.spacingXs),
                Icon(Icons.chevron_right_rounded, size: 20 * form.typeScale),
              ],
            ),
          ),
          const SizedBox(height: Dimens.spacingMd),
          SizedBox(
            height: posterH + 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: Dimens.spacingLg),
              itemCount: group.allItems.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: Dimens.spacingMd),
              itemBuilder: (context, i) {
                final item = group.allItems[i];
                return SizedBox(
                  width: posterW,
                  height: posterH + 40,
                  child: PosterCard(item: item, form: form),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  const _OverviewGrid({required this.groups, required this.form});

  final List<LibrarySeriesGroup> groups;
  final DeviceForm form;

  @override
  Widget build(BuildContext context) {
    final items = groups.expand((g) => g.allItems).toList();
    final cols = form.overviewCrossAxisCount;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: Dimens.spacingMd,
        crossAxisSpacing: Dimens.spacingMd,
        childAspectRatio: 0.62,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        return PosterCard(item: items[i], form: form);
      },
    );
  }
}

class PosterCard extends StatelessWidget {
  const PosterCard({super.key, required this.item, required this.form});

  final SeriesListDto item;
  final DeviceForm form;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: SizedBox.expand(
            child: ServerImage(
              url: item.coverUrl,
              borderRadius: BorderRadius.circular(Dimens.radiusMd),
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
      ],
    );
  }
}

class _MusicHomeSection extends StatelessWidget {
  const _MusicHomeSection({
    required this.albums,
    required this.artists,
    required this.form,
  });

  final List<MusicAlbum> albums;
  final List<MusicArtist> artists;
  final DeviceForm form;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '音乐',
          style: TextStyle(
            fontSize: 20 * form.typeScale,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: Dimens.spacingLg),
        if (artists.isNotEmpty) ...[
          Text(
            '歌手',
            style: TextStyle(
              fontSize: 15 * form.typeScale,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Dimens.spacingMd),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: artists.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: Dimens.spacingLg),
              itemBuilder: (context, i) {
                final a = artists[i];
                return SizedBox(
                  width: 76,
                  height: 100,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: ServerImage(
                          url: a.coverUrl,
                          borderRadius: BorderRadius.circular(40),
                        ),
                      ),
                      const SizedBox(height: Dimens.spacingXs),
                      Text(
                        a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12 * form.typeScale),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: Dimens.spacingXl),
        ],
        if (albums.isNotEmpty) ...[
          Text(
            '专辑',
            style: TextStyle(
              fontSize: 15 * form.typeScale,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Dimens.spacingMd),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(Dimens.radiusLg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final album in albums.take(12))
                  ListTile(
                    dense: !form.isTv,
                    leading: SizedBox(
                      width: 52,
                      height: 52,
                      child: ServerImage(url: album.coverUrl),
                    ),
                    title: Text(
                      album.title,
                      style: TextStyle(
                        fontSize: 14 * form.typeScale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      [
                        if (album.artistName != null) album.artistName!,
                        if (album.year != null) '${album.year}',
                      ].join(' · '),
                      style: TextStyle(fontSize: 12 * form.typeScale),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
