import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/state/session.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/dimens.dart';

/// Network image that resolves relative API paths via [Session].
class ServerImage extends StatelessWidget {
  const ServerImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.session,
  });

  final String? url;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Session? session;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(Dimens.radiusMd);
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: radius,
      ),
    );

    final path = url;
    if (path == null || path.isEmpty) return placeholder;

    final resolved = _resolve(context, path);

    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: resolved,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => placeholder,
        errorListener: (_) {},
      ),
    );
  }

  String _resolve(BuildContext context, String path) {
    if (path.startsWith('http')) return path;
    final s = session ?? SessionScope.of(context);
    return s.resolveImage(path) ?? path;
  }
}

/// Inherited access to [Session] for image URL resolution.
class SessionScope extends InheritedWidget {
  const SessionScope({
    super.key,
    required this.session,
    required super.child,
  });

  final Session session;

  static Session of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope missing above this context');
    return scope!.session;
  }

  @override
  bool updateShouldNotify(SessionScope oldWidget) =>
      session != oldWidget.session;
}
