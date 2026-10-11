import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/media_models.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../widgets/server_image.dart';

/// 管理员给某用户分配可访问的媒体库（对应 iOS LibraryAccessView）。
///
/// 布局：用户头部卡 → 全选/清空工具行 → 按类型分组的库列表 → 底部保存栏。
/// 库按类型分组呈现，停用库置灰加「已停用」标签（仍可勾选，便于提前授权）。
class UserLibraryAccessScreen extends StatefulWidget {
  const UserLibraryAccessScreen({
    super.key,
    required this.session,
    required this.user,
  });

  final Session session;
  final UserProfile user;

  @override
  State<UserLibraryAccessScreen> createState() =>
      _UserLibraryAccessScreenState();
}

class _UserLibraryAccessScreenState extends State<UserLibraryAccessScreen> {
  /// 类型分组顺序与文案/图标；未知类型落到「其他」。
  static const _groupOrder = ['VIDEO', 'MUSIC', 'AUDIOBOOK', 'EBOOK', 'COMIC'];
  static const _groupMeta = <String, (String, IconData)>{
    'VIDEO': ('视频', Icons.movie_rounded),
    'MUSIC': ('音乐', Icons.music_note_rounded),
    'AUDIOBOOK': ('有声书', Icons.headphones_rounded),
    'EBOOK': ('电子书', Icons.menu_book_rounded),
    'COMIC': ('漫画', Icons.image_rounded),
  };

  List<MediaLibrary> _libraries = const [];
  Set<int> _selected = {};
  Set<int> _assigned = {};
  bool _loading = false;
  bool _saving = false;
  String? _error;

  bool get _dirty => !setEquals(_selected, _assigned);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = widget.session.api!;
      final libraries = await api.fetchMediaLibraries();
      final ids = await api.fetchUserLibraries(widget.user.id);
      if (!mounted) return;
      setState(() {
        _libraries = libraries;
        _selected = ids.toSet();
        _assigned = ids.toSet();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.session.api!.assignUserLibraries(
        widget.user.id,
        _selected.toList()..sort(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggle(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() => _selected = {for (final lib in _libraries) lib.id});
  }

  void _clearAll() {
    setState(() => _selected = {});
  }

  /// 库按类型分桶，顺序遵循 [_groupOrder]，未知类型排到最后显示为「其他」。
  List<(String, String, IconData, List<MediaLibrary>)> get _groups {
    final buckets = <String, List<MediaLibrary>>{};
    for (final lib in _libraries) {
      buckets.putIfAbsent(lib.type.toUpperCase(), () => []).add(lib);
    }
    final keys = [
      ..._groupOrder.where(buckets.containsKey),
      ...buckets.keys.where((k) => !_groupOrder.contains(k)),
    ];
    return [
      for (final k in keys)
        (
          k,
          _groupMeta[k]?.$1 ?? '其他',
          _groupMeta[k]?.$2 ?? Icons.folder_rounded,
          buckets[k]!,
        ),
    ];
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
          '媒体库授权',
          style: TextStyle(
            fontSize: 17 * form.typeScale,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      // 保存栏常驻底部（摘要 + 保存按钮），列表在上方滚动。
      body: Column(
        children: [
          Expanded(child: _buildBody(form)),
          _buildSaveBar(form),
        ],
      ),
    );
  }

  Widget _buildBody(DeviceForm form) {
    if (_loading && _libraries.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color: AppColors.accentOf(context),
          strokeWidth: 2.5,
        ),
      );
    }
    if (_error != null && _libraries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(Dimens.spacingXl),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14 * form.typeScale,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ),
            FilledButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_libraries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_off_rounded,
              size: 48,
              color: Theme.of(context).hintColor,
            ),
            const SizedBox(height: Dimens.spacingLg),
            Text(
              '服务器上暂无媒体库',
              style: TextStyle(
                fontSize: 15 * form.typeScale,
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accentOf(context),
      child: ListView(
        padding: const EdgeInsets.all(Dimens.spacingLg),
        children: [
          _UserHeader(
            user: widget.user,
            isSelf: widget.user.id == widget.session.user?.id,
            selected: _selected,
            form: form,
          ),
          const SizedBox(height: Dimens.spacingLg),
          _buildToolbarRow(form),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: Dimens.spacingSm),
              child: Text(
                _error!,
                style: TextStyle(
                  fontSize: 13 * form.typeScale,
                  color: AppColors.danger,
                ),
              ),
            ),
          const SizedBox(height: Dimens.spacingMd),
          for (final (type, label, icon, libs) in _groups) ...[
            _GroupHeader(
              label: label,
              icon: icon,
              selectedCount: libs
                  .where((l) => _selected.contains(l.id))
                  .length,
              totalCount: libs.length,
              form: form,
            ),
            const SizedBox(height: Dimens.spacingSm),
            _buildGroupCard(type, label, icon, libs, form),
            const SizedBox(height: Dimens.spacingLg),
          ],
          const SizedBox(height: Dimens.spacingXl),
        ],
      ),
    );
  }

  /// 工具行：左侧说明文案，右侧「全选 / 清空」快捷操作。
  Widget _buildToolbarRow(DeviceForm form) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '勾选该用户可以访问的媒体库',
            style: TextStyle(
              fontSize: 13 * form.typeScale,
              color: Theme.of(context).hintColor,
            ),
          ),
        ),
        TextButton(
          onPressed: _libraries.isEmpty ? null : _selectAll,
          child: Text('全选', style: TextStyle(fontSize: 13 * form.typeScale)),
        ),
        TextButton(
          onPressed: _selected.isEmpty ? null : _clearAll,
          child: Text('清空', style: TextStyle(fontSize: 13 * form.typeScale)),
        ),
      ],
    );
  }

  /// 一个类型分组卡：组内库逐行排列，行间用缩进分隔线。
  Widget _buildGroupCard(
    String type,
    String label,
    IconData icon,
    List<MediaLibrary> libs,
    DeviceForm form,
  ) {
    return Material(
      color: AppColors.surface(context),
      borderRadius: BorderRadius.circular(Dimens.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, lib) in libs.indexed) ...[
            if (i > 0)
              Divider(height: 1, indent: 64, color: Theme.of(context).dividerColor),
            _LibraryRow(
              lib: lib,
              typeIcon: icon,
              selected: _selected.contains(lib.id),
              onChanged: (_) => _toggle(lib.id),
              form: form,
            ),
          ],
        ],
      ),
    );
  }

  /// 底部保存栏：左侧实时摘要（空选时给危险色警告），右侧保存按钮。
  Widget _buildSaveBar(DeviceForm form) {
    final emptyWarning = _selected.isEmpty;
    return Material(
      color: AppColors.surface(context),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            Dimens.spacingLg,
            Dimens.spacingMd,
            Dimens.spacingLg,
            Dimens.spacingMd,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  emptyWarning
                      ? '未选择任何媒体库，保存后该用户将看不到任何内容'
                      : '已授权 ${_selected.length} / ${_libraries.length} 个媒体库',
                  style: TextStyle(
                    fontSize: 12 * form.typeScale,
                    color: emptyWarning
                        ? AppColors.danger
                        : Theme.of(context).hintColor,
                  ),
                ),
              ),
              const SizedBox(width: Dimens.spacingMd),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentOf(context),
                ),
                onPressed: _dirty && !_saving ? _save : null,
                child: _saving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text('保存', style: TextStyle(fontSize: 14 * form.typeScale)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 用户头部卡：头像 + 昵称/用户名 + 角色标签 + 右侧授权进度。
class _UserHeader extends StatelessWidget {
  const _UserHeader({
    required this.user,
    required this.isSelf,
    required this.selected,
    required this.form,
  });

  final UserProfile user;
  final bool isSelf;
  final Set<int> selected;
  final DeviceForm form;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface(context),
      borderRadius: BorderRadius.circular(Dimens.radiusLg),
      child: Padding(
        padding: const EdgeInsets.all(Dimens.spacingLg),
        child: Row(
          children: [
            _avatar(context),
            const SizedBox(width: Dimens.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16 * form.typeScale,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: Dimens.spacingSm),
                      _Tag(
                        text: user.roleText,
                        color: user.isAdmin
                            ? const Color(0xFFAF52DE)
                            : Theme.of(context).hintColor,
                      ),
                      if (isSelf)
                        _Tag(text: '我', color: AppColors.accentOf(context)),
                    ],
                  ),
                  const SizedBox(height: Dimens.spacingXs),
                  Text(
                    '@${user.username}',
                    style: TextStyle(
                      fontSize: 12 * form.typeScale,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Dimens.spacingMd),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${selected.length}',
                  style: TextStyle(
                    fontSize: 22 * form.typeScale,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentOf(context),
                  ),
                ),
                Text(
                  '已授权',
                  style: TextStyle(
                    fontSize: 11 * form.typeScale,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(BuildContext context) {
    if (user.avatar != null && user.avatar!.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: 44,
          height: 44,
          child: ServerImage(url: user.avatar, borderRadius: BorderRadius.zero),
        ),
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.accentOf(context).withValues(alpha: 0.15),
      child: Text(
        user.title.isNotEmpty ? user.title.characters.first : '?',
        style: TextStyle(
          color: AppColors.accentOf(context),
          fontSize: 16 * form.typeScale,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 分组标题：类型图标 + 名称 + 「已授权 x / 总数 y」。
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.label,
    required this.icon,
    required this.selectedCount,
    required this.totalCount,
    required this.form,
  });

  final String label;
  final IconData icon;
  final int selectedCount;
  final int totalCount;
  final DeviceForm form;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.spacingXs),
      child: Row(
        children: [
          Icon(icon, size: 18 * form.typeScale, color: AppColors.accentOf(context)),
          const SizedBox(width: Dimens.spacingSm),
          Text(
            label,
            style: TextStyle(
              fontSize: 14 * form.typeScale,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: Dimens.spacingSm),
          Text(
            '$selectedCount / $totalCount',
            style: TextStyle(
              fontSize: 12 * form.typeScale,
              color: Theme.of(context).hintColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// 分组卡里的一行库：类型图标圆底 + 名称/标签 + 路径 + 勾选框。
class _LibraryRow extends StatelessWidget {
  const _LibraryRow({
    required this.lib,
    required this.typeIcon,
    required this.selected,
    required this.onChanged,
    required this.form,
  });

  final MediaLibrary lib;
  final IconData typeIcon;
  final bool selected;
  final ValueChanged<bool?> onChanged;
  final DeviceForm form;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!selected),
      child: Opacity(
        // 停用的库置灰：授权了也不会出现在前端，但仍允许勾选（提前授权）。
        opacity: lib.enabled ? 1.0 : 0.45,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimens.spacingMd,
            vertical: Dimens.spacingSm + 2,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.accentOf(context).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  typeIcon,
                  size: 19 * form.typeScale,
                  color: AppColors.accentOf(context),
                ),
              ),
              const SizedBox(width: Dimens.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            lib.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15 * form.typeScale,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: Dimens.spacingSm),
                        _Tag(
                          text: lib.typeLabel,
                          color: AppColors.accentOf(context),
                        ),
                        if (lib.isAdult)
                          const _Tag(text: '18+', color: AppColors.danger),
                        if (!lib.enabled)
                          _Tag(
                            text: '已停用',
                            color: Theme.of(context).hintColor,
                          ),
                      ],
                    ),
                    if (lib.path.isNotEmpty) ...[
                      const SizedBox(height: Dimens.spacingXs),
                      Text(
                        lib.path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11 * form.typeScale,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Dimens.spacingSm),
              Checkbox(
                value: selected,
                onChanged: onChanged,
                activeColor: AppColors.accentOf(context),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 小圆角标签（角色 / 类型 / 18+ / 已停用）。
class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
