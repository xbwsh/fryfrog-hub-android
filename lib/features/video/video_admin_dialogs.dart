import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../core/models/media_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../widgets/server_image.dart';
import 'cover_crop_dialog.dart';

/// Admin dialogs/sheets for the video detail page (TMDB binding, metadata
/// editing, covers, logo picking). The screen only dispatches menu actions;
/// orchestration lives in `VideoDetailController`.

/// Shows a non-dismissible progress dialog, runs [work], then closes the
/// dialog (even on error, which rethrows so callers can SnackBar).
///
/// Owns the route it pushes: `finally` only ever closes *that* dialog. A bare
/// `nav.pop()` closes whichever route happens to be on top — system back ignores
/// `barrierDismissible`, so the user can back out of the dialog mid-`work`, and
/// the unconditional pop then removed the caller's screen instead.
Future<T> runWithProgress<T>(
  BuildContext context,
  String label,
  Future<T> Function() work,
) async {
  final nav = Navigator.of(context, rootNavigator: true);
  var dismissed = false;
  // Plain Dialog (not AlertDialog): AlertDialog's min-height constraint
  // top-aligns a lone content row, which reads as "sitting too high".
  final route = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) dismissed = true;
      },
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimens.spacingXl,
            vertical: Dimens.spacingLg,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: Dimens.spacingLg),
              Flexible(child: Text(label)),
            ],
          ),
        ),
      ),
    ),
  );
  unawaited(nav.push(route));
  try {
    return await work();
  } finally {
    if (!dismissed && route.isActive) {
      if (route.isCurrent) {
        nav.pop();
      } else {
        // Something else was pushed on top while work ran — remove ours
        // specifically instead of popping whatever is now current.
        nav.removeRoute(route);
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// TMDB search & bind
// ─────────────────────────────────────────────────────────────────────────

/// Search TMDB and pick a result; pops with the chosen [TmdbSearchItem].
/// Binding + progress polling happen in the screen after the dialog closes.
class TmdbBindDialog extends StatefulWidget {
  const TmdbBindDialog({
    super.key,
    required this.onSearch,
    this.initialKeyword = '',
  });

  final Future<List<TmdbSearchItem>> Function(String query) onSearch;
  final String initialKeyword;

  @override
  State<TmdbBindDialog> createState() => _TmdbBindDialogState();
}

class _TmdbBindDialogState extends State<TmdbBindDialog> {
  late final TextEditingController _keywordCtrl = TextEditingController(
    text: widget.initialKeyword,
  );
  List<TmdbSearchItem> _results = const [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _keywordCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _keywordCtrl.text.trim();
    if (q.isEmpty || _searching) return;
    setState(() {
      _searching = true;
      _error = null;
      _results = const [];
    });
    try {
      final results = await widget.onSearch(q);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '搜索失败：$e';
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: AppColors.surface(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(Dimens.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '搜索并绑定 TMDB',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: Dimens.spacingSm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _keywordCtrl,
                      onSubmitted: (_) => _search(),
                      decoration: const InputDecoration(
                        hintText: '输入标题搜索 TMDB',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: Dimens.spacingSm),
                  FilledButton.icon(
                    onPressed: _searching ? null : _search,
                    icon: _searching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search_rounded, size: 18),
                    label: const Text('搜索'),
                  ),
                ],
              ),
              const SizedBox(height: Dimens.spacingSm),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: Dimens.spacingSm),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              Flexible(
                child: _results.isEmpty && !_searching
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: Dimens.spacingXl,
                        ),
                        child: Center(
                          child: Text(
                            _keywordCtrl.text.isEmpty ? '输入标题关键词' : '无结果',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.hintColor,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = _results[i];
                          return ListTile(
                            dense: true,
                            leading: _TmdbPoster(posterUrl: r.posterUrl),
                            title: Text(
                              r.displayTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              [
                                if (r.year != null) '${r.year}',
                                r.isTv ? '剧集' : '电影',
                                if (r.voteAverage != null && r.voteAverage! > 0)
                                  '★ ${r.voteAverage!.toStringAsFixed(1)}',
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.hintColor,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 20,
                            ),
                            onTap: () => Navigator.pop(context, r),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// TMDB CDN thumbnail (no auth headers — must not send the Bearer token
/// to a third-party host, so plain [Image.network] instead of ServerImage).
class _TmdbPoster extends StatelessWidget {
  const _TmdbPoster({this.posterUrl});

  final String? posterUrl;

  @override
  Widget build(BuildContext context) {
    final url = posterUrl;
    return SizedBox(
      width: 40,
      height: 60,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Dimens.radiusSm),
        child: url == null
            ? Container(
                color: AppColors.surface(context),
                alignment: Alignment.center,
                child: const Icon(Icons.movie_rounded, size: 22),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.surface(context),
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_rounded, size: 20),
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Metadata editing
// ─────────────────────────────────────────────────────────────────────────

/// Pre-filled metadata form. Builds the PUT body itself (only non-null,
/// parseable fields) and hands it to [onSave]; pops with `true` on success.
class EditMetadataDialog extends StatefulWidget {
  const EditMetadataDialog({
    super.key,
    required this.detail,
    required this.selected,
    required this.onSave,
  });

  final SeriesDetail detail;
  final VideoItem? selected;
  final Future<void> Function(Map<String, dynamic> body) onSave;

  @override
  State<EditMetadataDialog> createState() => _EditMetadataDialogState();
}

class _EditMetadataDialogState extends State<EditMetadataDialog> {
  late final TextEditingController _title;
  late final TextEditingController _originalTitle;
  late final TextEditingController _overview;
  late final TextEditingController _rating;
  late final TextEditingController _year;
  late final TextEditingController _status;
  late final TextEditingController _genre;
  late final TextEditingController _director;
  late final TextEditingController _actors;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.detail;
    final video = widget.selected;
    _title = TextEditingController(text: d.title);
    _originalTitle = TextEditingController(text: d.originalTitle ?? '');
    _overview = TextEditingController(text: d.overview ?? '');
    _rating = TextEditingController(
      text: d.rating != null ? d.rating!.toStringAsFixed(1) : '',
    );
    _year = TextEditingController(text: d.year?.toString() ?? '');
    _status = TextEditingController(text: d.status ?? '');
    _genre = TextEditingController(text: video?.genre ?? '');
    _director = TextEditingController(text: video?.director ?? '');
    _actors = TextEditingController(text: video?.actors ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _originalTitle.dispose();
    _overview.dispose();
    _rating.dispose();
    _year.dispose();
    _status.dispose();
    _genre.dispose();
    _director.dispose();
    _actors.dispose();
    super.dispose();
  }

  /// Backend keeps old values for absent fields — only send what parses.
  Map<String, dynamic> _buildBody() {
    final body = <String, dynamic>{};
    void putText(String key, TextEditingController c) {
      final v = c.text.trim();
      if (v.isNotEmpty) body[key] = v;
    }

    putText('title', _title);
    putText('originalTitle', _originalTitle);
    putText('overview', _overview);
    final rating = double.tryParse(_rating.text.trim());
    if (rating != null) body['rating'] = rating;
    final year = int.tryParse(_year.text.trim());
    if (year != null) body['year'] = year;
    if (widget.detail.isStandalone) {
      putText('genre', _genre);
      putText('director', _director);
      putText('actors', _actors);
    } else {
      putText('status', _status);
    }
    return body;
  }

  Future<void> _save() async {
    if (_saving) return;
    final body = _buildBody();
    if (body.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('没有需要保存的修改')));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(body);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStandalone = widget.detail.isStandalone;
    return AlertDialog(
      title: const Text('编辑元数据'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: '标题'),
              ),
              const SizedBox(height: Dimens.spacingLg),
              TextField(
                controller: _originalTitle,
                decoration: const InputDecoration(labelText: '原始标题'),
              ),
              const SizedBox(height: Dimens.spacingLg),
              TextField(
                controller: _overview,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: '简介'),
              ),
              const SizedBox(height: Dimens.spacingLg),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _rating,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: '评分'),
                    ),
                  ),
                  const SizedBox(width: Dimens.spacingMd),
                  Expanded(
                    child: TextField(
                      controller: _year,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '年份'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Dimens.spacingLg),
              if (isStandalone) ...[
                TextField(
                  controller: _genre,
                  decoration: const InputDecoration(
                    labelText: '类型',
                    hintText: '如：剧情,科幻',
                  ),
                ),
                const SizedBox(height: Dimens.spacingLg),
                TextField(
                  controller: _director,
                  decoration: const InputDecoration(labelText: '导演'),
                ),
                const SizedBox(height: Dimens.spacingLg),
                TextField(
                  controller: _actors,
                  decoration: const InputDecoration(
                    labelText: '主演',
                    hintText: '逗号分隔',
                  ),
                ),
              ] else
                TextField(
                  controller: _status,
                  decoration: const InputDecoration(
                    labelText: '状态',
                    hintText: '如 Ended / Continuing',
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Cover picker (TMDB pull + frame candidates)
// ─────────────────────────────────────────────────────────────────────────

/// Bottom sheet: pull covers from TMDB, or generate frame screenshots and
/// pick one as poster / fanart. Handles its own progress dialogs + snacks.
class CoverPickerSheet extends StatefulWidget {
  const CoverPickerSheet({
    super.key,
    required this.onDownloadCovers,
    required this.onGenerateFrames,
    required this.onSelectFrame,
    required this.onFetchCoverOptions,
    required this.onApplyCover,
    this.onFetchTmdbImages,
    this.onApplyTmdbImage,
    this.onFetchFrameBytes,
    this.onUploadCover,
    this.seasonNumber,
    this.episodeNumber,
    this.isEpisode = true,
  });

  final Future<bool> Function() onDownloadCovers;
  final Future<List<FrameCandidate>> Function() onGenerateFrames;
  final Future<void> Function(int index, {required String type}) onSelectFrame;

  /// 本集在 TMDB 的横屏图（still）候选。
  final Future<List<CoverOption>> Function() onFetchCoverOptions;

  /// 把选中的 TMDB 图应用为本集横屏封面。
  final Future<void> Function(String filePath) onApplyCover;

  /// 分层取图（总览/季/单集）；为空则退化成只做单集剧照。
  final Future<TmdbImageOptions> Function(String level)? onFetchTmdbImages;

  /// 把图落到指定层级（level × kind）。
  final Future<void> Function(String filePath, String level, String kind)?
  onApplyTmdbImage;

  /// 取帧图的原始字节（帧 URL 需签名 + Bearer，裁剪器只吃本地文件）。
  final Future<Uint8List> Function(String url)? onFetchFrameBytes;

  /// 上传裁剪后的图片（level × kind 决定落盘位置，与 TMDB 取图同一套约定）。
  final Future<void> Function(
    File file, {
    required String level,
    required String kind,
  })?
  onUploadCover;

  final int? seasonNumber;
  final int? episodeNumber;

  /// false（电影/单片）时不显示季/单集层级。
  final bool isEpisode;

  @override
  State<CoverPickerSheet> createState() => _CoverPickerSheetState();
}

class _CoverPickerSheetState extends State<CoverPickerSheet> {
  List<FrameCandidate>? _frames;
  bool _working = false;

  /// 当前层级：series（总览）| season（季）| episode（单集）
  String _level = 'episode';

  /// 当前类型：poster（海报）| backdrop（背景图）| still（剧照）
  String _kind = 'still';

  /// 按层级缓存候选，切回来不用重新请求
  final Map<String, TmdbImageOptions> _byLevel = {};

  @override
  void initState() {
    super.initState();
    // 电影没有季/单集维度，只能设总览图
    if (!widget.isEpisode) {
      _level = 'series';
      _kind = 'poster';
    }
  }

  TmdbImageOptions? get _current => _byLevel[_level];

  List<CoverOption> get _visibleOptions => _current?.byKind(_kind) ?? const [];

  /// 每层可选类型。
  /// 单集只有 `still`：实测 TMDB 的单集 `/images` 只返回 stills，没有竖版海报
  /// （所以这里没有「海报」选项），而 still 是 16:9 横版图，落的是 fanart.jpg。
  List<String> get _kindsForLevel => switch (_level) {
    'series' => const ['poster', 'backdrop'],
    'season' => const ['poster'],
    _ => const ['still'],
  };

  String get _levelLabel => switch (_level) {
    'series' => '总览',
    'season' =>
      widget.seasonNumber != null ? '第 ${widget.seasonNumber} 季' : '季',
    _ => widget.episodeNumber != null ? '第 ${widget.episodeNumber} 集' : '单集',
  };

  /// 标签必须说明「落成哪一种图」：剧照/背景图都是横版（fanart），海报才是竖版。
  /// 之前单集层只写「剧照」，容易被当成竖封面——设完发现竖封面没变，其实是
  /// 本集的横版图。
  String _kindLabel(String kind) => switch (kind) {
    'poster' => '海报（竖版）',
    'backdrop' => '背景图（横版）',
    _ => '剧照（横版）',
  };

  /// 当前层级设置的图会落到哪里、影响哪个位置——避免"设了没生效"的误解。
  String get _kindHint => switch ((_level, _kind)) {
    ('episode', _) =>
      '存为本集横版图（fanart.jpg），影响本集详情页顶部大图与横屏卡片。'
          '竖封面整季共用季海报，不在这里设置。',
    ('season', _) => '存为该季的竖版封面（tvshow-poster.jpg），整季共用。',
    ('series', 'backdrop') => '存为剧集级横版图（tvshow-fanart.jpg），作为各集的兜底横图。',
    (_, _) => '存为剧集级竖版海报（tvshow-poster.jpg）。',
  };

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// 拉取当前层级的 TMDB 图片候选（一次拿到该层所有类型）。
  Future<void> _loadLayer() async {
    final fetch = widget.onFetchTmdbImages;
    if (_working) return;
    if (fetch == null) return;
    setState(() => _working = true);
    try {
      final result = await runWithProgress(
        context,
        '正在读取 TMDB「$_levelLabel」图片…',
        () => fetch(_level),
      );
      if (!mounted) return;
      setState(() {
        _byLevel[_level] = result;
        final kinds = _kindsForLevel;
        if (!kinds.contains(_kind)) _kind = kinds.first;
      });
      if (_visibleOptions.isEmpty) {
        _snack('TMDB 这一层没有「${_kindLabel(_kind)}」候选');
      }
    } catch (e) {
      _snack('读取 TMDB 图片失败：$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// 把选中的图落到当前层级。
  Future<void> _applyLayer(CoverOption option) async {
    final path = option.filePath;
    final apply = widget.onApplyTmdbImage;
    if (_working || path == null || apply == null) return;
    setState(() => _working = true);
    try {
      await runWithProgress(
        context,
        '正在应用为「$_levelLabel · ${_kindLabel(_kind)}」…',
        () => apply(path, _level, _kind),
      );
      _snack('已设为$_levelLabel${_kindLabel(_kind)}');
    } catch (e) {
      _snack('设置失败：$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _download() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final ok = await runWithProgress(
        context,
        '正在从 TMDB 拉取封面…',
        widget.onDownloadCovers,
      );
      _snack(ok ? '封面已从 TMDB 更新' : 'TMDB 未返回可用封面');
    } catch (e) {
      _snack('拉取封面失败：$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _generate() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final frames = await runWithProgress(
        context,
        '正在生成截帧候选…',
        widget.onGenerateFrames,
      );
      if (!mounted) return;
      setState(() => _frames = frames);
      if (frames.isEmpty) _snack('未生成可用截帧');
    } catch (e) {
      _snack('生成截帧失败：$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// 上传本地图片作为该层级的封面/背景。
  ///
  /// 为什么要有这条路：帧截图是视频原始比例（多为 16:9），当竖版封面用时
  /// 要么被裁切要么留黑边；让用户自己挑图并裁成正确比例，才是真正的解法。
  Future<void> _uploadLocal() async {
    if (_working) return;
    final upload = widget.onUploadCover;
    if (upload == null) return;

    final kind = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('上传本地图片'),
        content: Text(
          '为「$_levelLabel」上传一张图。\n\n'
          '下一步可以裁剪成 2:3 竖版、16:9 横版，或保持原比例。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'backdrop'),
            child: const Text('横版背景'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'poster'),
            child: const Text('竖版封面'),
          ),
        ],
      ),
    );
    if (kind == null || !mounted) return;

    setState(() => _working = true);
    try {
      // 选图由 file_selector 完成；Android 上会走系统的图片选择器
      const typeGroup = XTypeGroup(
        label: '图片',
        extensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif'],
      );
      final picked = await openFile(acceptedTypeGroups: const [typeGroup]);
      if (picked == null) return; // 用户取消
      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      final ok = await cropAndUploadCover(
        context,
        sourceBytes: bytes,
        kind: kind == 'poster' ? CoverCropKind.poster : CoverCropKind.fanart,
        onUpload: (file) => upload(
          file,
          level: _level,
          kind: kind == 'poster' ? 'poster' : 'still',
        ),
      );
      if (!mounted) return;
      if (ok) {
        _snack(kind == 'poster' ? '已上传竖版封面' : '已上传横版背景');
        Navigator.pop(context); // close the sheet
      }
    } catch (e) {
      _snack('上传失败：$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _pick(FrameCandidate frame) async {
    if (_working) return;
    final type = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('设置第 ${frame.index + 1} 帧'),
        content: const Text('选择要将这一帧应用为：'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'fanart'),
            child: const Text('设为背景'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'poster'),
            child: const Text('设为封面'),
          ),
        ],
      ),
    );
    if (type == null) return;
    if (!mounted) return;

    // 帧截图是视频原始比例（通常 16:9），直接当竖版封面会被裁切/留黑边。
    // 先让用户裁一刀，再上传裁剪结果——用户自己定构图，比我们猜怎么裁更好。
    final fetchBytes = widget.onFetchFrameBytes;
    final upload = widget.onUploadCover;
    if (fetchBytes != null && upload != null && (frame.url ?? '').isNotEmpty) {
      setState(() => _working = true);
      try {
        final bytes = await runWithProgress(
          context,
          '正在读取帧…',
          () => fetchBytes(frame.url!),
        );
        if (!mounted) return;
        final ok = await cropAndUploadCover(
          context,
          sourceBytes: bytes,
          kind: type == 'poster' ? CoverCropKind.poster : CoverCropKind.fanart,
          onUpload: (file) => upload(
            file,
            level: _level,
            kind: type == 'poster' ? 'poster' : 'still',
          ),
        );
        if (!mounted) return;
        if (ok) {
          _snack(type == 'poster' ? '已设为封面' : '已设为背景图');
          Navigator.pop(context); // close the sheet
        }
      } catch (e) {
        _snack('设置封面失败：$e');
      } finally {
        if (mounted) setState(() => _working = false);
      }
      return;
    }

    // 没提供字节/上传通道时退回旧行为（直接应用该帧）
    setState(() => _working = true);
    try {
      await runWithProgress(
        context,
        '正在应用…',
        () => widget.onSelectFrame(frame.index, type: type),
      );
      _snack(type == 'poster' ? '已设为封面' : '已设为背景图');
      if (mounted) Navigator.pop(context); // close the sheet
    } catch (e) {
      _snack('设置封面失败：$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final frames = _frames;
    // 面板内容长度随层级/类型变化：层级选择 + 类型 chips + 候选网格，在矮窗口下
    // 会超出弹窗高度（曾报 "A RenderFlex overflowed by 60 pixels"）。
    // 用 LayoutBuilder 拿父级给的真实可用高度（已扣除系统栏/键盘），比 MediaQuery
    // 更准；系数放宽到 0.95，让平板横屏这类大屏尽量用满高度。
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight * 0.95
            : MediaQuery.sizeOf(context).height * 0.95;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(Dimens.radiusXl),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              Dimens.spacingLg,
              Dimens.spacingMd,
              Dimens.spacingLg,
              Dimens.spacingXl,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).hintColor
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: Dimens.spacingMd),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '设置封面',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: Dimens.spacingSm),
                  // ── TMDB 分层取图：总览 / 季 / 单集 ─────────────────────────
                  // 三个操作并成一行，把纵向空间让给下面的候选网格。
                  // 「一键拉取」去掉括号说明（窄屏会挤爆），说明改放 tooltip。
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _working ? null : _loadLayer,
                          icon: const Icon(
                            Icons.image_search_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _current == null
                                ? '读取 TMDB 图片'
                                : '重新读取（${_visibleOptions.length}）',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: Dimens.spacingSm),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _working ? null : _generate,
                          icon: const Icon(
                            Icons.photo_camera_rounded,
                            size: 18,
                          ),
                          label: const Text(
                            '生成视频截帧',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: Dimens.spacingSm),
                      Expanded(
                        child: Tooltip(
                          message: '从 TMDB 拉取默认图（自动取第一张）；想自己挑用左边两个',
                          child: OutlinedButton.icon(
                            onPressed: _working ? null : _download,
                            icon: const Icon(
                              Icons.cloud_download_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              '一键拉取',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // 上传本地图片单独一行：4 个按钮挤一行在手机竖屏会溢出，
                  // 而且这条路跟上面三个（都依赖服务器/视频）性质不同
                  if (widget.onUploadCover != null) ...[
                    const SizedBox(height: Dimens.spacingSm),
                    OutlinedButton.icon(
                      onPressed: _working ? null : _uploadLocal,
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: const Text('上传本地图片（可裁剪 2:3 / 16:9）'),
                    ),
                  ],
                  const SizedBox(height: Dimens.spacingSm),
                  if (widget.isEpisode)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SegmentedButton<String>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        segments: [
                          const ButtonSegment(
                            value: 'series',
                            label: Text('总览'),
                          ),
                          ButtonSegment(
                            value: 'season',
                            label: Text(
                              widget.seasonNumber != null
                                  ? '第 ${widget.seasonNumber} 季'
                                  : '季',
                            ),
                          ),
                          ButtonSegment(
                            value: 'episode',
                            label: Text(
                              widget.episodeNumber != null
                                  ? '第 ${widget.episodeNumber} 集'
                                  : '单集',
                            ),
                          ),
                        ],
                        selected: {_level},
                        onSelectionChanged: (s) => setState(() {
                          _level = s.first;
                          final kinds = _kindsForLevel;
                          if (!kinds.contains(_kind)) _kind = kinds.first;
                        }),
                      ),
                    ),
                  const SizedBox(height: Dimens.spacingSm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: Dimens.spacingSm,
                      children: [
                        for (final k in _kindsForLevel)
                          ChoiceChip(
                            label: Text(_kindLabel(k)),
                            selected: _kind == k,
                            onSelected: _working
                                ? null
                                : (_) => setState(() => _kind = k),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Dimens.spacingXs),
                  // 说清「设完落到哪个文件、影响哪个位置」：单集层只有横版剧照，
                  // 竖封面整季共用季海报，不讲清楚会被误当成竖封面。
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _kindHint,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: Dimens.spacingMd),
                  if (_current != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$_levelLabel · ${_kindLabel(_kind)}（${_visibleOptions.length}）· 点选应用',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: Dimens.spacingSm),
                    if (_visibleOptions.isNotEmpty)
                      _ImageOptionGrid(
                        options: _visibleOptions,
                        // 竖版海报按 2:3 显示，横图/剧照按 16:9
                        aspectRatio: _kind == 'poster' ? 2 / 3 : 16 / 9,
                        enabled: !_working,
                        onTap: _applyLayer,
                      ),
                    const SizedBox(height: Dimens.spacingMd),
                  ],
                  if (frames == null)
                    // 分层图区块在上方已渲染，这里只负责「尚未生成截帧」的提示
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: Dimens.spacingLg,
                      ),
                      child: Center(
                        child: Text(
                          '可从 TMDB 选本集图片，或生成视频截帧后点选应用',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      ),
                    )
                  else if (frames.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: Dimens.spacingLg,
                      ),
                      child: Center(
                        child: Text(
                          '暂无截帧候选',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: GridView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: Dimens.spacingSm,
                              crossAxisSpacing: Dimens.spacingSm,
                              childAspectRatio: 16 / 9,
                            ),
                        itemCount: frames.length,
                        itemBuilder: (context, i) {
                          final f = frames[i];
                          return InkWell(
                            borderRadius: BorderRadius.circular(
                              Dimens.radiusSm,
                            ),
                            onTap: _working ? null : () => _pick(f),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                Dimens.radiusSm,
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ServerImage(
                                    url: f.url,
                                    fit: BoxFit.cover,
                                    borderRadius: BorderRadius.zero,
                                  ),
                                  Positioned(
                                    left: Dimens.spacingSm,
                                    bottom: Dimens.spacingSm,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: Dimens.spacingSm,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.6,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          Dimens.radiusSm,
                                        ),
                                      ),
                                      child: Text(
                                        '#${f.index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// TMDB 图片候选网格：点选即应用。竖版海报用 2:3，横图/剧照用 16:9。
class _ImageOptionGrid extends StatelessWidget {
  const _ImageOptionGrid({
    required this.options,
    required this.aspectRatio,
    required this.enabled,
    required this.onTap,
  });

  final List<CoverOption> options;
  final double aspectRatio;
  final bool enabled;
  final Future<void> Function(CoverOption option) onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: Dimens.spacingSm,
          crossAxisSpacing: Dimens.spacingSm,
          childAspectRatio: aspectRatio,
        ),
        itemCount: options.length,
        itemBuilder: (context, i) {
          final option = options[i];
          return InkWell(
            borderRadius: BorderRadius.circular(Dimens.radiusSm),
            onTap: enabled ? () => onTap(option) : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Dimens.radiusSm),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ServerImage(
                    url: option.url,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.zero,
                  ),
                  if (option.sizeLabel.isNotEmpty)
                    Positioned(
                      right: Dimens.spacingSm,
                      bottom: Dimens.spacingSm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimens.spacingSm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(Dimens.radiusSm),
                        ),
                        child: Text(
                          option.sizeLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
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

// ─────────────────────────────────────────────────────────────────────────
// Manual logo picking
// ─────────────────────────────────────────────────────────────────────────
/// Candidate list (thumbnail + language + size + votes); pops with `true`
/// after [onSet] succeeds.
class LogoPickerDialog extends StatefulWidget {
  const LogoPickerDialog({
    super.key,
    required this.options,
    required this.onSet,
  });

  final List<LogoOption> options;
  final Future<void> Function(String filePath) onSet;

  @override
  State<LogoPickerDialog> createState() => _LogoPickerDialogState();
}

class _LogoPickerDialogState extends State<LogoPickerDialog> {
  int? _settingIndex;

  Future<void> _choose(LogoOption option) async {
    final filePath = option.filePath;
    if (filePath == null || filePath.isEmpty || _settingIndex != null) {
      return;
    }
    setState(() => _settingIndex = widget.options.indexOf(option));
    try {
      await widget.onSet(filePath);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _settingIndex = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('设置 Logo 失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: AppColors.surface(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(Dimens.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '手动设置 Logo · ${widget.options.length}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
              const SizedBox(height: Dimens.spacingSm),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.options.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final o = widget.options[i];
                    final setting = _settingIndex == i;
                    return ListTile(
                      dense: true,
                      leading: SizedBox(
                        width: 72,
                        height: 40,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(Dimens.radiusSm),
                          child: ServerImage(
                            url: o.url,
                            fit: BoxFit.contain,
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                      ),
                      title: Text(
                        (o.iso6391 != null && o.iso6391!.isNotEmpty)
                            ? o.iso6391!
                            : '通用（无语言标记）',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        [
                          if (o.sizeLabel.isNotEmpty) o.sizeLabel,
                          if (o.voteCount != null)
                            '票数 ${o.voteCount!.toStringAsFixed(0)}',
                        ].join(' · '),
                        style: TextStyle(fontSize: 12, color: theme.hintColor),
                      ),
                      trailing: setting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 20,
                            ),
                      onTap: setting ? null : () => _choose(o),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
