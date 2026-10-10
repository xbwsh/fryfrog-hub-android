import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/media_models.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';

/// 管理员给某用户分配可访问的媒体库（对应 iOS LibraryAccessView）。
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
          '媒体库授权 · ${widget.user.username}',
          style: TextStyle(
            fontSize: 17 * form.typeScale,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _dirty && !_saving ? _save : null,
            child: _saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: AppColors.accentOf(context),
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    '保存',
                    style: TextStyle(
                      color: AppColors.accentOf(context),
                      fontSize: 15 * form.typeScale,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(width: Dimens.spacingSm),
        ],
      ),
      body: _buildBody(form),
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

    return ListView(
      padding: const EdgeInsets.all(Dimens.spacingLg),
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Dimens.spacingMd),
            child: Text(
              _error!,
              style: TextStyle(
                fontSize: 13 * form.typeScale,
                color: AppColors.danger,
              ),
            ),
          ),
        if (_libraries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Dimens.spacingXl),
            child: Center(
              child: Text(
                '服务器上暂无媒体库',
                style: TextStyle(
                  fontSize: 14 * form.typeScale,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ),
          ),
        for (final lib in _libraries)
          Material(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(Dimens.radiusLg),
            clipBehavior: Clip.antiAlias,
            child: CheckboxListTile(
              value: _selected.contains(lib.id),
              onChanged: (_) => _toggle(lib.id),
              title: Text(
                lib.name,
                style: TextStyle(
                  fontSize: 15 * form.typeScale,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                lib.typeLabel,
                style: TextStyle(
                  fontSize: 12 * form.typeScale,
                  color: Theme.of(context).hintColor,
                ),
              ),
              activeColor: AppColors.accentOf(context),
            ),
          ),
        if (_libraries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Dimens.spacingMd),
            child: Text(
              _selected.isEmpty
                  ? '未选择任何媒体库，保存后该用户将看不到任何内容'
                  : '已选择 ${_selected.length} 个媒体库',
              style: TextStyle(
                fontSize: 12 * form.typeScale,
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
      ],
    );
  }
}
