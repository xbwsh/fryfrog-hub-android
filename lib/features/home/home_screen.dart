import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/media_models.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../widgets/server_image.dart';
import '../video/video_detail_screen.dart';
import '../video/video_library_screen.dart';

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
                          child: _HomeToolbar(form: form),
                        ),
                      _Carousel(
                        items: session.carouselItems,
                        session: session,
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
                      if (!_overview)
                        for (final g in session.videoGroups)
                          _LibraryRail(group: g, form: form, session: session)
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Dimens.spacingLg,
                          ),
                          child: _OverviewGrid(
                            groups: session.videoGroups,
                            form: form,
                            session: session,
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
  const _HomeToolbar({required this.form});

  final DeviceForm form;

  @override
  Widget build(BuildContext context) {
    return Text(
      '视频',
      style: TextStyle(
        fontSize: 28 * form.typeScale,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _Carousel extends StatefulWidget {
  const _Carousel({required this.items, required this.height, this.session});

  final List<SeriesListDto> items;
  final double height;
  final Session? session;

  @override
  State<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<_Carousel> {
  static const _autoPlayInterval = Duration(seconds: 5);

  final _controller = PageController(viewportFraction: 0.92);
  Timer? _autoPlay;
  bool _userInteracting = false;
  double formScale = 1;

  @override
  void initState() {
    super.initState();
    _restartAutoPlay();
  }

  @override
  void didUpdateWidget(covariant _Carousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) _restartAutoPlay();
  }

  void _restartAutoPlay() {
    _autoPlay?.cancel();
    if (widget.items.length <= 1) return;
    _autoPlay = Timer.periodic(_autoPlayInterval, (_) => _advance());
  }

  void _advance() {
    // Skip while the user is dragging, or when this route is covered
    // (pushed detail screen) — resume on ScrollEnd / return.
    if (!mounted || _userInteracting) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    if (!_controller.hasClients) return;

    final count = widget.items.length;
    final current = _controller.page?.round() ?? 0;
    final next = current + 1;
    if (next >= count) {
      // PageView can't animate past the last page — hard-cut back to start.
      _controller.jumpToPage(0);
    } else {
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _autoPlay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    formScale = AdaptiveScope.of(context).typeScale;
    if (widget.items.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: Text('暂无推荐内容')),
      );
    }

    return SizedBox(
      height: widget.height,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            _userInteracting = true;
          } else if (notification is ScrollEndNotification) {
            _userInteracting = false;
          }
          return false;
        },
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.items.length,
          itemBuilder: (context, i) {
            final item = widget.items[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimens.spacingSm),
              child: InkWell(
                onTap: widget.session == null
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute<bool>(
                            builder: (_) => VideoDetailScreen(
                              session: widget.session!,
                              item: item,
                            ),
                          ),
                        );
                      },
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
                            const SizedBox(height: Dimens.spacingXs),
                            Row(
                              children: [
                                Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: AppColors.accent,
                                  size: 28 * formScale,
                                ),
                                const SizedBox(width: Dimens.spacingXs),
                                Text(
                                  item.isTv ? '播放剧集' : '播放',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
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
  const _LibraryRail({required this.group, required this.form, this.session});

  final LibrarySeriesGroup group;
  final DeviceForm form;
  final Session? session;

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
            child: InkWell(
              borderRadius: BorderRadius.circular(Dimens.radiusSm),
              onTap: session == null
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<bool>(
                          builder: (_) => VideoLibraryScreen(
                            session: session!,
                            group: group,
                          ),
                        ),
                      );
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Dimens.spacingXs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      group.name,
                      style: TextStyle(
                        fontSize: 20 * form.typeScale,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: Dimens.spacingXs),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20 * form.typeScale,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Dimens.spacingMd),
          SizedBox(
            height: posterH + 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Dimens.spacingLg),
              itemCount: group.allItems.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: Dimens.spacingMd),
              itemBuilder: (context, i) {
                final item = group.allItems[i];
                return SizedBox(
                  width: posterW,
                  height: posterH + 40,
                  child: PosterCard(item: item, form: form, session: session),
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
  const _OverviewGrid({required this.groups, required this.form, this.session});

  final List<LibrarySeriesGroup> groups;
  final DeviceForm form;
  final Session? session;

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
        return PosterCard(item: items[i], form: form, session: session);
      },
    );
  }
}

class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.item,
    required this.form,
    this.session,
  });

  final SeriesListDto item;
  final DeviceForm form;
  final Session? session;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Dimens.radiusMd),
      onTap: session == null
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute<bool>(
                  builder: (_) =>
                      VideoDetailScreen(session: session!, item: item),
                ),
              );
            },
      child: Column(
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
      ),
    );
  }
}
