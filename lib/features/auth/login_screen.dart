import 'package:flutter/cupertino.dart' show CupertinoColors, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/server_profile.dart';
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
  // 公网地址与用户名首启必须留空：写死 frostine.top / admin 会把用户
  // 引到别人的服务器，且与 ServerConnection.publicHost 的空串默认不一致。
  // 登录成功后由 savedLoginDefaults() 回填用户自己的值；端口/协议无歧义，预填。
  final _publicHost = TextEditingController();
  final _lanHost = TextEditingController();
  final _port = TextEditingController(text: '20058');
  final _username = TextEditingController();
  final _password = TextEditingController();

  String _scheme = 'http';
  String? _error;

  /// 已保存的服务器档案，用于"点一下切换服务器"。不含密码。
  List<ServerProfile> _profiles = const [];

  @override
  void initState() {
    super.initState();
    _backfillSaved();
  }

  /// 回填上次保存的服务器配置与用户名（对齐 iOS LoginViewModel.init），
  /// 否则每次登录都要重填地址、且局域网地址会被丢成默认值。
  Future<void> _backfillSaved() async {
    final saved = await widget.session.savedLoginDefaults();
    final profiles = await widget.session.listProfiles();
    if (!mounted) return;
    setState(() {
      _scheme = saved.scheme;
      _publicHost.text = saved.publicHost;
      _lanHost.text = saved.lanHost;
      _port.text = saved.port;
      _username.text = saved.username;
      _profiles = profiles;
    });
  }

  /// 当前表单是否已等于这条档案（用于高亮 chip）。
  bool _isSelected(ServerProfile p) =>
      p.publicHost.trim() == _publicHost.text.trim() &&
      p.lanHost.trim() == _lanHost.text.trim() &&
      p.port.trim() == _port.text.trim() &&
      p.scheme == _scheme;

  /// 点 chip → 用整条档案覆盖表单；密码不参与（档案不存密码），
  /// 由用户按需重新输入。
  void _applyProfile(ServerProfile p) {
    setState(() {
      _publicHost.text = p.publicHost;
      _lanHost.text = p.lanHost;
      _port.text = p.port;
      _scheme = p.scheme;
      _username.text = p.username;
      _error = null;
    });
  }

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
    // Wide targets get a 6:4 hero split: brand left, login card right.
    final split = form.isTabletLandscape || form.isTv;
    final verticalPad = form.isTv ? Dimens.spacingXxl : Dimens.spacingXl;

    return GlassScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      edgeToEdge: true,
      statusBarStyle: GlassStatusBarStyle.none,
      extendBody: true,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: split
                ? form.contentMaxWidth
                : fieldWidth + Dimens.spacingXxl,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: Dimens.spacingXl,
              vertical: verticalPad,
            ),
            child: split
                ? ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          MediaQuery.sizeOf(context).height - verticalPad * 2,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(flex: 6, child: _brandHero(context, form)),
                        const SizedBox(width: Dimens.spacingXl),
                        Expanded(flex: 4, child: _formCard(context, form)),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _brandRow(context, form),
                      const SizedBox(height: Dimens.spacingXxl),
                      _formCard(context, form),
                      const SizedBox(height: Dimens.spacingXl),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// Compact brand strip for phone / tablet-portrait (unchanged layout).
  Widget _brandRow(BuildContext context, DeviceForm form) {
    return Wrap(
      spacing: Dimens.spacingLg,
      runSpacing: Dimens.spacingMd,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _brandIcon(form),
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
    );
  }

  /// Stacked hero brand for the 60% panel on wide screens.
  Widget _brandHero(BuildContext context, DeviceForm form) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _brandIcon(form, box: 96 * form.posterScale * 0.7),
        const SizedBox(height: Dimens.spacingLg),
        Text(
          'Fryfrog Hub',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 44 * form.typeScale,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: Dimens.spacingSm),
        Text(
          '连接你的媒体库服务器',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16 * form.typeScale,
            color: Theme.of(context).hintColor,
          ),
        ),
      ],
    );
  }

  Widget _brandIcon(DeviceForm form, {double? box}) {
    final d = box ?? 72 * form.posterScale * 0.7;
    return SizedBox(
      width: d,
      height: d,
      child: Image.asset('assets/images/fryfrog_hub_icon.png', fit: BoxFit.contain),
    );
  }

  Widget _formCard(BuildContext context, DeviceForm form) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(Dimens.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_profiles.isNotEmpty) ...[
              Text(
                '已保存服务器',
                style: TextStyle(
                  fontSize: 12 * form.typeScale,
                  color: Theme.of(context).hintColor,
                ),
              ),
              const SizedBox(height: Dimens.spacingXs),
              Wrap(
                spacing: Dimens.spacingSm,
                runSpacing: Dimens.spacingSm,
                children: [
                  for (final p in _profiles)
                    ChoiceChip(
                      label: Text(
                        p.label,
                        style: TextStyle(
                          fontSize: 13 * form.typeScale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      selected: _isSelected(p),
                      onSelected: (_) => _applyProfile(p),
                    ),
                ],
              ),
              const SizedBox(height: Dimens.spacingLg),
            ],
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
                      Text(
                        '协议',
                        style: TextStyle(fontSize: 12 * form.typeScale),
                      ),
                      const SizedBox(height: Dimens.spacingXs),
                      GlassSegmentedControl(
                        segments: const [
                          GlassSegment(label: 'http'),
                          GlassSegment(label: 'https'),
                        ],
                        selectedIndex: _scheme == 'https' ? 1 : 0,
                        onSegmentSelected: (i) =>
                            setState(() => _scheme = i == 1 ? 'https' : 'http'),
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
              label: '账号和密码',
              hint: '输入账号',
              controller: _username,
              form: form,
              icon: Icon(
                CupertinoIcons.person_fill,
                size: 20,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
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
              shape: const LiquidRoundedRectangle(
                borderRadius: Dimens.radiusLg,
              ),
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
    this.icon,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final DeviceForm form;
  final TextInputType? keyboardType;

  /// 字段左侧图标；与 GlassPasswordField 自带的锁图标同规格
  /// （size 20 + secondaryLabel），保证账号/密码两行视觉对齐。
  final Widget? icon;

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
          prefixIcon: icon,
          keyboardType: keyboardType,
        ),
      ],
    );
  }
}
