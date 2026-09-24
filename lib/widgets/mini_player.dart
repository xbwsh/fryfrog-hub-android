import 'package:flutter/material.dart';

import '../core/adaptive/device_form.dart';
import '../core/theme/dimens.dart';

/// Compact glass mini player docked above navigation chrome.
class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);
    // Hidden until a real track is loaded.
    return const SizedBox.shrink();

    // ignore: dead_code
    return Container(
      height: Dimens.dockHeight - 8,
      padding: const EdgeInsets.symmetric(horizontal: Dimens.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Dimens.radiusXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Dimens.radiusSm),
            child: Container(
              width: 40 * form.posterScale * 0.7,
              height: 40 * form.posterScale * 0.7,
              color: Colors.white24,
            ),
          ),
          const SizedBox(width: Dimens.spacingMd),
          Expanded(
            child: Text(
              '未在播放',
              style: TextStyle(fontSize: 13 * form.typeScale),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
    );
  }
}
