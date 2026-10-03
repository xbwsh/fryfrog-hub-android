import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/media_models.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../widgets/server_image.dart';
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
  });

  final List<SeriesListDto> items;
  final double height;
  final Session? session;

  /// Full-screen hero mode: flush to the top/right screen edges (status-bar
  /// bleed, no right gutter) while the left edge sits on the same 16px line
  /// as the library rails below, with rounded left corners for a soft
  /// transition into the rail column.
  final bool fullBleed;

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

class _HomeCarouselState extends State<HomeCarousel> {
  static const _autoPlayInterval = Duration(seconds: 5);

  late PageController _controller;
  double _fraction = 0.92;
  Timer? _autoPlay;
  bool _userInteracting = false;
  double formScale = 1;

  @override
  void initState() {
    super.initState();
    _fraction = widget.fullBleed ? 1.0 : 0.92;
    _controller = PageController(viewportFraction: _fraction);
    _restartAutoPlay();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rotation can flip fullBleed (0.92 peek <-> 1.0 edge-to-edge); swap the
    // controller so the active slide never shows neighbour slivers when
    // bleeding. Old controller dies after the PageView re-attaches.
    final want = widget.fullBleed ? 1.0 : 0.92;
    if (want != _fraction) {
      _fraction = want;
      final old = _controller;
      _controller = PageController(viewportFraction: want);
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
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
              key: ValueKey(item.id),
              padding: EdgeInsets.only(
                // Left gutter matches the library rails' spacingLg so the
                // hero edge and the 分库 headers below share one line.
                left: widget.fullBleed ? Dimens.spacingLg : Dimens.spacingSm,
                right: widget.fullBleed ? 0 : Dimens.spacingSm,
              ),
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
                  borderRadius: widget.fullBleed
                      // Soft left corners facing the rails; the right side
                      // runs off the screen edge square.
                      ? BorderRadius.only(
                          topLeft: Radius.circular(Dimens.radiusLg),
                          bottomLeft: Radius.circular(Dimens.radiusLg),
                        )
                      : BorderRadius.circular(Dimens.radiusLg),
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
                      Positioned(
                        // Full-bleed sits under the status bar — clear the
                        // clock; inset modes are already below it.
                        top:
                            (widget.fullBleed
                                ? MediaQuery.paddingOf(context).top
                                : 0) +
                            Dimens.spacingSm,
                        left: Dimens.spacingLg,
                        child: Wrap(
                          spacing: Dimens.spacingXs,
                          children: [
                            if (item.isAdult)
                              const SlideBadge(
                                text: '18+',
                                color: AppColors.danger,
                              ),
                            if (item.rating != null && item.rating! > 0)
                              SlideBadge(
                                text: '★ ${item.rating!.toStringAsFixed(1)}',
                                color: Colors.white,
                              ),
                          ],
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

/// Small translucent chip for a slide/poster top-left corner (rating / 18+).
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
