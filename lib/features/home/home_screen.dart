import 'package:flutter/material.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/media_models.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../widgets/server_image.dart';
import '../video/video_detail_screen.dart';
import '../video/video_library_screen.dart';
import 'home_carousel.dart';

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
        // No inner Scaffold — root Scaffold already provides Material.
        // TV keeps its title/toolbar below the inset; every other form runs
        // the carousel under the (transparent) status bar instead.
        return SafeArea(
          top: form.isTv,
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
                    // Only TV shows the big page title; phone and tablet
                    // portrait stay clean (no top chrome).
                    if (form.isTv)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Dimens.spacingLg,
                          Dimens.spacingMd,
                          Dimens.spacingLg,
                          0,
                        ),
                        child: _HomeToolbar(form: form),
                      ),
                    HomeCarousel(
                      items: session.carouselItems,
                      session: session,
                      // 详情页改过数据（绑定/元数据/封面）→ 重载目录
                      onChanged: session.loadCatalog,
                      fullBleed: !form.isTv,
                      railAligned: form.isTabletLandscape,
                      height: form.isTv
                          ? Dimens.carouselHeightTv
                          : form.isTabletLandscape
                          ? HomeCarousel.landscapeHeight(context)
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
                        version: session.catalogVersion,
                        overview: _overview,
                        onToggle: () => setState(() => _overview = !_overview),
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
                          version: session.catalogVersion,
                          session: session,
                        ),
                      ),
                    SizedBox(
                      height:
                          Dimens.dockHeight +
                          Dimens.spacingXxl +
                          MediaQuery.paddingOf(context).bottom,
                    ),
                  ],
                ),
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

class _OverviewStats extends StatefulWidget {
  const _OverviewStats({
    required this.groups,
    required this.form,
    required this.version,
    required this.overview,
    required this.onToggle,
  });

  final List<LibrarySeriesGroup> groups;
  final DeviceForm form;
  final int version;
  final bool overview;
  final VoidCallback onToggle;

  @override
  State<_OverviewStats> createState() => _OverviewStatsState();
}

class _OverviewStatsState extends State<_OverviewStats> {
  // Counts only change when the catalog itself is replaced — recompute on
  // version bumps instead of expanding + filtering every item on each
  // Session notify (which rebuilds this widget constantly).
  int _version = -1;
  List<(String, int)> _cells = const [];

  List<(String, int)> _compute() {
    final items = widget.groups.expand((g) => g.allItems).toList();
    final movies = items.where((e) => e.isStandalone && !e.isTv).length;
    final shows = items.where((e) => e.isTv).length;
    final other = items.length - movies - shows;
    return [
      ('全部', items.length),
      ('电影', movies),
      ('电视剧', shows),
      ('其他', other),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_version != widget.version) {
      _version = widget.version;
      _cells = _compute();
    }
    final form = widget.form;

    return Row(
      children: [
        for (final (label, count) in _cells)
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
        // Rail/overview toggle lives here instead of a bottom-right FAB —
        // the FAB sat under the mini player / dock and was unreachable on
        // tablets, which have no FAB at all.
        const SizedBox(width: Dimens.spacingSm),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Dimens.spacingMd),
          child: Material(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(Dimens.radiusLg),
            child: InkWell(
              borderRadius: BorderRadius.circular(Dimens.radiusLg),
              onTap: widget.onToggle,
              child: Tooltip(
                message: widget.overview ? '分库显示' : '总览显示',
                child: SizedBox(
                  width: 48,
                  height: 46,
                  child: Icon(
                    widget.overview
                        ? Icons.view_agenda_rounded
                        : Icons.grid_view_rounded,
                    size: 22 * form.typeScale,
                  ),
                ),
              ),
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
                  key: ValueKey(item.id),
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

class _OverviewGrid extends StatefulWidget {
  const _OverviewGrid({
    required this.groups,
    required this.form,
    required this.version,
    this.session,
  });

  final List<LibrarySeriesGroup> groups;
  final DeviceForm form;
  final int version;
  final Session? session;

  @override
  State<_OverviewGrid> createState() => _OverviewGridState();
}

class _OverviewGridState extends State<_OverviewGrid> {
  // The expand() below allocates a full list — recompute only when the
  // catalog itself is replaced, not on every Session notify.
  int _version = -1;
  List<SeriesListDto> _items = const [];

  @override
  Widget build(BuildContext context) {
    if (_version != widget.version) {
      _version = widget.version;
      _items = widget.groups.expand((g) => g.allItems).toList();
    }
    final items = _items;
    final form = widget.form;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: form.overviewCrossAxisCount,
        mainAxisSpacing: Dimens.spacingMd,
        crossAxisSpacing: Dimens.spacingMd,
        childAspectRatio: 0.62,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        return PosterCard(
          key: ValueKey(items[i].id),
          item: items[i],
          form: form,
          session: widget.session,
        );
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
          : () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) =>
                      VideoDetailScreen(session: session!, item: item),
                ),
              );
              // 详情页改过数据 → 重载目录，避免新名字要杀进程才可见
              if (changed == true) await session!.loadCatalog();
            },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: SizedBox.expand(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ServerImage(
                    url: item.coverUrl,
                    borderRadius: BorderRadius.circular(Dimens.radiusMd),
                  ),
                  if (item.isAdult || (item.rating != null && item.rating! > 0))
                    Positioned(
                      top: Dimens.spacingXs,
                      left: Dimens.spacingXs,
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
        ],
      ),
    );
  }
}
