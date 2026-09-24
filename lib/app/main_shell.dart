import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/adaptive/device_form.dart';
import '../core/state/session.dart';
import '../core/theme/dimens.dart';
import '../features/books/books_screen.dart';
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

  static const _titles = ['首页', '书架', '音乐', '我的'];

  List<Widget> get _pages => [
        HomeScreen(session: widget.session),
        BooksScreen(session: widget.session),
        MusicScreen(session: widget.session),
        ProfileScreen(session: widget.session),
      ];

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);
    final pages = _pages;
    final current = pages[_index];

    final content = switch (form) {
      DeviceForm.phone => _PhoneShell(
          form: form,
          index: _index,
          onIndexChanged: (i) => setState(() => _index = i),
          body: current,
        ),
      DeviceForm.tabletPortrait => _TabletPortraitShell(
          form: form,
          index: _index,
          onIndexChanged: (i) => setState(() => _index = i),
          title: _titles[_index],
          body: current,
        ),
      DeviceForm.tabletLandscape => _SideRailShell(
          form: form,
          index: _index,
          onIndexChanged: (i) => setState(() => _index = i),
          body: current,
          showLabels: true,
        ),
      DeviceForm.tv => _SideRailShell(
          form: form,
          index: _index,
          onIndexChanged: (i) => setState(() => _index = i),
          body: current,
          showLabels: true,
          wide: true,
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
              GlassTab(icon: Icon(Icons.home_rounded), label: '首页'),
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
              GlassTab(icon: Icon(Icons.home_rounded), label: '首页'),
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
    this.wide = false,
  });

  final DeviceForm form;
  final int index;
  final ValueChanged<int> onIndexChanged;
  final Widget body;
  final bool showLabels;
  final bool wide;

  @override
  State<_SideRailShell> createState() => _SideRailShellState();
}

class _SideRailShellState extends State<_SideRailShell> {
  final List<FocusNode> _nodes = List.generate(4, (_) => FocusNode());

  static const _icons = [
    Icons.home_rounded,
    Icons.auto_stories_rounded,
    Icons.library_music_rounded,
    Icons.person_rounded,
  ];
  static const _labels = ['首页', '书架', '音乐', '我的'];

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = widget.form;
    final width = widget.wide ? Dimens.tvNavWidth : Dimens.railWidthExpanded;
    final scale = form.typeScale;

    return GlassScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      edgeToEdge: true,
      statusBarStyle: GlassStatusBarStyle.none,
      extendBody: true,
      // Content draws under the gesture bar; only the nav card keeps SafeArea.
      body: Row(
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
                            autofocus: i == 0,
                            onKeyEvent: (node, event) {
                              if (event is KeyDownEvent &&
                                  (event.logicalKey ==
                                          LogicalKeyboardKey.select ||
                                      event.logicalKey ==
                                          LogicalKeyboardKey.enter ||
                                      event.logicalKey ==
                                          LogicalKeyboardKey.gameButtonA)) {
                                widget.onIndexChanged(i);
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: Builder(
                              builder: (context) {
                                final focused = Focus.of(context).hasFocus;
                                final selected = widget.index == i;
                                return InkWell(
                                  borderRadius:
                                      BorderRadius.circular(Dimens.radiusMd),
                                  onTap: () => widget.onIndexChanged(i),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: Dimens.spacingLg,
                                      vertical: Dimens.spacingMd + 2,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        Dimens.radiusMd,
                                      ),
                                      border: focused
                                          ? Border.all(
                                              color: Colors.white,
                                              width: Dimens.focusBorder,
                                            )
                                          : null,
                                      color: selected
                                          ? Colors.white.withValues(alpha: 0.14)
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _icons[i],
                                          size: (widget.wide ? 28 : 22) *
                                              scale /
                                              form.typeScale *
                                              form.typeScale,
                                        ),
                                        const SizedBox(width: Dimens.spacingMd),
                                        Text(
                                          _labels[i],
                                          style: TextStyle(
                                            fontSize: (widget.wide ? 18 : 15) *
                                                scale,
                                            fontWeight: selected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
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
    );
  }
}
