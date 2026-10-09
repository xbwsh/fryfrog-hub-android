import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/adaptive/device_form.dart';
import '../core/state/session.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/dimens.dart';
import '../features/books/books_screen.dart';
import '../features/home/home_screen.dart';
import '../features/music/music_screen.dart';
import '../features/profile/profile_screen.dart';
import '../widgets/mini_player.dart';

/// 底部/顶部玻璃 tabbar 的四个 tab（手机与平板共用同一份）。
const _kGlassTabs = [
  GlassTab(icon: Icon(Icons.video_library_rounded), label: '视频'),
  GlassTab(icon: Icon(Icons.auto_stories_rounded), label: '书架'),
  GlassTab(icon: Icon(Icons.library_music_rounded), label: '音乐'),
  GlassTab(icon: Icon(Icons.person_rounded), label: '我的'),
];

/// 底部 tabbar 的液态玻璃材质：比控件默认更厚、更"像玻璃"——
/// 更强的磨砂背模糊与折射、更高的色彩饱和、明显的边缘勾光，
/// 让浮动胶囊在任意内容背景上都更有立体感。
const _kTabBarGlass = LiquidGlassSettings(
  glassColor: AppColors.glassBar,
  thickness: 36,
  blur: 8,
  chromaticAberration: 0.4,
  lightIntensity: 0.7,
  ambientStrength: 1.2,
  ambientRim: 0.45,
  refractiveIndex: 1.55,
  saturation: 1.0,
  glowIntensity: 0.85,
  shadowElevation: 2,
);

/// 选中 pill 的镜片材质：保持折射透镜特性（库要求 blur 恒为 0），
/// 加一点白色填充和更深的曲率，让透镜从条上"浮"出来。
final _kTabPillGlass = AnimatedGlassIndicator.baseIndicatorSettings.copyWith(
  glassColor: AppColors.glassPill,
  thickness: 28,
  refractiveIndex: 1.2,
  // iOS 26 选中 pill 边缘的虹彩折射参考值。
  chromaticAberration: 0.15,
);

/// 选中态统一用 `AppColors.accent`（与轮播图/详情页播放按钮同一个蓝）。
///
/// `GlassTabBar` 是三方玻璃控件，**不读** Material 的 `NavigationBarTheme`，
/// 所以必须显式给色；否则选中态会是控件自带的颜色，与播放按钮对不上。
const _kTabIndicatorAlpha = 0.22;

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

  /// IndexedStack 里的页都常驻，子页看不到自己的可见性；把当前 tab 索引
  /// 单独挂一个 ValueNotifier，"我的"页据此决定要不要轮询服务器延迟。
  final ValueNotifier<int> _tabIndex = ValueNotifier<int>(0);

  void _setIndex(int i) {
    if (i == _index) return;
    _index = i;
    _tabIndex.value = i;
    setState(() {});
  }

  // Pages are long-lived inside the IndexedStack below — keep instances
  // stable so switching tabs does not recreate State.
  late final List<Widget> _pages = [
    HomeScreen(session: widget.session),
    BooksScreen(session: widget.session),
    MusicScreen(session: widget.session),
    ValueListenableBuilder<int>(
      valueListenable: _tabIndex,
      builder: (_, index, _) =>
          ProfileScreen(session: widget.session, active: index == 3),
    ),
  ];

  @override
  void dispose() {
    _tabIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);

    // IndexedStack keeps inactive tabs mounted: switching keeps scroll
    // position, avoids re-decoding images and stops the home carousel
    // timer from restarting on every return.
    //
    // TickerMode mutes tickers of hidden tabs: without it the home carousel
    // keeps auto-advancing (animateToPage every 5s) while the user scrolls
    // another tab, stealing frames and causing hitches.
    final body = IndexedStack(
      index: _index,
      children: [
        for (var i = 0; i < _pages.length; i++)
          TickerMode(enabled: _index == i, child: _pages[i]),
      ],
    );

    final content = switch (form) {
      DeviceForm.phone => _PhoneShell(
        form: form,
        index: _index,
        onIndexChanged: _setIndex,
        body: body,
      ),
      DeviceForm.tabletPortrait => _TabletPortraitShell(
        index: _index,
        onIndexChanged: _setIndex,
        body: body,
      ),
      DeviceForm.tabletLandscape => _SideRailShell(
        form: form,
        index: _index,
        onIndexChanged: _setIndex,
        body: body,
        showLabels: true,
        session: widget.session,
      ),
      DeviceForm.tv => _SideRailShell(
        form: form,
        index: _index,
        onIndexChanged: _setIndex,
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
      // 去掉滚动时屏幕底部的那层玻璃模糊遮罩（用户要求），tabbar 保持玻璃透明。
      bottomEdgeFade: false,
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
            settings: _kTabBarGlass,
            indicatorSettings: _kTabPillGlass,
            innerBlur: 5,
            magnification: 1.2,
            glowBlurRadius: 40,
            glowSpreadRadius: 10,
            glowOpacity: 0.65,
            indicatorColor: AppColors.accent.withValues(
              alpha: _kTabIndicatorAlpha,
            ),
            selectedIconColor: AppColors.accent,
            selectedLabelColor: AppColors.accent,
            interactionGlowColor: AppColors.accent,
            tabs: _kGlassTabs,
          ),
        ),
      ),
    );
  }
}

class _TabletPortraitShell extends StatelessWidget {
  const _TabletPortraitShell({
    required this.index,
    required this.onIndexChanged,
    required this.body,
  });

  final int index;
  final ValueChanged<int> onIndexChanged;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      edgeToEdge: true,
      statusBarStyle: GlassStatusBarStyle.none,
      extendBody: true,
      bottomEdgeFade: false,
      edgeStyle: GlassScrollEdgeStyle.blur,
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
            settings: _kTabBarGlass,
            indicatorSettings: _kTabPillGlass,
            innerBlur: 5,
            magnification: 1.2,
            glowBlurRadius: 40,
            glowSpreadRadius: 10,
            glowOpacity: 0.65,
            indicatorColor: AppColors.accent.withValues(
              alpha: _kTabIndicatorAlpha,
            ),
            selectedIconColor: AppColors.accent,
            selectedLabelColor: AppColors.accent,
            interactionGlowColor: AppColors.accent,
            tabs: _kGlassTabs,
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

  /// TV variant: wider rail + large focus targets.
  final bool wide;

  @override
  State<_SideRailShell> createState() => _SideRailShellState();
}

class _SideRailShellState extends State<_SideRailShell> {
  final List<FocusNode> _nodes = List.generate(4, (_) => FocusNode());
  final FocusNode _logoutNode = FocusNode();

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
    _logoutNode.dispose();
    super.dispose();
  }

  void _select(int i) {
    widget.onIndexChanged(i);
    _nodes[i].requestFocus();
  }

  void _logout() {
    _logoutNode.requestFocus();
    widget.session.logout();
  }

  @override
  Widget build(BuildContext context) {
    final form = widget.form;
    final width = widget.wide ? Dimens.tvNavWidth : Dimens.railWidthExpanded;
    final scale = form.typeScale;
    final scheme = Theme.of(context).colorScheme;

    return GlassScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      edgeToEdge: true,
      statusBarStyle: GlassStatusBarStyle.none,
      extendBody: true,
      bottomEdgeFade: false,
      edgeStyle: GlassScrollEdgeStyle.blur,
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
                            // Keep D-pad focus on the active tab, not always Home.
                            autofocus: i == widget.index,
                            onKeyEvent: (node, event) {
                              if (event is KeyDownEvent &&
                                  (event.logicalKey ==
                                          LogicalKeyboardKey.select ||
                                      event.logicalKey ==
                                          LogicalKeyboardKey.enter ||
                                      event.logicalKey ==
                                          LogicalKeyboardKey.gameButtonA)) {
                                _select(i);
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: Builder(
                              builder: (context) {
                                final focused = Focus.of(context).hasFocus;
                                final selected = widget.index == i;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(
                                    Dimens.radiusMd,
                                  ),
                                  onTap: () => _select(i),
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
                                          size: (widget.wide ? 28 : 22) * scale,
                                          color: selected
                                              ? scheme.primary
                                              : null,
                                        ),
                                        const SizedBox(width: Dimens.spacingMd),
                                        Text(
                                          _labels[i],
                                          style: TextStyle(
                                            fontSize:
                                                (widget.wide ? 18 : 15) * scale,
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
                      const Spacer(),
                      // 退出登录收到底部居中：我的页里不再放，侧栏是横屏
                      // 平板/TV 的常驻导航，退出放这里随手可达。
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimens.spacingSm,
                          vertical: Dimens.spacingXs,
                        ),
                        child: Focus(
                          focusNode: _logoutNode,
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent &&
                                (event.logicalKey ==
                                        LogicalKeyboardKey.select ||
                                    event.logicalKey ==
                                        LogicalKeyboardKey.enter ||
                                    event.logicalKey ==
                                        LogicalKeyboardKey.gameButtonA)) {
                              _logout();
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: Builder(
                            builder: (context) {
                              final focused = Focus.of(context).hasFocus;
                              return InkWell(
                                borderRadius: BorderRadius.circular(
                                  Dimens.radiusMd,
                                ),
                                onTap: _logout,
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
                                            color: scheme.primary,
                                            width: Dimens.focusBorder,
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.logout_rounded,
                                        size:
                                            (widget.wide ? 28 : 22) * scale,
                                        color: AppColors.danger,
                                      ),
                                      const SizedBox(
                                        width: Dimens.spacingMd,
                                      ),
                                      Text(
                                        '退出登录',
                                        style: TextStyle(
                                          fontSize:
                                              (widget.wide ? 18 : 15) * scale,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.danger,
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
                      const SizedBox(height: Dimens.spacingMd),
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
