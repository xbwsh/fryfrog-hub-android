import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/media_models.dart';
import '../../core/models/video.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../widgets/server_image.dart';

/// 倍数文案：`1.0X` / `0.75X`（整数补一位小数、大写 X，与原型一致）。
String formatSpeed(double rate) {
  final text = rate == rate.roundToDouble() ? rate.toStringAsFixed(1) : '$rate';
  return '${text}X';
}

/// 播放器右侧「选集」抽屉（数字 / 列表 / 网格 / 大图 四种样式）。
///
/// 常驻 Stack：关着时整体滑出屏幕右侧并忽略指针，样式选择在开合间保留。
/// 只挂载当前样式 pane；打开 / 换集时 [_scrollEpoch] +1，
/// 让当前 pane 把「当前集」滚进视野（各 pane 固定 itemExtent，偏移可直接算）。
class EpisodeDrawer extends StatefulWidget {
  const EpisodeDrawer({
    super.key,
    required this.open,
    required this.episodes,
    required this.currentId,
    required this.onClose,
    required this.onPick,
  });

  final bool open;
  final List<VideoItem> episodes;
  final int currentId;
  final VoidCallback onClose;
  final ValueChanged<VideoItem> onPick;

  @override
  State<EpisodeDrawer> createState() => _EpisodeDrawerState();
}

/// 四种缩略图样式；默认「数字」（原型同款）。
enum _EpisodeStyle {
  num('数字'),
  list('列表'),
  grid('网格'),
  big('大图');

  const _EpisodeStyle(this.label);

  final String label;
}

class _EpisodeDrawerState extends State<EpisodeDrawer> {
  _EpisodeStyle _style = _EpisodeStyle.num;

  /// 打开抽屉 / 换集时 +1：当前 pane 据此滚到当前集。
  int _scrollEpoch = 0;

  @override
  void didUpdateWidget(EpisodeDrawer old) {
    super.didUpdateWidget(old);
    if ((widget.open && !old.open) || widget.currentId != old.currentId) {
      _scrollEpoch++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = AdaptiveScope.of(context).typeScale;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = math.min(
      Dimens.playerDrawerWidth,
      screenWidth * Dimens.playerDrawerWidthFraction,
    );

    return AnimatedSlide(
      offset: widget.open ? Offset.zero : const Offset(1, 0),
      duration: const Duration(milliseconds: 380),
      curve: const Cubic(0.22, 0.9, 0.3, 1),
      child: AnimatedOpacity(
        opacity: widget.open ? 1 : 0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: IgnorePointer(
          ignoring: !widget.open,
          child: Container(
            width: width,
            decoration: const BoxDecoration(
              color: AppColors.backgroundDark,
              border: Border(left: BorderSide(color: Colors.white12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 24,
                  offset: Offset(-8, 0),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(scale),
                const Divider(height: 1, thickness: 1, color: Colors.white10),
                // 关着时静音 pane 内的 EQ 动画（TickerMode 遵从 Animate 开关）。
                Expanded(
                  child: TickerMode(
                    enabled: widget.open,
                    child: _buildPane(scale),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(double scale) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.spacingLg,
        Dimens.spacingLg,
        Dimens.spacingMd,
        Dimens.spacingSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '选集',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: Dimens.spacingSm),
              Text(
                '全 ${widget.episodes.length} 集',
                style: TextStyle(color: Colors.white54, fontSize: 12 * scale),
              ),
              const Spacer(),
              IconButton(
                onPressed: widget.onClose,
                tooltip: '关闭',
                icon: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Colors.white70,
                ),
                style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(
                    Colors.white.withValues(alpha: 0.08),
                  ),
                  foregroundColor: const WidgetStatePropertyAll(Colors.white70),
                  minimumSize: const WidgetStatePropertyAll(Size(28, 28)),
                  maximumSize: const WidgetStatePropertyAll(Size(28, 28)),
                  padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Dimens.radiusSm),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimens.spacingSm),
          _StyleSwitch(
            selected: _style,
            scale: scale,
            onChanged: (style) => setState(() => _style = style),
          ),
        ],
      ),
    );
  }

  Widget _buildPane(double scale) {
    final common = (
      episodes: widget.episodes,
      currentId: widget.currentId,
      scrollEpoch: _scrollEpoch,
      open: widget.open,
      scale: scale,
      onPick: widget.onPick,
    );
    switch (_style) {
      case _EpisodeStyle.num:
        return _NumPane(
          episodes: common.episodes,
          currentId: common.currentId,
          scrollEpoch: common.scrollEpoch,
          open: common.open,
          scale: common.scale,
          onPick: common.onPick,
        );
      case _EpisodeStyle.list:
        return _ListPane(
          episodes: common.episodes,
          currentId: common.currentId,
          scrollEpoch: common.scrollEpoch,
          open: common.open,
          scale: common.scale,
          onPick: common.onPick,
        );
      case _EpisodeStyle.grid:
        return _GridPane(
          episodes: common.episodes,
          currentId: common.currentId,
          scrollEpoch: common.scrollEpoch,
          open: common.open,
          scale: common.scale,
          onPick: common.onPick,
        );
      case _EpisodeStyle.big:
        return _BigPane(
          episodes: common.episodes,
          currentId: common.currentId,
          scrollEpoch: common.scrollEpoch,
          open: common.open,
          scale: common.scale,
          onPick: common.onPick,
        );
    }
  }
}

/// 样式切换段控件（原型 .style-switch）：容器 white6%，选中 chip accent16%。
class _StyleSwitch extends StatelessWidget {
  const _StyleSwitch({
    required this.selected,
    required this.scale,
    required this.onChanged,
  });

  final _EpisodeStyle selected;
  final double scale;
  final ValueChanged<_EpisodeStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Dimens.spacingXs),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Dimens.radiusMd),
      ),
      child: Row(
        children: [
          for (final style in _EpisodeStyle.values) ...[
            if (style != _EpisodeStyle.values.first)
              const SizedBox(width: Dimens.spacingXs),
            Expanded(child: _chip(context, style)),
          ],
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, _EpisodeStyle style) {
    final active = style == selected;
    return Material(
      color: active
          ? AppColors.accentOf(context).withValues(alpha: 0.16)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(Dimens.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(Dimens.radiusSm),
        onTap: () => onChanged(style),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Dimens.spacingXs),
          child: Center(
            child: Text(
              style.label,
              style: TextStyle(
                color: active ? AppColors.accentOf(context) : Colors.white54,
                fontSize: 12 * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 四种样式共用的滚动状态：固定 itemExtent / 格子尺寸 →
/// 「滚到正中」的目标偏移可直接按 index 算，不依赖懒加载先把目标 item 构出来。
abstract class _EpisodePane extends StatefulWidget {
  const _EpisodePane({
    required this.episodes,
    required this.currentId,
    required this.scrollEpoch,
    required this.open,
    required this.scale,
    required this.onPick,
  });

  final List<VideoItem> episodes;
  final int currentId;
  final int scrollEpoch;
  final bool open;
  final double scale;
  final ValueChanged<VideoItem> onPick;
}

abstract class _EpisodePaneState<T extends _EpisodePane> extends State<T> {
  final ScrollController _scroll = ScrollController();

  /// 单个 item 的纵向节拍（含间距）；子类在 LayoutBuilder 里填写。
  double _pitch = 0;

  /// 滚动视口高度；子类在 LayoutBuilder 里填写。
  double _viewport = 0;

  /// 子类实现：index 对应 item 滚到正中时的滚动偏移（未减视口）。
  double _targetFor(int index);

  int get _activeIndex =>
      widget.episodes.indexWhere((e) => e.id == widget.currentId);

  @override
  void initState() {
    super.initState();
    _scheduleScroll();
  }

  @override
  void didUpdateWidget(covariant T old) {
    super.didUpdateWidget(old);
    if (old.scrollEpoch != widget.scrollEpoch) _scheduleScroll();
  }

  void _scheduleScroll() {
    if (!widget.open) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.open) _scrollToActive();
    });
  }

  void _scrollToActive() {
    if (_pitch <= 0 || _viewport <= 0 || !_scroll.hasClients) return;
    final index = _activeIndex;
    if (index < 0) return;
    final target = (_targetFor(index) - _viewport / 2).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }
}

// ── 样式一：纯数字宫格 ───────────────────────────────────────────────

class _NumPane extends _EpisodePane {
  const _NumPane({
    required super.episodes,
    required super.currentId,
    required super.scrollEpoch,
    required super.open,
    required super.scale,
    required super.onPick,
  });

  @override
  State<_NumPane> createState() => _NumPaneState();
}

class _NumPaneState extends _EpisodePaneState<_NumPane> {
  static const EdgeInsets _padding = EdgeInsets.fromLTRB(
    Dimens.spacingLg,
    Dimens.spacingMd,
    Dimens.spacingLg,
    Dimens.spacingXl,
  );

  int _cols = 1;

  @override
  double _targetFor(int index) =>
      Dimens.spacingMd + (index ~/ _cols) * _pitch + _pitch / 2;

  @override
  Widget build(BuildContext context) {
    const gap = Dimens.spacingSm;
    return LayoutBuilder(
      builder: (context, constraints) {
        // GridView 的 padding 在内部再裁掉左右，先算内容宽。
        final contentW = constraints.maxWidth - Dimens.spacingLg * 2;
        _cols = math.max(
          1,
          ((contentW + gap) / (Dimens.playerNumCellMaxExtent + gap)).ceil(),
        );
        final cell = (contentW - (_cols - 1) * gap) / _cols;
        _pitch = cell + gap;
        _viewport = constraints.maxHeight;
        return GridView.builder(
          controller: _scroll,
          padding: _padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _cols,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            childAspectRatio: 1,
          ),
          itemCount: widget.episodes.length,
          itemBuilder: (context, index) => _cell(widget.episodes[index], index),
        );
      },
    );
  }

  Widget _cell(VideoItem ep, int index) {
    final active = ep.id == widget.currentId;
    final scale = widget.scale;
    final onAccent = Theme.of(context).colorScheme.onPrimary;
    return Material(
      color: active
          ? AppColors.accentOf(context)
          : Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(Dimens.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(Dimens.radiusMd),
        onTap: () => widget.onPick(ep),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Text(
                ep.episodeNumber?.toString() ?? '${index + 1}',
                style: TextStyle(
                  color: active ? onAccent : Colors.white70,
                  fontSize: 14 * scale,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            // 原型此处是 VIP 圆点位；我们没有 VIP 数据 → 借位放「已看完」绿点。
            if (ep.isWatched)
              Positioned(
                top: Dimens.spacingXs,
                right: Dimens.spacingXs,
                child: Container(
                  width: Dimens.spacingSm,
                  height: Dimens.spacingSm,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? onAccent.withValues(alpha: 0.7)
                        : AppColors.success,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 样式二：竖向缩略图列表 ───────────────────────────────────────────

class _ListPane extends _EpisodePane {
  const _ListPane({
    required super.episodes,
    required super.currentId,
    required super.scrollEpoch,
    required super.open,
    required super.scale,
    required super.onPick,
  });

  @override
  State<_ListPane> createState() => _ListPaneState();
}

class _ListPaneState extends _EpisodePaneState<_ListPane> {
  static const EdgeInsets _padding = EdgeInsets.fromLTRB(
    Dimens.spacingLg,
    Dimens.spacingMd,
    Dimens.spacingLg,
    Dimens.spacingXl,
  );

  static final double _thumbH = Dimens.playerEpisodeThumbWidth * 9 / 16;

  /// itemExtent = 缩略图 + 上下各 spacingSm + 行间 spacingSm（固定 → 偏移可算）。
  static final double _itemExtent = _thumbH + Dimens.spacingSm * 3;

  @override
  double _targetFor(int index) =>
      Dimens.spacingMd + index * _pitch + _pitch / 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _pitch = _itemExtent;
        _viewport = constraints.maxHeight;
        return ListView.builder(
          controller: _scroll,
          padding: _padding,
          itemExtent: _itemExtent,
          itemCount: widget.episodes.length,
          itemBuilder: (context, index) =>
              _row(context, widget.episodes[index]),
        );
      },
    );
  }

  Widget _row(BuildContext context, VideoItem ep) {
    final active = ep.id == widget.currentId;
    final scale = widget.scale;
    final meta = _meta(ep);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Dimens.spacingSm),
      child: Material(
        color: active
            ? AppColors.accentOf(context).withValues(alpha: 0.13)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(Dimens.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(Dimens.radiusMd),
          onTap: () => widget.onPick(ep),
          child: SizedBox(
            height: _thumbH,
            child: Row(
              children: [
                _EpisodeThumb(
                  ep: ep,
                  active: active,
                  scale: scale,
                  width: Dimens.playerEpisodeThumbWidth,
                ),
                const SizedBox(width: Dimens.spacingMd),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ep.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active
                              ? AppColors.accentOf(context)
                              : Colors.white,
                          fontSize: 13 * scale,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: Dimens.spacingXs),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11 * scale,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _meta(VideoItem ep) {
    final parts = <String>[
      if (ep.episodeNumber != null) ep.episodeLabel,
      // 时长同样先隐藏：后端把 TMDB 季详情的 runtime（整季总时长）写进了
      // 每一集 duration_minutes，所有集会显示同一个假时长。后端修好后恢复。
    ];
    return parts.join(' · ');
  }
}

// ── 样式三：双列缩略图网格 ───────────────────────────────────────────

class _GridPane extends _EpisodePane {
  const _GridPane({
    required super.episodes,
    required super.currentId,
    required super.scrollEpoch,
    required super.open,
    required super.scale,
    required super.onPick,
  });

  @override
  State<_GridPane> createState() => _GridPaneState();
}

class _GridPaneState extends _EpisodePaneState<_GridPane> {
  static const EdgeInsets _padding = EdgeInsets.fromLTRB(
    Dimens.spacingLg,
    Dimens.spacingMd,
    Dimens.spacingLg,
    Dimens.spacingXl,
  );

  static const int _cols = 2;
  static const double _gap = Dimens.spacingMd;

  @override
  double _targetFor(int index) =>
      Dimens.spacingMd + (index ~/ _cols) * _pitch + _pitch / 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentW = constraints.maxWidth - Dimens.spacingLg * 2;
        final cellW = (contentW - _gap) / _cols;
        final thumbH = cellW * 9 / 16;
        final nameH = 18 * widget.scale;
        final cellH = thumbH + Dimens.spacingSm + nameH;
        _pitch = cellH + _gap;
        _viewport = constraints.maxHeight;
        return GridView.builder(
          controller: _scroll,
          padding: _padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _cols,
            mainAxisSpacing: _gap,
            crossAxisSpacing: _gap,
            childAspectRatio: cellW / cellH,
          ),
          itemCount: widget.episodes.length,
          itemBuilder: (context, index) =>
              _card(widget.episodes[index], thumbH, nameH),
        );
      },
    );
  }

  Widget _card(VideoItem ep, double thumbH, double nameH) {
    final active = ep.id == widget.currentId;
    final scale = widget.scale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: thumbH,
          child: _EpisodeThumb(
            ep: ep,
            active: active,
            scale: scale,
            showEq: true,
          ),
        ),
        const SizedBox(height: Dimens.spacingSm),
        SizedBox(
          height: nameH,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              ep.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? AppColors.accentOf(context) : Colors.white54,
                fontSize: 11.5 * scale,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 样式四：单列大图 ─────────────────────────────────────────────────

class _BigPane extends _EpisodePane {
  const _BigPane({
    required super.episodes,
    required super.currentId,
    required super.scrollEpoch,
    required super.open,
    required super.scale,
    required super.onPick,
  });

  @override
  State<_BigPane> createState() => _BigPaneState();
}

class _BigPaneState extends _EpisodePaneState<_BigPane> {
  static const EdgeInsets _padding = EdgeInsets.fromLTRB(
    Dimens.spacingLg,
    Dimens.spacingMd,
    Dimens.spacingLg,
    Dimens.spacingXl,
  );

  @override
  double _targetFor(int index) =>
      Dimens.spacingMd + index * _pitch + _pitch / 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final thumbH = constraints.maxWidth * 9 / 16;
        final infoH = 22 * widget.scale;
        _pitch = thumbH + Dimens.spacingSm + infoH + Dimens.spacingLg;
        _viewport = constraints.maxHeight;
        return ListView.builder(
          controller: _scroll,
          padding: _padding,
          itemExtent: _pitch,
          itemCount: widget.episodes.length,
          itemBuilder: (context, index) =>
              _card(widget.episodes[index], index, thumbH, infoH),
        );
      },
    );
  }

  Widget _card(VideoItem ep, int index, double thumbH, double infoH) {
    final active = ep.id == widget.currentId;
    final scale = widget.scale;
    final tag = active ? '正在播放' : (ep.resolutionLabel ?? '');
    return Padding(
      // itemExtent 里给大卡留了底部间距，卡本体只占到 info 行为止。
      padding: const EdgeInsets.only(bottom: Dimens.spacingLg),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onPick(ep),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: thumbH,
                child: _EpisodeThumb(
                  ep: ep,
                  active: active,
                  scale: scale,
                  radius: Dimens.radiusMd,
                  badgeText: '第 ${ep.episodeNumber ?? index + 1} 集',
                  // 时长暂时不显示：后端把 TMDB「季详情」的 runtime（整季总时长）
                  // 写进了每一集的 duration_minutes，导致所有集都显示同一个
                  // 假时长（实测全是 30 分钟）。等后端修好、重新刮削写入每集
                  // 真实时长后再恢复；那时只需把下面这行注释放开。
                  // durationText: minutes != null ? '$minutes 分' : null,
                ),
              ),
              const SizedBox(height: Dimens.spacingSm),
              SizedBox(
                height: infoH,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        ep.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active
                              ? AppColors.accentOf(context)
                              : Colors.white,
                          fontSize: 13.5 * scale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (tag.isNotEmpty) ...[
                      SizedBox(width: Dimens.spacingSm),
                      Text(
                        tag,
                        style: TextStyle(
                          color: active
                              ? AppColors.accentOf(context)
                              : Colors.white54,
                          fontSize: 10.5 * scale,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 缩略图公共件 ─────────────────────────────────────────────────────

/// 集缩略图：图 + 左下角标 + 可选 EQ + 当前集 accent 描边。
class _EpisodeThumb extends StatelessWidget {
  const _EpisodeThumb({
    required this.ep,
    required this.active,
    required this.scale,
    this.width,
    this.radius = Dimens.radiusSm,
    this.badgeText,
    this.showEq = false,
  });

  final VideoItem ep;
  final bool active;
  final double scale;
  final double? width;
  final double radius;
  final String? badgeText;
  final bool showEq;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final onAccent = Theme.of(context).colorScheme.onPrimary;
    final thumb = Stack(
      fit: StackFit.expand,
      children: [
        ServerImage(
          url: ep.fanartUrl ?? ep.coverUrl,
          borderRadius: borderRadius,
          placeholderColor: Colors.black26,
        ),
        // 显式传了角标文本（大图「第 N 集」/时长）→ 带底色胶囊；
        // 否则是列表/网格的纯集数角标 → 无底色白字 + 阴影。
        if (badgeText != null)
          Positioned(
            left: Dimens.spacingXs,
            bottom: Dimens.spacingXs,
            child: _badge(badgeText!, active, onAccent),
          )
        else if (ep.episodeNumber != null)
          Positioned(
            left: Dimens.spacingXs,
            bottom: Dimens.spacingXs,
            child: _numBadge(ep.episodeNumber!.toString()),
          ),
        if (showEq && active)
          Positioned(
            right: Dimens.spacingSm,
            bottom: Dimens.spacingSm,
            child: _PlayingBars(height: 11 * scale),
          ),
        if (active)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.accentOf(context),
                  width: 2,
                ),
                borderRadius: borderRadius,
              ),
            ),
          ),
      ],
    );
    if (width == null) return thumb;
    return SizedBox(width: width, height: width! * 9 / 16, child: thumb);
  }

  /// 列表/网格左下角的集数：不要黑底，白字 + 阴影保证亮画面上可读。
  Widget _numBadge(String text) {
    return Text(
      text,
      maxLines: 1,
      style: TextStyle(
        color: Colors.white,
        fontSize: 11 * scale,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
        shadows: const [
          Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
    );
  }

  Widget _badge(String text, bool active, Color onAccent) {
    // 不再铺半透明黑底：压在画面上会糊掉一块，且集数/时长这类辅助信息不该有
    // 实心胶囊。改成白字 + 阴影，和 [_numBadge] 保持一致的可读性方案。
    return Text(
      text,
      style: TextStyle(
        color: active ? onAccent : Colors.white,
        fontSize: 11 * scale,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
        shadows: const [
          Shadow(color: Colors.black87, blurRadius: 5, offset: Offset(0, 1)),
          Shadow(color: Colors.black54, blurRadius: 2),
        ],
      ),
    );
  }
}

/// 当前集缩略图右下的三根律动条（≈原型 .playing EQ）。
class _PlayingBars extends StatefulWidget {
  const _PlayingBars({this.height = 11});

  final double height;

  @override
  State<_PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<_PlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const heights = [5.0, 11.0, 7.0];
    final unit = widget.height / 11;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < heights.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            _bar(heights[i] * unit, i * 0.16),
          ],
        ],
      ),
    );
  }

  Widget _bar(double height, double delay) {
    // 同一动画用 Interval 错峰，三根各跳各的。
    final t = Curves.easeInOut
        .transform(Interval(delay, delay + 0.68).transform(_controller.value))
        .clamp(0.0, 1.0);
    return Transform.scale(
      scaleY: 0.42 + 0.58 * t,
      alignment: Alignment.bottomCenter,
      child: Container(
        width: 2.5,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.accentOf(context),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

// ── 倍速浮层 ─────────────────────────────────────────────────────────

/// 右下角「播放速度」浮层：值头 + 刻度滑条 + 拖动气泡 + 四个预设档。
///
/// 常驻 Stack，关着时缩小下移并忽略指针；气泡在拖动 / 点预设时闪现约 800ms。
class SpeedPanel extends StatefulWidget {
  const SpeedPanel({
    super.key,
    required this.open,
    required this.rate,
    required this.onChanged,
  });

  final bool open;
  final double rate;
  final ValueChanged<double> onChanged;

  @override
  State<SpeedPanel> createState() => _SpeedPanelState();
}

const List<double> _presets = [0.5, 1.0, 1.5, 2.0];

class _SpeedPanelState extends State<SpeedPanel> {
  Timer? _bubbleTimer;
  bool _bubbleVisible = false;

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    super.dispose();
  }

  void _change(double value) {
    widget.onChanged(value);
    _bubbleTimer?.cancel();
    if (!_bubbleVisible) setState(() => _bubbleVisible = true);
    _bubbleTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _bubbleVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = AdaptiveScope.of(context).typeScale;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = math.min(
      Dimens.playerSpeedPanelWidth,
      screenWidth - Dimens.spacingLg * 2,
    );
    final rate = widget.rate.clamp(0.5, 2.0);

    return AnimatedSlide(
      offset: widget.open ? Offset.zero : const Offset(0, 0.15),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: widget.open ? 1 : 0.94,
        alignment: Alignment.bottomRight,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: widget.open ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: IgnorePointer(
            ignoring: !widget.open,
            child: Container(
              width: width,
              padding: const EdgeInsets.fromLTRB(
                Dimens.spacingLg,
                Dimens.spacingMd,
                Dimens.spacingLg,
                Dimens.spacingMd,
              ),
              decoration: BoxDecoration(
                color: AppColors.backgroundDark,
                borderRadius: BorderRadius.circular(Dimens.radiusLg),
                border: Border.all(color: Colors.white12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Slider 拇指行程两端各内缩一个拇指半径 → 刻度/气泡同规则。
                  final w = constraints.maxWidth;
                  double xOf(double v) =>
                      Dimens.playerSpeedThumbRadius +
                      (v - 0.5) / 1.5 * (w - Dimens.playerSpeedThumbRadius * 2);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            '播放速度',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12 * scale,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            formatSpeed(rate),
                            style: TextStyle(
                              color: AppColors.accentOf(context),
                              fontSize: 16 * scale,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // 气泡区：定高一格，气泡贴底压在滑条上方。
                      SizedBox(
                        height: Dimens.spacingXxl,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (_bubbleVisible)
                              Positioned(
                                left:
                                    xOf(rate) -
                                    Dimens.playerSpeedBubbleWidth / 2,
                                bottom: 0,
                                child: _bubble(formatSpeed(rate), scale),
                              ),
                          ],
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          activeTrackColor: AppColors.accentOf(context),
                          inactiveTrackColor: Colors.white.withValues(
                            alpha: 0.16,
                          ),
                          thumbColor: Colors.white,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: Dimens.playerSpeedThumbRadius,
                          ),
                          overlayColor: AppColors.accentOf(context)
                              .withValues(alpha: 0.16),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                          // 刻度标签是自己画的文本行，轨道上不要 Flutter 的点状刻度。
                          tickMarkShape: SliderTickMarkShape.noTickMark,
                          showValueIndicator: ShowValueIndicator.never,
                        ),
                        child: Slider(
                          value: rate,
                          min: 0.5,
                          max: 2.0,
                          divisions: 6,
                          onChanged: _change,
                        ),
                      ),
                      const SizedBox(height: Dimens.spacingXs),
                      // 刻度标签（0.5 → 2.0，步进 0.25，与拇指同一套定位公式）。
                      SizedBox(
                        height: Dimens.spacingLg,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (var i = 0; i <= 6; i++)
                              Positioned(
                                left:
                                    xOf(0.5 + i * 0.25) -
                                    Dimens.playerSpeedTickWidth / 2,
                                child: SizedBox(
                                  width: Dimens.playerSpeedTickWidth,
                                  child: Text(
                                    _tickText(0.5 + i * 0.25),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10 * scale,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Dimens.spacingSm),
                      Row(
                        children: [
                          for (var i = 0; i < _presets.length; i++) ...[
                            if (i > 0) const SizedBox(width: Dimens.spacingSm),
                            Expanded(child: _preset(_presets[i], rate, scale)),
                          ],
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _tickText(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(1) : '$v';

  Widget _bubble(String text, double scale) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimens.spacingSm,
            vertical: Dimens.spacingXs,
          ),
          decoration: BoxDecoration(
            color: AppColors.accentOf(context),
            borderRadius: BorderRadius.circular(Dimens.radiusSm),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 11 * scale,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -4),
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 7,
              height: 7,
              color: AppColors.accentOf(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _preset(double value, double rate, double scale) {
    final selected = rate == value;
    return Material(
      color: selected
          ? AppColors.accentOf(context).withValues(alpha: 0.15)
          : Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(Dimens.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(Dimens.radiusSm),
        onTap: () => _change(value),
        child: SizedBox(
          height: Dimens.playerSpeedChipHeight,
          child: Center(
            child: Text(
              formatSpeed(value),
              style: TextStyle(
                color: selected ? AppColors.accentOf(context) : Colors.white70,
                fontSize: 12 * scale,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 播放器右下「字幕」浮层：关闭 + 本片内封字幕轨（libmpv 上报的 sid）。
///
/// 与 [SpeedPanel] 同位置同宽；纯状态less，开合动画与倍速浮层同参数。
/// 轨道列表由播放器侧过滤掉 mpv 的 `auto`/`no` 占位项后再传进来。
class SubtitlePanel extends StatelessWidget {
  const SubtitlePanel({
    super.key,
    required this.open,
    required this.tracks,
    required this.selectedId,
    required this.onPick,
    this.externalSubs = const [],
    this.onPickExternal,
    this.onClearExternal,
  });

  final bool open;

  /// 可选的内封字幕轨（已滤掉 `auto`/`no` 占位项）。
  final List<SubtitleTrack> tracks;

  /// mpv 当前生效的 sid：具体 id / `no`（关闭）/ `auto`（未定，不高亮）。
  final String? selectedId;

  final ValueChanged<SubtitleTrack> onPick;

  /// 外挂字幕（与视频同目录的 .srt/.ass）。mpv 不会自动识别，需`sub-add` 加载。
  final List<ExternalSubtitle> externalSubs;

  /// 点某个外挂字幕（已选中的传 null 表示不区分，由调用方判断高亮）。
  final ValueChanged<ExternalSubtitle>? onPickExternal;

  /// 点「关闭字幕」时清掉外挂轨。
  final VoidCallback? onClearExternal;

  /// 当前是否正挂着某个外挂字幕（用于高亮）。
  bool get hasExternalSelected => externalSubs.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final scale = AdaptiveScope.of(context).typeScale;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = math.min(
      Dimens.playerSubPanelWidth,
      screenWidth - Dimens.spacingLg * 2,
    );

    return AnimatedSlide(
      offset: open ? Offset.zero : const Offset(0, 0.15),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: open ? 1 : 0.94,
        alignment: Alignment.bottomRight,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: open ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: IgnorePointer(
            ignoring: !open,
            child: Container(
              width: width,
              padding: const EdgeInsets.fromLTRB(
                Dimens.spacingLg,
                Dimens.spacingMd,
                Dimens.spacingLg,
                Dimens.spacingMd,
              ),
              decoration: BoxDecoration(
                color: AppColors.backgroundDark,
                borderRadius: BorderRadius.circular(Dimens.radiusLg),
                border: Border.all(color: Colors.white12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '字幕',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: Dimens.spacingSm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: Dimens.playerSubPanelMaxHeight,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _row(
                            context: context,
                            label: '关闭',
                            selected: selectedId == 'no',
                            scale: scale,
                            onTap: () {
                              // 有外挂字幕挂着时，「关闭」要把外挂轨也撤掉，
                              // 否则 mpv 上还留着 sub-add 的轨，字幕不会消失。
                              onClearExternal?.call();
                              onPick(SubtitleTrack.no());
                            },
                          ),
                          for (final track in tracks)
                            _row(
                              context: context,
                              label: _label(track),
                              trailing: _trailing(track),
                              selected: selectedId == track.id,
                              scale: scale,
                              onTap: () => onPick(track),
                            ),
                          // 外挂字幕单独分组：内封轨来自容器，外挂轨来自同目录
                          // 文件，来源不同混在一起会让人以为是一回事。
                          if (externalSubs.isNotEmpty) ...[
                            const SizedBox(height: Dimens.spacingSm),
                            Text(
                              '外挂字幕',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11 * scale,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: Dimens.spacingXs),
                            for (final sub in externalSubs)
                              _row(
                                context: context,
                                label: sub.displayName,
                                trailing: sub.filename
                                    .split('.')
                                    .last
                                    .toUpperCase(),
                                selected: false,
                                scale: scale,
                                onTap: () => onPickExternal?.call(sub),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 标题优先，其次语言码，都没有就用 sid 兜底（如 `字幕 2`）。
  String _label(SubtitleTrack track) {
    final title = track.title;
    if (title != null && title.isNotEmpty) return title;
    final lang = track.language;
    if (lang != null && lang.isNotEmpty) return lang;
    return '字幕 ${track.id}';
  }

  /// 有标题时把语言码缀在行尾，区分「简体/English」这类同名轨。
  String? _trailing(SubtitleTrack track) {
    final title = track.title;
    final lang = track.language;
    if (title == null || title.isEmpty) return null;
    if (lang == null || lang.isEmpty || lang == title) return null;
    return lang;
  }

  Widget _row({
    required BuildContext context,
    required String label,
    String? trailing,
    required bool selected,
    required double scale,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected
          ? AppColors.accentOf(context).withValues(alpha: 0.15)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(Dimens.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(Dimens.radiusSm),
        onTap: onTap,
        child: SizedBox(
          height: Dimens.playerSubRowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimens.spacingXs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? AppColors.accentOf(context)
                          : Colors.white,
                      fontSize: 13 * scale,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(right: Dimens.spacingXs),
                    child: Text(
                      trailing,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11 * scale,
                      ),
                    ),
                  ),
                if (selected)
                  Icon(
                    Icons.check_rounded,
                    size: 18 * scale,
                    color: AppColors.accentOf(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
