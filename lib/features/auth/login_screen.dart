import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';

/// Login layout mirrors apple LoginView: brand row + server form + credentials.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session});

  final Session session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _publicHost = TextEditingController(text: 'frostine.top');
  final _lanHost = TextEditingController();
  final _port = TextEditingController(text: '20058');
  final _username = TextEditingController(text: 'admin');
  final _password = TextEditingController();

  String _scheme = 'http';
  String? _error;

  @override
  void dispose() {
    _publicHost.dispose();
    _lanHost.dispose();
    _port.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final ok = await widget.session.login(
      publicHost: _publicHost.text.trim(),
      lanHost: _lanHost.text.trim(),
      scheme: _scheme,
      port: _port.text.trim(),
      username: _username.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = widget.session.error ?? '登录失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);
    final fieldWidth = form.isPhone
        ? Dimens.maxFormWidth
        : (form.isTv ? 480.0 : 400.0);

    return GlassScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      edgeToEdge: true,
      statusBarStyle: GlassStatusBarStyle.none,
      extendBody: true,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: fieldWidth + Dimens.spacingXxl),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: Dimens.spacingXl,
              vertical: form.isTv ? Dimens.spacingXxl : Dimens.spacingXl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: Dimens.spacingLg,
                  runSpacing: Dimens.spacingMd,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      width: 72 * form.posterScale * 0.7,
                      height: 72 * form.posterScale * 0.7,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0A84FF), Color(0xFF5E5CE6)],
                        ),
                        borderRadius: BorderRadius.circular(Dimens.radiusLg),
                      ),
                      child: const Icon(Icons.movie_filter_rounded,
                          color: Colors.white, size: 36),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fryfrog Hub',
                          style: TextStyle(
                            fontSize: 32 * form.typeScale,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          '连接你的媒体库服务器',
                          style: TextStyle(
                            fontSize: 14 * form.typeScale,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: Dimens.spacingXxl),
                GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(Dimens.spacingLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Field(
                          label: '公网服务器地址',
                          hint: 'IP 或域名，如 192.168.1.100',
                          controller: _publicHost,
                          form: form,
                        ),
                        const SizedBox(height: Dimens.spacingLg),
                        _Field(
                          label: '局域网地址（选填）',
                          hint: '与公网共用协议与端口，局域网优先',
                          controller: _lanHost,
                          form: form,
                        ),
                        const SizedBox(height: Dimens.spacingLg),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('协议',
                                      style: TextStyle(
                                          fontSize: 12 * form.typeScale)),
                                  const SizedBox(height: Dimens.spacingXs),
                                  GlassSegmentedControl(
                                    segments: const [
                                      GlassSegment(label: 'http'),
                                      GlassSegment(label: 'https'),
                                    ],
                                    selectedIndex: _scheme == 'https' ? 1 : 0,
                                    onSegmentSelected: (i) => setState(
                                        () => _scheme = i == 1 ? 'https' : 'http'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: Dimens.spacingMd),
                            SizedBox(
                              width: form.isPhone ? 120 : 140,
                              child: _Field(
                                label: '端口',
                                hint: '20058',
                                controller: _port,
                                form: form,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Dimens.spacingLg),
                        _Field(
                          label: '用户名',
                          hint: 'admin',
                          controller: _username,
                          form: form,
                        ),
                        const SizedBox(height: Dimens.spacingLg),
                        GlassPasswordField(
                          controller: _password,
                          placeholder: '输入密码',
                          onSubmitted: (_) => _submit(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: Dimens.spacingMd),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: AppColors.danger,
                              fontSize: 13 * form.typeScale,
                            ),
                          ),
                        ],
                        const SizedBox(height: Dimens.spacingXl),
                        GlassButton.custom(
                          width: double.infinity,
                          height: 48 * form.typeScale,
                          style: GlassButtonStyle.filled,
                          onTap: widget.session.isLoading ? () {} : _submit,
                          child: Text(
                            widget.session.isLoading ? '登录中…' : '登录',
                            style: TextStyle(
                              fontSize: 16 * form.typeScale,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Dimens.spacingXl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    required this.form,
    this.keyboardType,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final DeviceForm form;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12 * form.typeScale,
            color: Theme.of(context).hintColor,
          ),
        ),
        const SizedBox(height: Dimens.spacingXs),
        GlassTextField(
          controller: controller,
          placeholder: hint,
          keyboardType: keyboardType,
        ),
      ],
    );
  }
}
