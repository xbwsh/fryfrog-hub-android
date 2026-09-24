import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/network/server_connection.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';

/// Profile mirrors apple ProfileView sections: account / admin / server /
/// appearance / playback / cache / privacy / support / logout.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final user = session.user;
        final connection = session.connection;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: form.contentMaxWidth),
                child: ListView(
                  padding: EdgeInsets.all(
                    form.isTv ? Dimens.spacingXxl : Dimens.spacingLg,
                  ),
                  children: [
                    Text(
                      '我的',
                      style: TextStyle(
                        fontSize: 28 * form.typeScale,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: Dimens.spacingXl),
                    GlassCard(
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 26 * form.posterScale * 0.8,
                          backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                          child: Text(
                            (user?.title.isNotEmpty ?? false)
                                ? user!.title.characters.first
                                : '?',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 20 * form.typeScale,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(
                          user?.title ?? '未登录',
                          style: TextStyle(
                            fontSize: 17 * form.typeScale,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          user == null ? '' : '@${user.username} · ${user.roleText}',
                          style: TextStyle(fontSize: 13 * form.typeScale),
                        ),
                      ),
                    ),
                    const SizedBox(height: Dimens.spacingLg),
                    _SectionCard(
                      title: '账户',
                      form: form,
                      children: [
                        _NavTile(
                          icon: Icons.key_rounded,
                          label: '修改密码',
                          form: form,
                        ),
                        if (user?.isAdmin == true)
                          _NavTile(
                            icon: Icons.groups_2_rounded,
                            label: '用户管理',
                            form: form,
                          ),
                      ],
                    ),
                    if (user?.isAdmin == true) ...[
                      const SizedBox(height: Dimens.spacingLg),
                      _SectionCard(
                        title: '管理',
                        form: form,
                        children: [
                          _NavTile(
                            icon: Icons.video_library_rounded,
                            label: '媒体库管理',
                            form: form,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: Dimens.spacingLg),
                    _SectionCard(
                      title: '服务器',
                      form: form,
                      children: [
                        _AddressTile(
                          mode: ServerConnectionMode.public,
                          connection: connection,
                          form: form,
                        ),
                        if (connection.hasLan)
                          _AddressTile(
                            mode: ServerConnectionMode.lan,
                            connection: connection,
                            form: form,
                          ),
                      ],
                    ),
                    const SizedBox(height: Dimens.spacingLg),
                    _SectionCard(
                      title: '外观',
                      form: form,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(Dimens.spacingLg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '主题',
                                style: TextStyle(
                                  fontSize: 13 * form.typeScale,
                                  color: Theme.of(context).hintColor,
                                ),
                              ),
                              const SizedBox(height: Dimens.spacingSm),
                              GlassSegmentedControl(
                                segments: [
                                  for (final mode in ThemeModePref.values)
                                    GlassSegment(label: mode.title),
                                ],
                                selectedIndex:
                                    ThemeModePref.values.indexOf(session.themeMode),
                                onSegmentSelected: (i) => session.setThemeMode(
                                  ThemeModePref.values[i],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Dimens.spacingLg),
                    _SectionCard(
                      title: '隐私',
                      form: form,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Dimens.spacingLg,
                            vertical: Dimens.spacingMd,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '隐私模式',
                                  style: TextStyle(fontSize: 15 * form.typeScale),
                                ),
                              ),
                              GlassSwitch(
                                value: session.privacyEnabled,
                                onChanged: session.setPrivacy,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Dimens.spacingLg),
                    _SectionCard(
                      title: '支持',
                      form: form,
                      children: [
                        _NavTile(
                          icon: Icons.favorite_rounded,
                          label: '支持开发者',
                          form: form,
                        ),
                      ],
                    ),
                    const SizedBox(height: Dimens.spacingXl),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: GlassButton.custom(
                          height: 48,
                          onTap: () => session.logout(),
                          child: Text(
                            '退出登录',
                            style: TextStyle(
                              color: AppColors.danger,
                              fontSize: 15 * form.typeScale,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Dimens.dockHeight + Dimens.spacingXl),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    required this.form,
  });

  final String title;
  final List<Widget> children;
  final DeviceForm form;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: Dimens.spacingSm,
            bottom: Dimens.spacingSm,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13 * form.typeScale,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).hintColor,
            ),
          ),
        ),
        GlassCard(
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.form,
  });

  final IconData icon;
  final String label;
  final DeviceForm form;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: !form.isTv,
      leading: Icon(icon),
      title: Text(label, style: TextStyle(fontSize: 15 * form.typeScale)),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.mode,
    required this.connection,
    required this.form,
  });

  final ServerConnectionMode mode;
  final ServerConnection connection;
  final DeviceForm form;

  @override
  Widget build(BuildContext context) {
    final url = connection.urlString(mode) ?? '未配置';
    final active = connection.effectiveMode == mode;
    final label = mode == ServerConnectionMode.lan ? '局域网' : '公网';

    return ListTile(
      dense: !form.isTv,
      leading: Icon(
        mode == ServerConnectionMode.lan ? Icons.wifi_rounded : Icons.public_rounded,
        color: active ? AppColors.accent : Theme.of(context).hintColor,
      ),
      title: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 15 * form.typeScale)),
          if (active) ...[
            const SizedBox(width: Dimens.spacingSm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '使用中',
                style: TextStyle(
                  fontSize: 11 * form.typeScale,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        url,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12 * form.typeScale),
      ),
    );
  }
}
