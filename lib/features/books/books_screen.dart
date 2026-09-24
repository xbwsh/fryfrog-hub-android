import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/media_models.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../widgets/server_image.dart';

/// Books tab mirrors apple BooksTabView: ebooks / comics / audiobooks segments.
class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key, required this.session});

  final Session session;

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  static const _kinds = [
    BookShelfKind.ebook,
    BookShelfKind.comic,
    BookShelfKind.audiobook,
  ];
  static const _labels = ['电子书', '漫画', '有声书'];

  int _section = 0;

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);
    final session = widget.session;

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final kind = _kinds[_section];
        final books = session.booksOf(kind);

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
                          for (final label in _labels)
                            GlassSegment(label: label),
                        ],
                        selectedIndex: _section,
                        onSegmentSelected: (i) => setState(() => _section = i),
                      ),
                    ),
                  ),
                  const SizedBox(height: Dimens.spacingXl),
                  Expanded(
                    child: _BookShelfGrid(
                      kind: kind,
                      books: books,
                      form: form,
                      emptyLabel: '暂无${_labels[_section]}',
                      isLoading: session.isLoadingCatalog && books.isEmpty,
                      error: books.isEmpty ? session.catalogError : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BookShelfGrid extends StatelessWidget {
  const _BookShelfGrid({
    required this.kind,
    required this.books,
    required this.form,
    required this.emptyLabel,
    required this.isLoading,
    this.error,
  });

  final BookShelfKind kind;
  final List<BookItem> books;
  final DeviceForm form;
  final String emptyLabel;
  final bool isLoading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.accent,
          strokeWidth: 2.5,
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Text(
          error!,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14 * form.typeScale,
            color: Theme.of(context).hintColor,
          ),
        ),
      );
    }

    if (books.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: TextStyle(
            fontSize: 15 * form.typeScale,
            color: Theme.of(context).hintColor,
          ),
        ),
      );
    }

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
        childAspectRatio: 0.72,
      ),
      itemCount: books.length,
      itemBuilder: (context, i) {
        final book = books[i];
        final cover = (book.coverUrl != null && book.coverUrl!.isNotEmpty)
            ? book.coverUrl
            : kind.coverPath(book.id);
        final progress = (book.positionPercent ?? 0) / 100;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ServerImage(
                    url: cover,
                    borderRadius: BorderRadius.circular(Dimens.radiusMd),
                  ),
                  if (progress > 0)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(Dimens.radiusMd),
                        ),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: Colors.black26,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Dimens.spacingXs),
            Text(
              book.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13 * form.typeScale,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (book.subtitle.isNotEmpty)
              Text(
                book.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12 * form.typeScale,
                  color: Theme.of(context).hintColor,
                ),
              ),
          ],
        );
      },
    );
  }
}
