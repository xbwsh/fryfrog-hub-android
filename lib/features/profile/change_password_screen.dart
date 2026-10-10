import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';

/// 修改自己的密码（对应 iOS ChangePasswordView）。
/// 成功后后端会作废当前 token，提示重新登录。
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.session});

  final Session session;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _old.text.isNotEmpty &&
      _new.text.length >= 8 &&
      _confirm.text.isNotEmpty &&
      !_loading;

  Future<void> _save() async {
    if (_new.text != _confirm.text) {
      setState(() => _error = '两次输入的新密码不一致');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.session.api!.changeMyPassword(
        oldPassword: _old.text,
        newPassword: _new.text,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('密码修改成功'),
          content: const Text('为安全起见将退出登录，请使用新密码重新登录'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.session.logout();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);
    final mismatch = _confirm.text.isNotEmpty && _new.text != _confirm.text;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '修改密码',
          style: TextStyle(
            fontSize: 17 * form.typeScale,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Dimens.spacingLg),
        children: [
          GlassTextField(
            controller: _old,
            placeholder: '当前密码',
            obscureText: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Dimens.spacingLg),
          GlassTextField(
            controller: _new,
            placeholder: '新密码（至少 8 位）',
            obscureText: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Dimens.spacingLg),
          GlassTextField(
            controller: _confirm,
            placeholder: '确认新密码',
            obscureText: true,
            onChanged: (_) => setState(() {}),
          ),
          if (mismatch)
            Padding(
              padding: const EdgeInsets.only(top: Dimens.spacingSm),
              child: Text(
                '两次输入的新密码不一致',
                style: TextStyle(
                  fontSize: 13 * form.typeScale,
                  color: AppColors.danger,
                ),
              ),
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
          SizedBox(height: Dimens.spacingXl),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentOf(context),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _canSubmit ? _save : null,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    '修改密码',
                    style: TextStyle(
                      fontSize: 15 * form.typeScale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
