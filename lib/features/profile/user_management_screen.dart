import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/media_models.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../widgets/server_image.dart';
import 'user_library_access_screen.dart';

/// 用户管理（管理员）：列表 / 创建 / 编辑 / 删除 / 重置密码 / 媒体库授权。
/// 对应 iOS UsersManagementView + UserEditView + LibraryAccessView。
class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key, required this.session});

  final Session session;

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  List<UserProfile> _users = const [];
  bool _loading = false;
  String? _error;
  UserProfile? _toDelete;
  UserProfile? _toReset;
  final _resetController = TextEditingController();

  int? get _meId => widget.session.user?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await widget.session.api!.fetchUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
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

  Future<void> _toggle(UserProfile user) async {
    try {
      await widget.session.api!.updateUser(
        user.id,
        enabled: user.enabled != false,
      );
      await _load();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _delete(UserProfile user) async {
    if (user.id == _meId) {
      _showError('不能删除当前登录的账号');
      return;
    }
    try {
      await widget.session.api!.deleteUser(user.id);
      await _load();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _resetPassword(UserProfile user) async {
    final password = _resetController.text;
    if (password.length < 8) {
      _showError('新密码至少 8 位');
      return;
    }
    try {
      await widget.session.api!.resetUserPassword(
        userId: user.id,
        newPassword: password,
      );
      _resetController.clear();
      if (mounted) setState(() => _toReset = null);
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openLibraries(UserProfile user) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            UserLibraryAccessScreen(session: widget.session, user: user),
      ),
    );
  }

  Future<void> _openEdit({UserProfile? user}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _UserEditDialog(session: widget.session, user: user, meId: _meId),
    );
    if (saved == true) {
      await _load();
      if (user != null && user.id == _meId) {
        // 编辑过自己（昵称/角色/启用），同步顶部用户信息
        try {
          await widget.session.refreshUser();
        } catch (_) {}
      }
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
          '用户管理',
          style: TextStyle(
            fontSize: 17 * form.typeScale,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '创建用户',
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () => _openEdit(),
          ),
          const SizedBox(width: Dimens.spacingSm),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildBody(form)),
          if (_toDelete != null) _deleteDialog(_toDelete!),
          if (_toReset != null) _resetDialog(_toReset!),
        ],
      ),
    );
  }

  Widget _deleteDialog(UserProfile user) {
    return AlertDialog(
      title: Text('删除用户「${user.username}」？'),
      content: const Text('删除后该用户将无法登录'),
      actions: [
        TextButton(
          onPressed: () => setState(() => _toDelete = null),
          child: const Text('取消'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          onPressed: () {
            setState(() => _toDelete = null);
            _delete(user);
          },
          child: const Text('删除'),
        ),
      ],
    );
  }

  Widget _resetDialog(UserProfile user) {
    return AlertDialog(
      title: Text('重置密码 ${user.username}'),
      content: GlassTextField(
        controller: _resetController,
        placeholder: '新密码（至少 8 位）',
        obscureText: true,
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _toReset = null),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => _resetPassword(user),
          child: const Text('重置'),
        ),
      ],
    );
  }

  Widget _buildBody(DeviceForm form) {
    if (_loading && _users.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color: AppColors.accentOf(context),
          strokeWidth: 2.5,
        ),
      );
    }
    if (_error != null && _users.isEmpty) {
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
    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.group_off_rounded,
              size: 48,
              color: Theme.of(context).hintColor,
            ),
            const SizedBox(height: Dimens.spacingLg),
            Text(
              '暂无用户',
              style: TextStyle(
                fontSize: 16 * form.typeScale,
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
      child: ListView.separated(
        padding: const EdgeInsets.all(Dimens.spacingLg),
        itemCount: _users.length,
        separatorBuilder: (_, _) => const SizedBox(height: Dimens.spacingSm),
        itemBuilder: (context, i) {
          final user = _users[i];
          final isSelf = user.id == _meId;
          return Material(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(Dimens.radiusLg),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: _Avatar(user: user),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      user.title,
                      style: TextStyle(
                        fontSize: 15 * form.typeScale,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: Dimens.spacingSm),
                  _UserTag(
                    text: user.roleText,
                    color: user.isAdmin
                        ? const Color(0xFFAF52DE)
                        : Theme.of(context).hintColor,
                  ),
                  if (isSelf)
                    _UserTag(text: '我', color: AppColors.accentOf(context)),
                ],
              ),
              subtitle: Text(
                '@${user.username}',
                style: TextStyle(
                  fontSize: 12 * form.typeScale,
                  color: Theme.of(context).hintColor,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isSelf)
                    Switch(
                      value: user.enabled != false,
                      onChanged: (_) => _toggle(user),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (action) {
                      switch (action) {
                        case 'edit':
                          _openEdit(user: user);
                        case 'reset':
                          _resetController.clear();
                          setState(() => _toReset = user);
                        case 'libraries':
                          _openLibraries(user);
                        case 'delete':
                          setState(() => _toDelete = user);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_rounded),
                          title: Text('编辑'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'reset',
                        child: ListTile(
                          leading: Icon(Icons.key_rounded),
                          title: Text('重置密码'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'libraries',
                        child: ListTile(
                          leading: Icon(Icons.folder_rounded),
                          title: Text('媒体库授权'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        enabled: !isSelf,
                        child: const ListTile(
                          leading: Icon(Icons.delete_rounded),
                          title: Text('删除'),
                        ),
                      ),
                    ],
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);
    if (user.avatar != null && user.avatar!.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: 36,
          height: 36,
          child: ServerImage(url: user.avatar, borderRadius: BorderRadius.zero),
        ),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.accentOf(context).withValues(alpha: 0.15),
      child: Text(
        (user.title.isNotEmpty) ? user.title.characters.first : '?',
        style: TextStyle(
          color: AppColors.accentOf(context),
          fontSize: 15 * form.typeScale,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _UserTag extends StatelessWidget {
  const _UserTag({required this.text, required this.color});

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

/// 创建 / 编辑用户表单（对应 iOS UserEditView）。
class _UserEditDialog extends StatefulWidget {
  const _UserEditDialog({required this.session, required this.meId, this.user});

  final Session session;
  final int? meId;
  final UserProfile? user;

  @override
  State<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<_UserEditDialog> {
  late final TextEditingController _username;
  late final TextEditingController _nickname;
  late final TextEditingController _password;
  late String _role;
  late bool _enabled;
  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.user?.username ?? '');
    _nickname = TextEditingController(text: widget.user?.nickname ?? '');
    _password = TextEditingController();
    _role = widget.user?.role ?? 'USER';
    _enabled = widget.user?.enabled ?? true;
  }

  @override
  void dispose() {
    _username.dispose();
    _nickname.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_isEdit) return _nickname.text.trim().isNotEmpty && !_loading;
    return _username.text.trim().isNotEmpty &&
        _password.text.length >= 8 &&
        !_loading;
  }

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        await widget.session.api!.updateUser(
          widget.user!.id,
          nickname: _nickname.text.trim(),
          role: _role,
          enabled: _enabled,
        );
      } else {
        await widget.session.api!.createUser(
          username: _username.text.trim(),
          password: _password.text,
          nickname: _nickname.text.trim().isEmpty
              ? null
              : _nickname.text.trim(),
          role: _role,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);
    final isSelf = _isEdit && widget.user!.id == widget.meId;

    return AlertDialog(
      title: Text(_isEdit ? '编辑用户' : '创建用户'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(form, '用户名'),
              GlassTextField(
                controller: _username,
                placeholder: '用户名',
                enabled: !_isEdit,
                onChanged: (_) => setState(() {}),
              ),
              if (_isEdit) ...[
                const SizedBox(height: Dimens.spacingMd),
                _label(form, '昵称'),
                GlassTextField(
                  controller: _nickname,
                  placeholder: '昵称（选填）',
                  onChanged: (_) => setState(() {}),
                ),
              ] else ...[
                const SizedBox(height: Dimens.spacingMd),
                _label(form, '昵称（选填）'),
                GlassTextField(controller: _nickname, placeholder: '昵称（选填）'),
                const SizedBox(height: Dimens.spacingMd),
                _label(form, '密码'),
                GlassTextField(
                  controller: _password,
                  placeholder: '密码（至少 8 位）',
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: Dimens.spacingMd),
              _label(form, '角色'),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'USER', label: Text('普通用户')),
                  ButtonSegment(value: 'ADMIN', label: Text('管理员')),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              const SizedBox(height: Dimens.spacingMd),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '启用',
                      style: TextStyle(fontSize: 15 * form.typeScale),
                    ),
                  ),
                  Switch(
                    value: _enabled,
                    onChanged: isSelf
                        ? null
                        : (v) => setState(() => _enabled = v),
                  ),
                ],
              ),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accentOf(context),
          ),
          onPressed: _canSubmit ? _save : null,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(_isEdit ? '保存' : '创建'),
        ),
      ],
    );
  }

  Widget _label(DeviceForm form, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Dimens.spacingXs),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12 * form.typeScale,
          color: Theme.of(context).hintColor,
        ),
      ),
    );
  }
}
