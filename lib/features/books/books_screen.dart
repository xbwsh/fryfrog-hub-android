import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/state/session.dart';
import '../../core/theme/dimens.dart';

/// Books tab mirrors apple BooksTabView: ebooks / comics / audiobooks segments.
class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key, required this.session});

  final Session session;

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  int _section = 0;
  static const _labels = ['电子书', '漫画', '有声书'];

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.all(
            form.isTv ? Dimens.spacingXxl : Dimens.spacingLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '书架',
                style: TextStyle(
                  fontSize: 28 * form.typeScale,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: Dimens.spacingLg),
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: GlassSegmentedControl(
                    segments: [
                      for (final label in _labels) GlassSegment(label: label),
                    ],
                    selectedIndex: _section,
                    onSegmentSelected: (i) => setState(() => _section = i),
                  ),
                ),
              ),
              const SizedBox(height: Dimens.spacingXl),
              Expanded(
                child: _BookShelfGrid(section: _labels[_section], form: form),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookShelfGrid extends StatelessWidget {
  const _BookShelfGrid({required this.section, required this.form});

  final String section;
  final DeviceForm form;

  @override
  Widget build(BuildContext context) {
    final cols = form.isTv
        ? 6
        : form.isTabletLandscape
            ? 5
            : form.isTabletPortrait
                ? 4
                : 3;

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: Dimens.spacingLg,
        crossAxisSpacing: Dimens.spacingLg,
        childAspectRatio: 2 / 3,
      ),
      itemCount: 18,
      itemBuilder: (context, i) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Dimens.radiusMd),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.primaries[i % Colors.primaries.length]
                          .withValues(alpha: 0.75),
                      Colors.primaries[(i + 4) % Colors.primaries.length]
                          .withValues(alpha: 0.55),
                    ],
                  ),
                ),
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.all(Dimens.spacingSm),
                child: Text(
                  '$section ${i + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: Dimens.spacingXs),
            Text(
              '$section标题 ${i + 1}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13 * form.typeScale,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}
