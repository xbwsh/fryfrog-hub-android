import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/adaptive/device_form.dart';
import '../core/state/session.dart';
import '../widgets/server_image.dart';

/// 艺术字 Logo（TMDB clearlogo / 本地 movie-logo.png / tvshow-logo.png）。
///
/// 实测素材形状差异极大：
/// - 横向长条 1255×510、3608×1162（可用）
/// - 竖排 735×1544、375×639、202×338（放进 46px 高的槽里只剩 ~10px 宽，看不见）
/// - 极端 754×2226（同理）
/// 还有的画布很大但字很小、四周大片留白（3608×1162 的 `movie-logo.png` 几乎全白）。
///
/// 因此不能盲信宽高比：先量“不透明/非近白像素”的包围盒，只有当内容比例
/// 处在可读区间时才单独显示 logo，否则回落到文字标题（可读优先）。
class VideoLogo extends StatefulWidget {
  const VideoLogo({
    super.key,
    required this.url,
    required this.title,
    this.height = 46,
    this.session,
  });

  final String? url;
  final String title;
  final double height;
  final Session? session;

  /// 内容包围盒的宽高比可用区间：低于下限偏竖排、高于上限过于扁平。
  static const double minAspect = 1.2;
  static const double maxAspect = 8.0;
  /// 内容至少占画布这么大比例，否则视为“画布大、字很小”。
  static const double minContentRatio = 0.10;

  @override
  State<VideoLogo> createState() => _VideoLogoState();
}

class _VideoLogoState extends State<VideoLogo> {
  bool? _usable;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _measure();
  }

  @override
  void didUpdateWidget(VideoLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _usable = null;
      _measure();
    }
  }

  Future<void> _measure() async {
    final path = widget.url;
    if (path == null || path.isEmpty) {
      if (mounted) setState(() => _usable = false);
      return;
    }
    final session = widget.session ?? SessionScope.of(context);
    final resolved = path.startsWith('http')
        ? path
        : (session.resolveImage(path) ?? path);
    final token = session.token;
    try {
      final provider = NetworkImage(
        resolved,
        headers: {
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );
      final stream = provider.resolve(ImageConfiguration.empty);
      final completer = Completer<ui.Image>();
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          if (!completer.isCompleted) completer.complete(info.image);
          stream.removeListener(listener);
        },
        onError: (e, _) {
          if (!completer.isCompleted) completer.completeError(e);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      final image = await completer.future.timeout(const Duration(seconds: 6));
      final usable = await _analyze(image);
      if (mounted) setState(() => _usable = usable);
    } catch (_) {
      // 取不到尺寸就不赌，直接显示文字标题
      if (mounted) setState(() => _usable = false);
    }
  }

  /// 量非空内容的包围盒，判断这个 logo 单独显示是否可读。
  static Future<bool> _analyze(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return false;
    final w = image.width;
    final h = image.height;
    if (w == 0 || h == 0) return false;
    final bytes = data.buffer.asUint8List();

    int minX = w, minY = h, maxX = -1, maxY = -1;
    // 采样步长：大图不必逐像素（只求包围盒）
    final step = (w > 400 || h > 400) ? 2 : 1;
    for (var y = 0; y < h; y += step) {
      for (var x = 0; x < w; x += step) {
        final i = (y * w + x) * 4;
        final a = bytes[i + 3];
        if (a < 24) continue; // 透明
        final r = bytes[i], g = bytes[i + 1], b = bytes[i + 2];
        if (r > 238 && g > 238 && b > 238) continue; // 近白（白底留白）
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    if (maxX < 0 || maxY < 0) return false; // 全空白/全透明

    final contentW = (maxX - minX + 1).toDouble();
    final contentH = (maxY - minY + 1).toDouble();
    if (contentH <= 0) return false;
    final aspect = contentW / contentH;
    final ratio = (contentW * contentH) / (w * h);
    return aspect >= VideoLogo.minAspect &&
        aspect <= VideoLogo.maxAspect &&
        ratio >= VideoLogo.minContentRatio;
  }

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);
    final text = Text(
      widget.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white,
        fontSize: 20 * form.typeScale,
        fontWeight: FontWeight.w800,
        height: 1.2,
      ),
    );

    switch (_usable) {
      case null:
        // 量尺寸期间先给文字，避免出现 22px 宽的“细条”闪一下
        return text;
      case false:
        return text;
      case true:
        return SizedBox(
          height: widget.height * form.typeScale,
          width: double.infinity,
          child: ServerImage(
            url: widget.url,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            borderRadius: BorderRadius.zero,
            session: widget.session,
          ),
        );
    }
  }
}
