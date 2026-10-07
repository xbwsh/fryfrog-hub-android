import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/media_models.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../widgets/server_image.dart';
import '../../widgets/video_logo.dart';
import '../video/video_detail_screen.dart';

/// Home hero carousel shared by the phone/portrait shells (rendered inside
/// [HomeScreen]) and the tablet-landscape shell (rendered full-width above
/// the side rail by [MainShell]).
class HomeCarousel extends StatefulWidget {
  const HomeCarousel({
    super.key,
    required this.items,
    required this.height,
    this.session,
    this.fullBleed = false,
    this.railAligned = false,
    this.onChanged,
  });

  final List<SeriesListDto> items;
  final double height;
  final Session? session;

  /// 从详情页返回且页面改过数据（绑定/元数据/封面）时回调，让首页重载，
  /// 否则要杀进程才看到新名字。
  final VoidCallback? onChanged;

  /// Immersive mode: flush to the screen edges (no side gutters, no corner
  /// radius), runs under the transparent status bar and a deeper text scrim.
  final bool fullBleed;

  /// Landscape variant of [fullBleed]: left edge pulled back to the rails'
  /// 16px alignment line with rounded left corners (right stays square).
  final bool railAligned;

  /// Viewport-relative height for the tablet-landscape full-width band.
  static double landscapeHeight(BuildContext context) =>
      (MediaQuery.sizeOf(context).height *
              Dimens.carouselHeightLandscapeFraction)
          .clamp(
            Dimens.carouselHeightLandscapeMin,
            Dimens.carouselHeightLandscapeMax,
          )
          .toDouble();

  @override
  State<HomeCarousel> createState() => _HomeCarouselState();
}

class _HomeCarouselState extends State<HomeCarousel>
    with WidgetsBindingObserver {
  static const _autoPlayInterval = Duration(seconds: 5);

  late PageController _controller;
  Timer? _autoPlay;
  bool _userInteracting = false;
  double formScale = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 全宽分区：页面边缘始终与视口边缘重合，切换动画时新页滑入不会被
    // 视口直线截断，不会出现“动画中是直角、停住是圆角”的穿帮。
    _controller = PageController(viewportFraction: 1.0);
    _restartAutoPlay();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Don't keep auto-advancing while backgrounded or exiting to the home
    // screen — the 400ms page animation was fighting the launcher's exit
    // transition (very laggy home press) and burning frames in the background.
    if (state == AppLifecycleState.resumed) {
      _restartAutoPlay();
    } else {
      _autoPlay?.cancel();
    }
  }

  @override
  void didUpdateWidget(covariant HomeCarousel oldWidget) {
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
    // IndexedStack keeps this page alive on other tabs; TickerMode mutes it.
    if (!TickerMode.valuesOf(context).enabled) return;
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
    WidgetsBinding.instance.removeObserver(this);
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
              key: ValueKey(item.id),
              padding: EdgeInsets.only(
                left: !widget.fullBleed
                    ? Dimens.spacingSm
                    : widget.railAligned
                    ? Dimens.spacingLg
                    : 0,
                right: widget.fullBleed ? 0 : Dimens.spacingSm,
              ),
              child: InkWell(
                onTap: widget.session == null
                    ? null
                    : () async {
                        final changed = await Navigator.of(context).push<bool>(
                          MaterialPageRoute<bool>(
                            builder: (_) => VideoDetailScreen(
                              session: widget.session!,
                              item: item,
                            ),
                          ),
                        );
                        if (changed == true) widget.onChanged?.call();
                      },
                child: ClipRRect(
                  borderRadius: !widget.fullBleed
                      ? BorderRadius.circular(Dimens.radiusLg)
                      : widget.railAligned
                      // Soft left corners facing the rails; the right side
                      // runs off the screen edge square.
                      ? BorderRadius.only(
                          topLeft: Radius.circular(Dimens.radiusLg),
                          bottomLeft: Radius.circular(Dimens.radiusLg),
                        )
                      : BorderRadius.zero,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ServerImage(
                        url: item.fanartUrl ?? item.coverUrl,
                        borderRadius: BorderRadius.zero,
                        // Cover crops centrally by default — in the wide
                        // hero band that eats the top of the art; anchor
                        // to the top so the picture starts at the screen top.
                        alignment: widget.fullBleed
                            ? Alignment.topCenter
                            : Alignment.center,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: widget.fullBleed
                                ? [
                                    Colors.black.withValues(alpha: 0),
                                    Colors.black.withValues(alpha: 0.22),
                                    Colors.black.withValues(alpha: 0.78),
                                  ]
                                : [
                                    Colors.black.withValues(alpha: 0.05),
                                    Colors.black.withValues(alpha: 0.72),
                                  ],
                          ),
                        ),
                      ),
                      // 轮播图不显示 18+ / 评分角标：英雄图上的小标签干扰画面，
                      // 这些信息在详情页与海报网格里仍然可见。
                      Positioned(
                        left: Dimens.spacingLg,
                        right: Dimens.spacingLg,
                        bottom: Dimens.spacingLg,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 有可用 logo（TMDB clearlogo / 本地 movie-logo.png /
                            // tvshow-logo.png）就展示艺术字，形状不可读时 VideoLogo
                            // 自动回落到文字标题。
                            VideoLogo(
                              url: item.logoUrl,
                              title: item.displayTitle,
                              height: 56,
                              session: widget.session,
                              // 轮播图切换/首次进页时 logo 还没量好尺寸，
                              // 先保持透明，避免文字标题或灰块闪一下。
                              showTitleWhileLoading: false,
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

/// Bottom-right resolution chips for poster covers (e.g. 4K · 1080P).
/// Renders nothing when the item carries no resolution labels.
class ResolutionBadges extends StatelessWidget {
  const ResolutionBadges({super.key, required this.resolutions});

  final List<String> resolutions;

  static String _display(String label) {
    final lower = label.toLowerCase();
    if (lower == '1080p') return '1080P';
    if (lower == '720p') return '720P';
    if (lower == '480p') return '480P';
    if (lower == '2160p') return '4K';
    return label;
  }

  @override
  Widget build(BuildContext context) {
    if (resolutions.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: Dimens.spacingXs,
      children: [
        for (final r in resolutions)
          SlideBadge(text: _display(r), color: Colors.white),
      ],
    );
  }
}

/// Small translucent chip for a slide/poster corner (rating / 18+ / res).
class SlideBadge extends StatelessWidget {
  const SlideBadge({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimens.spacingSm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(Dimens.radiusSm),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
