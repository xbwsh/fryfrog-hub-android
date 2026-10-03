import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/adaptive/device_form.dart';
import '../core/state/session.dart';
import '../core/theme/dimens.dart';
import '../features/books/books_screen.dart';
import '../features/home/home_carousel.dart';
import '../features/home/home_screen.dart';
import '../features/music/music_screen.dart';
import '../features/profile/profile_screen.dart';
import '../widgets/mini_player.dart';

/// Adaptive chrome matching apple MainTabView:
/// phone = glass bottom dock · tablet portrait = glass top tabs ·
/// tablet landscape / TV = expanded side rail with focus.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.session});

  final Session session;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _titles = ['视频', '书架', '音乐', '我的'];

  // Pages are long-lived inside the IndexedStack below — keep instances
  // stable so switching tabs does not recreate State.
  late final List<Widget> _pages = [
    HomeScreen(session: widget.session),
    BooksScreen(session: widget.session),
    MusicScreen(session: widget.session),
    ProfileScreen(session: widget.session),
  ];

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);

    // IndexedStack keeps inactive tabs mounted: switching keeps scroll
    // position, avoids re-decoding images and stops the home carousel
    // timer from restarting on every return.
    final body = IndexedStack(index: _index, children: _pages);

    final content = switch (form) {
      DeviceForm.phone => _PhoneShell(
        form: form,
        index: _index,
        onIndexChanged: (i) => setState(() => _index = i),
        body: body,
      ),
      DeviceForm.tabletPortrait => _TabletPortraitShell(
        form: form,
        index: _index,
        onIndexChanged: (i) => setState(() => _index = i),
        title: _titles[_index],
        body: body,
      ),
      DeviceForm.tabletLandscape => _SideRailShell(
        form: form,
        index: _index,
        onIndexChanged: (i) => setState(() => _index = i),
        body: body,
        showLabels: true,
        session: widget.session,
      ),
      DeviceForm.tv => _SideRailShell(
        form: form,
        index: _index,
        onIndexChanged: (i) => setState(() => _index = i),
        body: body,
        showLabels: true,
        wide: true,
        session: widget.session,
      ),
    };

    return content;
  }
}

class _PhoneShell extends StatelessWidget {
  const _PhoneShell({
    required this.form,
    required this.index,
    required this.onIndexChanged,
    required this.body,
  });

  final DeviceForm form;
  final int index;
  final ValueChanged<int> onIndexChanged;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      edgeToEdge: true,
      // none: avoid SystemUiOverlayStyle.light/dark presets that force an
      // opaque navigation bar behind the gesture pill. Overlay is set in app.dart.
      statusBarStyle: GlassStatusBarStyle.none,
      extendBody: true,
      // blur = live ProgressiveBlur, follows theme changes; the default
      // soft style paints a static background capture that goes stale.
      edgeStyle: GlassScrollEdgeStyle.blur,
      body: Stack(
        children: [
          Positioned.fill(child: body),
          const Positioned(
            left: Dimens.spacingMd,
            right: Dimens.spacingMd,
            bottom: Dimens.dockHeight + Dimens.spacingMd,
            child: MiniPlayerBar(),
          ),
        ],
      ),
      bottomBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimens.spacingLg,
            0,
            Dimens.spacingLg,
            Dimens.spacingSm,
          ),
          child: GlassTabBar.bottom(
            selectedIndex: index,
            onTabSelected: onIndexChanged,
            tabs: const [
              GlassTab(icon: Icon(Icons.video_library_rounded), label: '视频'),
              GlassTab(icon: Icon(Icons.auto_stories_rounded), label: '书架'),
              GlassTab(icon: Icon(Icons.library_music_rounded), label: '音乐'),
              GlassTab(icon: Icon(Icons.person_rounded), label: '我的'),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabletPortraitShell extends StatelessWidget {
  const _TabletPortraitShell({
    required this.form,
    required this.index,
    required this.onIndexChanged,
    required this.title,
    required this.body,
  });

  final DeviceForm form;
  final int index;
  final ValueChanged<int> onIndexChanged;
  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      edgeToEdge: true,
      statusBarStyle: GlassStatusBarStyle.none,
      extendBody: true,
      edgeStyle: GlassScrollEdgeStyle.blur,
      // Default +20 extends the blur 20px past the app bar onto page
      // content (carousel, segmented controls) — retract it so the fade
      // stays inside the bar area.
      topEdgeFadeExtent: -Dimens.spacingLg,
      appBar: GlassAppBar(
        title: Text(title, style: TextStyle(fontSize: 17 * form.typeScale)),
        actions: [
          GlassIconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: body),
          const Positioned(
            left: Dimens.spacingLg,
            right: Dimens.spacingLg,
            bottom: Dimens.spacingLg,
            child: MiniPlayerBar(),
          ),
        ],
      ),
      bottomBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimens.spacingXxl,
            0,
            Dimens.spacingXxl,
            Dimens.spacingSm,
          ),
          child: GlassTabBar.bottom(
            selectedIndex: index,
            onTabSelected: onIndexChanged,
            tabs: const [
              GlassTab(icon: Icon(Icons.video_library_rounded), label: '视频'),
              GlassTab(icon: Icon(Icons.auto_stories_rounded), label: '书架'),
              GlassTab(icon: Icon(Icons.library_music_rounded), label: '音乐'),
              GlassTab(icon: Icon(Icons.person_rounded), label: '我的'),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideRailShell extends StatefulWidget {
  const _SideRailShell({
    required this.form,
    required this.index,
    required this.onIndexChanged,
    required this.body,
    required this.showLabels,
    required this.session,
    this.wide = false,
  });

  final DeviceForm form;
  final int index;
  final ValueChanged<int> onIndexChanged;
  final Widget body;
  final bool showLabels;
  final Session session;

  /// TV variant: wider rail + large focus targets (TV keeps the home
  /// carousel inside HomeScreen instead of the full-width hero band).
  final bool wide;

  @override
  State<_SideRailShell> createState() => _SideRailShellState();
}

class _SideRailShellState extends State<_SideRailShell> {
  final List<FocusNode> _nodes = List.generate(4, (_) => FocusNode());

  static const _icons = [
    Icons.video_library_rounded,
    Icons.auto_stories_rounded,
    Icons.library_music_rounded,
    Icons.person_rounded,
  ];
  static const _labels = ['视频', '书架', '音乐', '我的'];

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _select(int i) {
    widget.onIndexChanged(i);
    _nodes[i].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final form = widget.form;
    final width = widget.wide ? Dimens.tvNavWidth : Dimens.railWidthExpanded;
    final scale = form.typeScale;
    final scheme = Theme.of(context).colorScheme;

    // Landscape home renders the carousel as a full-width band ABOVE the
    // rail — the rail starts below it and the hero touches all four screen
    // edges (status bar included) for the video-detail level of immersion.
    final showHero =
        !widget.wide &&
        widget.index == 0 &&
        widget.session.carouselItems.isNotEmpty;

    return GlassScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      edgeToEdge: true,
      statusBarStyle: GlassStatusBarStyle.none,
      extendBody: true,
      edgeStyle: GlassScrollEdgeStyle.blur,
      // Content draws under the gesture bar; only the nav card keeps SafeArea.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: showHero
                ? HomeCarousel(
                    items: widget.session.carouselItems,
                    session: widget.session,
                    height: HomeCarousel.landscapeHeight(context),
                    fullBleed: true,
                  )
                : const SizedBox(width: double.infinity),
          ),
          Expanded(
            child: Row(
              children: [
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(Dimens.spacingMd),
                    child: GlassCard(
                      child: SizedBox(
                        width: width,
                        child: Column(
                          children: [
                            const SizedBox(height: Dimens.spacingLg),
                            Text(
                              'Fryfrog Hub',
                              style: TextStyle(
                                fontSize: 18 * scale,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: Dimens.spacingXl),
                            for (var i = 0; i < 4; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Dimens.spacingSm,
                                  vertical: Dimens.spacingXs,
                                ),
                                child: Focus(
                                  focusNode: _nodes[i],
                                  // Keep D-pad focus on the active tab, not always Home.
                                  autofocus: i == widget.index,
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent &&
                                        (event.logicalKey ==
                                                LogicalKeyboardKey.select ||
                                            event.logicalKey ==
                                                LogicalKeyboardKey.enter ||
                                            event.logicalKey ==
                                                LogicalKeyboardKey
                                                    .gameButtonA)) {
                                      _select(i);
                                      return KeyEventResult.handled;
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: Builder(
                                    builder: (context) {
                                      final focused = Focus.of(context)
                                          .hasFocus;
                                      final selected = widget.index == i;
                                      return InkWell(
                                        borderRadius: BorderRadius.circular(
                                          Dimens.radiusMd,
                                        ),
                                        onTap: () => _select(i),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: Dimens.spacingLg,
                                            vertical: Dimens.spacingMd + 2,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              Dimens.radiusMd,
                                            ),
                                            // Focus ring only on the item that has focus.
                                            border: focused
                                                ? Border.all(
                                                    color: scheme.primary,
                                                    width: Dimens.focusBorder,
                                                  )
                                                : null,
                                            // Selection highlight is independent of focus.
                                            color: selected
                                                ? scheme.primary.withValues(
                                                    alpha: 0.16,
                                                  )
                                                : null,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                _icons[i],
                                                size:
                                                    (widget.wide ? 28 : 22) *
                                                    scale,
                                                color: selected
                                                    ? scheme.primary
                                                    : null,
                                              ),
                                              const SizedBox(
                                                width: Dimens.spacingMd,
                                              ),
                                              Text(
                                                _labels[i],
                                                style: TextStyle(
                                                  fontSize:
                                                      (widget.wide ? 18 : 15) *
                                                      scale,
                                                  fontWeight: selected
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                  color: selected
                                                      ? scheme.primary
                                                      : null,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: widget.body),
                      // Mini player floats over content; no SafeArea strip when empty.
                      const Positioned(
                        left: Dimens.spacingLg,
                        right: Dimens.spacingLg,
                        bottom: Dimens.spacingLg,
                        child: MiniPlayerBar(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
