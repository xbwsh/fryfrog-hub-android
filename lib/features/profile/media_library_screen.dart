import 'package:flutter/material.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/media_models.dart';
import '../../core/network/gateways.dart';
import '../../core/network/gateways_impl.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import 'media_library_controller.dart';

/// Admin screen for media libraries: list / add / edit / delete / toggle,
/// server directory browsing and scan with live progress.
class MediaLibraryScreen extends StatefulWidget {
  const MediaLibraryScreen({super.key, required this.session});

  final Session session;

  @override
  State<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends State<MediaLibraryScreen> {
  late final MediaLibraryController _c;
  bool _wasScanning = false;

  @override
  void initState() {
    super.initState();
    final api = widget.session.api;
    _c = MediaLibraryController(
      gateway: api == null
          ? _NullMediaLibraryGateway()
          : ApiMediaLibraryGateway(api),
    );
    _c.addListener(_onChanged);
    _c.load();
  }

  void _onChanged() {
    if (!mounted) return;
    // A finished scan added/updated items — refresh the home catalog.
    if (_wasScanning && !_c.scanning) {
      widget.session.loadCatalog();
    }
    _wasScanning = _c.scanning;
    setState(() {});
  }

  @override
  void dispose() {
    _c
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _scanAll() async {
    try {
      final msg = await _c.startScanAll();
      if (msg != null) _snack(msg);
    } catch (e) {
      _snack('扫描失败：$e');
    }
  }

  Future<void> _scanOne(MediaLibrary lib) async {
    try {
      final msg = await _c.startScanOne(lib.id);
      if (msg != null) _snack(msg);
    } catch (e) {
      _snack('扫描失败：$e');
    }
  }

  Future<void> _toggle(MediaLibrary lib) async {
    try {
      await _c.toggle(lib);
    } catch (e) {
      _snack('操作失败：$e');
    }
  }

  Future<void> _delete(MediaLibrary lib) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
          '确定要删除资源库「${lib.name}」吗？\n\n'
          '删除后，已扫描入库的视频的资源库关联将被解除，'
          '但视频文件不会被删除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _c.remove(lib.id);
    } catch (e) {
      _snack('删除失败：$e');
    }
  }

  Future<void> _showForm({MediaLibrary? edit}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _LibraryFormDialog(gateway: _c.gateway, edit: edit, busy: _c.busy),
    );
    if (saved == true) {
      // The dialog performed the mutation through the shared gateway;
      // reload to pick up server-side normalization (path, sort order).
      await _c.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '媒体库管理',
          style: TextStyle(
            fontSize: 17 * form.typeScale,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '扫描全部',
            icon: const Icon(Icons.sync_rounded),
            onPressed: _c.scanning ? null : _scanAll,
          ),
          IconButton(
            tooltip: '添加资源库',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showForm(),
          ),
          const SizedBox(width: Dimens.spacingSm),
        ],
      ),
      body: ListenableBuilder(
        listenable: _c,
        builder: (context, _) {
          if (_c.loading && _c.libraries.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 2.5,
              ),
            );
          }
          if (_c.error != null && _c.libraries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(Dimens.spacingXl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _c.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14 * form.typeScale,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                    const SizedBox(height: Dimens.spacingLg),
                    FilledButton(onPressed: _c.load, child: const Text('重试')),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(Dimens.spacingLg),
            children: [
              if (_c.scanning) ...[
                _ScanProgressCard(controller: _c, form: form),
                const SizedBox(height: Dimens.spacingLg),
              ],
              if (_c.libraries.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: Dimens.spacingXxl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          size: 48,
                          color: Theme.of(context).hintColor,
                        ),
                        const SizedBox(height: Dimens.spacingLg),
                        Text(
                          '暂无资源库',
                          style: TextStyle(
                            fontSize: 15 * form.typeScale,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                        const SizedBox(height: Dimens.spacingLg),
                        FilledButton.icon(
                          onPressed: () => _showForm(),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('添加第一个资源库'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final lib in _c.libraries) ...[
                  _LibraryCard(
                    lib: lib,
                    form: form,
                    busy: _c.busy,
                    scanning: _c.scanning,
                    onToggle: () => _toggle(lib),
                    onScan: () => _scanOne(lib),
                    onEdit: () => _showForm(edit: lib),
                    onDelete: () => _delete(lib),
                  ),
                  const SizedBox(height: Dimens.spacingMd),
                ],
              const SizedBox(height: Dimens.dockHeight),
            ],
          );
        },
      ),
    );
  }
}

class _ScanProgressCard extends StatelessWidget {
  const _ScanProgressCard({required this.controller, required this.form});

  final MediaLibraryController controller;
  final DeviceForm form;

  @override
  Widget build(BuildContext context) {
    final percent = controller.scanPercent.clamp(0.0, 100.0);
    return Container(
      padding: const EdgeInsets.all(Dimens.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(Dimens.radiusLg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  controller.scanStage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14 * form.typeScale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${percent.round()}%',
                style: TextStyle(
                  fontSize: 13 * form.typeScale,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          if (controller.scanCurrentItem != null) ...[
            const SizedBox(height: Dimens.spacingXs),
            Text(
              '当前：${controller.scanCurrentItem}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12 * form.typeScale,
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
          const SizedBox(height: Dimens.spacingSm),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 6,
              backgroundColor: AppColors.background(context),
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.lib,
    required this.form,
    required this.busy,
    required this.scanning,
    required this.onToggle,
    required this.onScan,
    required this.onEdit,
    required this.onDelete,
  });

  final MediaLibrary lib;
  final DeviceForm form;
  final bool busy;
  final bool scanning;
  final VoidCallback onToggle;
  final VoidCallback onScan;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(Dimens.radiusLg),
      ),
      child: ListTile(
        enabled: !busy,
        leading: Switch(
          value: lib.enabled,
          activeThumbColor: AppColors.success,
          onChanged: busy ? null : (_) => onToggle(),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                lib.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15 * form.typeScale,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: Dimens.spacingSm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                lib.typeLabel,
                style: TextStyle(
                  fontSize: 11 * form.typeScale,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          [
            lib.path,
            if (lib.description != null && lib.description!.isNotEmpty)
              lib.description!,
          ].join('\n'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12 * form.typeScale, height: 1.3),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: '更多操作',
          onSelected: (action) {
            switch (action) {
              case 'scan':
                onScan();
              case 'edit':
                onEdit();
              case 'delete':
                onDelete();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'scan',
              enabled: !scanning,
              child: Row(
                children: [
                  const Icon(Icons.sync_rounded, size: 18),
                  const SizedBox(width: Dimens.spacingMd),
                  Text('扫描', style: TextStyle(fontSize: 14 * form.typeScale)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  const Icon(Icons.edit_rounded, size: 18),
                  const SizedBox(width: Dimens.spacingMd),
                  Text('编辑', style: TextStyle(fontSize: 14 * form.typeScale)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(
                    Icons.delete_rounded,
                    size: 18,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: Dimens.spacingMd),
                  Text(
                    '删除',
                    style: TextStyle(
                      fontSize: 14 * form.typeScale,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add / edit form. Performs the mutation itself so field controllers stay
/// local; pops with `true` when saved.
class _LibraryFormDialog extends StatefulWidget {
  const _LibraryFormDialog({
    required this.gateway,
    required this.edit,
    required this.busy,
  });

  final MediaLibraryGateway gateway;
  final MediaLibrary? edit;
  final bool busy;

  @override
  State<_LibraryFormDialog> createState() => _LibraryFormDialogState();
}

class _LibraryFormDialogState extends State<_LibraryFormDialog> {
  static const Map<String, String> _subTypes = {
    'MOVIE': '电影',
    'TV': '电视剧',
    'MIXED': '混合',
  };

  late final TextEditingController _name;
  late final TextEditingController _path;
  late final TextEditingController _desc;
  late String _subType;
  late bool _enabled;
  late bool _enableScraping;
  late bool _isAdult;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final edit = widget.edit;
    _name = TextEditingController(text: edit?.name ?? '');
    _path = TextEditingController(text: edit?.path ?? '');
    _desc = TextEditingController(text: edit?.description ?? '');
    _subType = edit?.subType ?? 'MOVIE';
    _enabled = edit?.enabled ?? true;
    _enableScraping = edit?.enableScraping ?? true;
    _isAdult = edit?.isAdult ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _path.dispose();
    _desc.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty && _path.text.trim().isNotEmpty;

  Future<void> _browse() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => _DirBrowserDialog(
        gateway: widget.gateway,
        initialPath: _path.text.trim(),
      ),
    );
    if (selected != null && selected.isNotEmpty) {
      _path.text = selected;
      setState(() {});
    }
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    try {
      if (widget.edit == null) {
        await widget.gateway.createLibrary(
          name: _name.text.trim(),
          path: _path.text.trim(),
          subType: _subType,
          enabled: _enabled,
          enableScraping: _enableScraping,
          isAdult: _isAdult,
          description: _desc.text.trim(),
        );
      } else {
        await widget.gateway.updateLibrary(
          widget.edit!.id,
          name: _name.text.trim(),
          path: _path.text.trim(),
          subType: _subType,
          enabled: _enabled,
          enableScraping: _enableScraping,
          isAdult: _isAdult,
          description: _desc.text.trim(),
        );
      }
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
    final form = AdaptiveScope.of(context);
    final edit = widget.edit;

    return AlertDialog(
      title: Text(edit == null ? '添加资源库' : '编辑资源库'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: '名称 *',
                  hintText: '例如：电影库、日剧库',
                ),
              ),
              const SizedBox(height: Dimens.spacingLg),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _path,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: '路径 *',
                        hintText: '/media/movies',
                      ),
                    ),
                  ),
                  const SizedBox(width: Dimens.spacingSm),
                  IconButton(
                    tooltip: '浏览服务器目录',
                    icon: const Icon(Icons.folder_open_rounded),
                    onPressed: _browse,
                  ),
                ],
              ),
              Text(
                '填写服务器上的绝对路径，或点击浏览选择',
                style: TextStyle(
                  fontSize: 11 * form.typeScale,
                  color: Theme.of(context).hintColor,
                ),
              ),
              const SizedBox(height: Dimens.spacingLg),
              DropdownButtonFormField<String>(
                initialValue: _subType,
                decoration: const InputDecoration(labelText: '视频子类型'),
                items: [
                  for (final entry in _subTypes.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (v) => setState(() => _subType = v ?? 'MOVIE'),
              ),
              const SizedBox(height: Dimens.spacingLg),
              TextField(
                controller: _desc,
                decoration: const InputDecoration(
                  labelText: '备注',
                  hintText: '可选的备注说明',
                ),
              ),
              const SizedBox(height: Dimens.spacingLg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '启用此资源库',
                      style: TextStyle(fontSize: 14 * form.typeScale),
                    ),
                  ),
                  Switch(
                    value: _enabled,
                    activeThumbColor: AppColors.success,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                ],
              ),
              // Video-only switches — other types ignore these flags on scan.
              if (edit == null || edit.type == 'VIDEO') ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '扫描时自动刮削',
                        style: TextStyle(fontSize: 14 * form.typeScale),
                      ),
                    ),
                    Switch(
                      value: _enableScraping,
                      onChanged: (v) => setState(() => _enableScraping = v),
                    ),
                  ],
                ),
                Text(
                  '扫描到新视频时自动匹配并绑定 TMDB',
                  style: TextStyle(
                    fontSize: 11 * form.typeScale,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                const SizedBox(height: Dimens.spacingMd),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '成人内容库',
                        style: TextStyle(fontSize: 14 * form.typeScale),
                      ),
                    ),
                    Switch(
                      value: _isAdult,
                      activeThumbColor: AppColors.danger,
                      onChanged: (v) => setState(() => _isAdult = v),
                    ),
                  ],
                ),
                Text(
                  '入库视频标记为 18+',
                  style: TextStyle(
                    fontSize: 11 * form.typeScale,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
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
          onPressed: _valid && !_saving ? _save : null,
          child: Text(_saving ? '保存中…' : '保存'),
        ),
      ],
    );
  }
}

/// Server directory picker: roots → children → "select this directory".
class _DirBrowserDialog extends StatefulWidget {
  const _DirBrowserDialog({required this.gateway, this.initialPath = ''});

  final MediaLibraryGateway gateway;
  final String initialPath;

  @override
  State<_DirBrowserDialog> createState() => _DirBrowserDialogState();
}

class _DirBrowserDialogState extends State<_DirBrowserDialog> {
  late String _path; // '' = disk roots
  List<LibraryDirItem> _dirs = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _path = widget.initialPath;
    _load(_path.isEmpty ? null : _path);
  }

  Future<void> _load(String? path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dirs = await widget.gateway.browse(path: path);
      if (!mounted) return;
      setState(() {
        _dirs = dirs;
        _path = path ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  String? get _parentPath {
    if (_path.isEmpty) return null;
    final normalized = _path.replaceAll('\\', '/');
    final parts = normalized.split('/')..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return null;
    parts.removeLast();
    if (parts.isEmpty) return null;
    final isWindows = RegExp(r'^[A-Za-z]:').hasMatch(normalized);
    return isWindows ? '${parts.join('\\')}\\' : '/${parts.join('/')}';
  }

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);

    return AlertDialog(
      title: const Text('选择目录'),
      content: SizedBox(
        width: 420,
        height: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimens.spacingMd,
                vertical: Dimens.spacingSm,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(Dimens.radiusSm),
              ),
              child: Text(
                _path.isEmpty ? '/' : _path,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12 * form.typeScale,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: Dimens.spacingSm),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                        strokeWidth: 2.5,
                      ),
                    )
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13 * form.typeScale,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                          const SizedBox(height: Dimens.spacingSm),
                          TextButton(
                            onPressed: () =>
                                _load(_path.isEmpty ? null : _path),
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    )
                  : _dirs.isEmpty
                  ? Center(
                      child: Text(
                        '此目录下没有子目录',
                        style: TextStyle(
                          fontSize: 13 * form.typeScale,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _dirs.length,
                      itemBuilder: (context, i) {
                        final dir = _dirs[i];
                        return ListTile(
                          dense: true,
                          enabled: dir.writable,
                          leading: Icon(
                            dir.writable
                                ? Icons.folder_rounded
                                : Icons.folder_off_rounded,
                            size: 20,
                          ),
                          title: Text(
                            dir.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14 * form.typeScale),
                          ),
                          trailing: dir.writable
                              ? const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                )
                              : null,
                          onTap: dir.writable ? () => _load(dir.path) : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _parentPath == null || _loading
              ? null
              : () => _load(_parentPath),
          child: const Text('返回上级'),
        ),
        FilledButton(
          onPressed: _path.isEmpty || _loading
              ? null
              : () => Navigator.pop(context, _path),
          child: const Text('选择此目录'),
        ),
      ],
    );
  }
}

/// Fail-fast stub when Session has no ApiClient (e.g. unit hosts).
class _NullMediaLibraryGateway implements MediaLibraryGateway {
  @override
  Future<List<MediaLibrary>> fetchLibraries() => throw UnsupportedError('未登录');

  @override
  Future<MediaLibrary> createLibrary({
    required String name,
    required String path,
    String? subType,
    required bool enabled,
    bool enableScraping = true,
    bool isAdult = false,
    String? description,
  }) => throw UnsupportedError('未登录');

  @override
  Future<MediaLibrary> updateLibrary(
    int id, {
    String? name,
    String? path,
    String? subType,
    bool? enabled,
    bool? enableScraping,
    bool? isAdult,
    String? description,
  }) => throw UnsupportedError('未登录');

  @override
  Future<void> deleteLibrary(int id) => throw UnsupportedError('未登录');

  @override
  Future<MediaLibrary> toggleLibrary(int id) => throw UnsupportedError('未登录');

  @override
  Future<int> scanAll() => throw UnsupportedError('未登录');

  @override
  Future<void> scanOne(int id) => throw UnsupportedError('未登录');

  @override
  Future<List<LibraryScanProgress>> fetchScanProgress() =>
      throw UnsupportedError('未登录');

  @override
  Future<LibraryPipelineProgress> fetchPipelineProgress(int id) =>
      throw UnsupportedError('未登录');

  @override
  Future<StaleRecords> fetchStaleRecords(int libraryId) =>
      throw UnsupportedError('未登录');

  @override
  Future<int> purgeStaleRecords(int libraryId, {bool dryRun = false}) =>
      throw UnsupportedError('未登录');

  @override
  Future<List<LibraryDirItem>> browse({String? path}) =>
      throw UnsupportedError('未登录');
}
