import 'package:flutter/material.dart';

import '../core/adaptive/device_form.dart';
import '../core/state/session.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/dimens.dart';
import '../features/auth/login_screen.dart';
import 'main_shell.dart';

/// Mirrors apple RootView: loading → auth gate → main tabs + global toast.
class RootView extends StatefulWidget {
  const RootView({super.key, required this.session});

  final Session session;

  @override
  State<RootView> createState() => _RootViewState();
}

class _RootViewState extends State<RootView> {
  String? _notice;

  @override
  void initState() {
    super.initState();
    widget.session.restoreSession();
  }

  void showNotice(String text) {
    setState(() => _notice = text);
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted && _notice == text) setState(() => _notice = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);

    return ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) {
        final body = switch ((widget.session.isLoading, widget.session.isAuthenticated)) {
          (true, _) => _LoadingView(form: form),
          (false, true) => MainShell(session: widget.session),
          _ => LoginScreen(session: widget.session),
        };

        return Scaffold(
          backgroundColor: AppColors.background(context),
          extendBody: true,
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              Positioned.fill(child: body),
              if (_notice != null)
                Positioned(
                  top: Dimens.spacingSm + MediaQuery.paddingOf(context).top,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimens.spacingLg,
                        vertical: Dimens.spacingSm + 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _notice!,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13 * form.typeScale,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.form});

  final DeviceForm form;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator.adaptive(),
          const SizedBox(height: Dimens.spacingLg),
          Text(
            '连接服务器…',
            style: TextStyle(fontSize: 15 * form.typeScale),
          ),
        ],
      ),
    );
  }
}
