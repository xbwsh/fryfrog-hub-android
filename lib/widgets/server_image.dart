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
    this.alignment = Alignment.center,
    this.borderRadius,
    this.session,
  });

  final String? url;
  final BoxFit fit;
  final Alignment alignment;
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

    final s = session ?? SessionScope.of(context);
    final resolved = path.startsWith('http')
        ? path
        : (s.resolveImage(path) ?? path);
    // Cover endpoints require Bearer auth — without it every image 401s
    // and the list shows one identical placeholder.
    final token = s.token;
    final headers = <String, String>{
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    // Decode at display size, not source size: covers/fanart from media
    // servers are often 1080p+, and every grid tile decoding full-size is
    // the app's biggest memory cost. Unbounded constraints (rare) fall
    // back to a screen-width cap.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final screenWidth = MediaQuery.sizeOf(context).width;

    return ClipRRect(
      borderRadius: radius,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final logicalWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : screenWidth;
          final pixels = (logicalWidth * dpr).round();
          return CachedNetworkImage(
            imageUrl: resolved,
            fit: fit,
            alignment: alignment,
            width: double.infinity,
            height: double.infinity,
            httpHeaders: headers,
            memCacheWidth: pixels > 0 ? pixels : null,
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
            errorListener: (e) {
              debugPrint('ServerImage failed: $resolved — $e');
            },
          );
        },
      ),
    );
  }
}

/// Inherited access to [Session] for image URL resolution.
class SessionScope extends InheritedWidget {
  const SessionScope({super.key, required this.session, required super.child});

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
