import 'package:flutter/material.dart';

import '../../core/models/media_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../widgets/server_image.dart';

/// Admin dialogs/sheets for the video detail page (TMDB binding, metadata
/// editing, covers, logo picking). The screen only dispatches menu actions;
/// orchestration lives in `VideoDetailController`.

/// Shows a non-dismissible progress dialog, runs [work], then pops the
/// dialog (even on error, which rethrows so callers can SnackBar).
Future<T> runWithProgress<T>(
  BuildContext context,
  String label,
  Future<T> Function() work,
) async {
  final nav = Navigator.of(context);
  // Pushed synchronously; not awaited — we pop it ourselves in `finally`.
  // Plain Dialog (not AlertDialog): AlertDialog's min-height constraint
  // top-aligns a lone content row, which reads as "sitting too high".
  // ignore: unawaited_futures
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
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
  );
  try {
    return await work();
  } finally {
    nav.pop();
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
  late final TextEditingController _keywordCtrl =
      TextEditingController(text: widget.initialKeyword);
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
  });

  final Future<bool> Function() onDownloadCovers;
  final Future<List<FrameCandidate>> Function() onGenerateFrames;
  final Future<void> Function(int index, {required String type}) onSelectFrame;

  /// 本集在 TMDB 的横屏图（still）候选。
  final Future<List<CoverOption>> Function() onFetchCoverOptions;

  /// 把选中的 TMDB 图应用为本集横屏封面。
  final Future<void> Function(String filePath) onApplyCover;

  @override
  State<CoverPickerSheet> createState() => _CoverPickerSheetState();
}

class _CoverPickerSheetState extends State<CoverPickerSheet> {
  List<FrameCandidate>? _frames;
  List<CoverOption>? _stills;
  bool _working = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 拉取 TMDB 的本集剧照候选，让用户自己挑，而不是只自动取一张。
  Future<void> _loadStills() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final list = await runWithProgress(
        context,
        '正在读取 TMDB 本集图片…',
        widget.onFetchCoverOptions,
      );
      if (!mounted) return;
      setState(() => _stills = list);
      if (list.isEmpty) _snack('TMDB 没有这一集的图片候选');
    } catch (e) {
      _snack('读取 TMDB 图片失败：$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _applyStill(CoverOption option) async {
    final path = option.filePath;
    if (_working || path == null) return;
    setState(() => _working = true);
    try {
      await runWithProgress(
        context,
        '正在应用为横屏封面…',
        () => widget.onApplyCover(path),
      );
      _snack('已设为本集横屏封面');
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
    final stills = _stills;
    return Container(
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).hintColor.withValues(alpha: 0.4),
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
              // 主路径：让用户从 TMDB 的本集剧照里挑一张
              Expanded(
                child: FilledButton.icon(
                  onPressed: _working ? null : _loadStills,
                  icon: const Icon(Icons.image_search_rounded, size: 18),
                  label: const Text('TMDB 本集图片'),
                ),
              ),
              const SizedBox(width: Dimens.spacingSm),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _working ? null : _generate,
                  icon: const Icon(Icons.photo_camera_rounded, size: 18),
                  label: const Text('生成视频截帧'),
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimens.spacingSm),
          // 一键拉取（自动取默认那张）——想自己挑就用上面那个
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _working ? null : _download,
              icon: const Icon(Icons.cloud_download_rounded, size: 18),
              label: const Text('一键从 TMDB 拉取（默认图）'),
            ),
          ),
          const SizedBox(height: Dimens.spacingMd),
          if (stills != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '本集图片（${stills.length}）· 点选设为横屏封面',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ),
            const SizedBox(height: Dimens.spacingSm),
            if (stills.isNotEmpty)
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
                  itemCount: stills.length,
                  itemBuilder: (context, i) {
                    final s = stills[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(Dimens.radiusSm),
                      onTap: _working ? null : () => _applyStill(s),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Dimens.radiusSm),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ServerImage(
                              url: s.url,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.zero,
                            ),
                            if (s.sizeLabel.isNotEmpty)
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
                                    borderRadius: BorderRadius.circular(
                                      Dimens.radiusSm,
                                    ),
                                  ),
                                  child: Text(
                                    s.sizeLabel,
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
              ),
            const SizedBox(height: Dimens.spacingMd),
          ],
          if (frames == null)
            // stills 区块在上方已渲染，这里只负责「尚未生成截帧」的提示
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Dimens.spacingLg),
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
              padding: const EdgeInsets.symmetric(vertical: Dimens.spacingLg),
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
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: Dimens.spacingSm,
                  crossAxisSpacing: Dimens.spacingSm,
                  childAspectRatio: 16 / 9,
                ),
                itemCount: frames.length,
                itemBuilder: (context, i) {
                  final f = frames[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(Dimens.radiusSm),
                    onTap: _working ? null : () => _pick(f),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Dimens.radiusSm),
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
                                color: Colors.black.withValues(alpha: 0.6),
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
