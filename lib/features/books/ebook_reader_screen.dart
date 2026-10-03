import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/media_models.dart';
import '../../core/network/gateways.dart';
import '../../core/network/gateways_impl.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import 'ebook_reader_controller.dart';

/// Full-screen TXT ebook chapter reader (vertical text scroll).
/// Orchestration lives in [EbookReaderController].
class EbookReaderScreen extends StatefulWidget {
  const EbookReaderScreen({
    super.key,
    required this.session,
    required this.bookId,
    required this.title,
    required this.chapters,
    this.initialChapterIndex = 0,
  });

  final Session session;
  final int bookId;
  final String title;
  final List<BookChapter> chapters;
  final int initialChapterIndex;

  @override
  State<EbookReaderScreen> createState() => _EbookReaderScreenState();
}

class _EbookReaderScreenState extends State<EbookReaderScreen>
    with WidgetsBindingObserver {
  late final EbookReaderController _c;
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _reHideTimer;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Reading owns the screen — hide status / navigation bars; restored in
    // dispose, re-asserted on rotation (see _reassertImmersive).
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    final api = widget.session.api;
    _c = EbookReaderController(
      gateway: api == null ? _NullEbookGateway() : ApiEbookGateway(api),
      bookId: widget.bookId,
      chapters: widget.chapters,
      initialChapterIndex: widget.initialChapterIndex,
    );
    _c.addListener(_onChanged);
    unawaited(_c.load());
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// Rotating the device (or returning from background) makes the OS bring
  /// the status / navigation bars back; re-hide them. The trailing timer
  /// retries once after things settle — Android drops system UI changes
  /// issued within 1s of a previous one.
  void _reassertImmersive() {
    if (!mounted) return;
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    _reHideTimer?.cancel();
    _reHideTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
    });
  }

  @override
  void didChangeMetrics() => _reassertImmersive();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reassertImmersive();
  }

  @override
  void dispose() {
    _reHideTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_restoreAppChrome());
    _c
      ..removeListener(_onChanged)
      ..dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _goToChapter(int pos) async {
    if (pos < 0 || pos >= _c.chapterCount || pos == _c.chapterPos) return;
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    await _c.goToChapter(pos);
    if (mounted && _scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    final max = n.metrics.maxScrollExtent;
    _c.onScrollFraction(max <= 0 ? 0 : n.metrics.pixels / max);
    return false;
  }

  Future<void> _openChapterSheet() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Dimens.radiusLg),
        ),
      ),
      builder: (context) {
        final maxH = MediaQuery.sizeOf(context).height * 0.6;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: Dimens.spacingSm),
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                indent: Dimens.spacingLg,
                endIndent: Dimens.spacingLg,
              ),
              itemCount: _c.chapters.length,
              itemBuilder: (context, i) {
                final c = _c.chapters[i];
                final selectedHere = i == _c.chapterPos;
                return ListTile(
                  dense: true,
                  leading: Text(
                    '${c.chapterIndex + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selectedHere
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).hintColor,
                    ),
                  ),
                  title: Text(
                    c.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: selectedHere
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  trailing: selectedHere
                      ? Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, i),
                );
              },
            ),
          ),
        );
      },
    );
    if (selected != null) await _goToChapter(selected);
  }

  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select) {
      if (_c.hasNextChapter) _goToChapter(_c.chapterPos + 1);
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.pageUp) {
      if (_c.hasPrevChapter) _goToChapter(_c.chapterPos - 1);
    } else if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      _exit();
    }
  }

  Future<void> _restoreAppChrome() => SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: SystemUiOverlay.values,
  );

  Future<void> _exit() async {
    if (_exiting) return;
    _exiting = true;
    final navigator = Navigator.of(context);
    // Bring the bars back while this route still covers the detail page —
    // otherwise its top bar reflows downward right after the pop reveals it.
    final save = _c.flushProgress();
    await _restoreAppChrome();
    await save;
    // Pop (not maybePop): PopScope below keeps canPop false so the system
    // back gesture routes through here instead of racing dispose.
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final form = AdaptiveScope.of(context);
    final pad = MediaQuery.paddingOf(context);

    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        _onKey(event);
        return KeyEventResult.ignored;
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || _exiting) return;
          unawaited(_exit());
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _c.toggleChrome,
                child: _buildBody(form, pad),
              ),
              if (_c.chromeVisible)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _TopBar(
                    form: form,
                    title: widget.title,
                    chapterLabel: _c.chapterLabel,
                    onPage: _c.chapterCount <= 1
                        ? null
                        : '${_c.chapterPos + 1}/${_c.chapterCount}',
                    onBack: _exit,
                    onChapters: _c.chapterCount > 1 ? _openChapterSheet : null,
                  ),
                ),
              if (_c.chromeVisible && _c.chapterCount > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _BottomBar(
                    form: form,
                    chapterPos: _c.chapterPos,
                    chapterCount: _c.chapterCount,
                    canPrev: _c.hasPrevChapter,
                    canNext: _c.hasNextChapter,
                    onPrev: () => _goToChapter(_c.chapterPos - 1),
                    onNext: () => _goToChapter(_c.chapterPos + 1),
                    onSlider: (v) => _goToChapter(v.round()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(DeviceForm form, EdgeInsets pad) {
    if (_c.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Dimens.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _c.error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14 * form.typeScale,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: Dimens.spacingLg),
              FilledButton(
                onPressed: _c.chapters.isEmpty ? null : () => _c.load(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_c.loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.accent,
          strokeWidth: 2.5,
        ),
      );
    }

    final topPad = _c.chromeVisible
        ? pad.top + kToolbarHeight
        : pad.top + Dimens.spacingLg;
    final bottomPad = _c.chromeVisible
        ? pad.bottom + Dimens.readerChromeExtent
        : pad.bottom + Dimens.spacingLg;

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: SingleChildScrollView(
        controller: _scrollCtrl,
        padding: EdgeInsets.only(
          top: topPad,
          bottom: bottomPad,
          left: Dimens.spacingLg,
          right: Dimens.spacingLg,
        ),
        child: Text(
          _c.content,
          style: TextStyle(
            fontSize: Dimens.ebookTextSize * form.typeScale,
            height: Dimens.ebookTextLineHeight,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Fail-fast stub when Session has no ApiClient.
class _NullEbookGateway implements EbookGateway {
  @override
  Future<List<BookChapter>> fetchChapters(int bookId) =>
      throw UnsupportedError('not logged in');

  @override
  Future<EbookChapterContent> fetchChapterContent(
    int bookId, {
    required int chapterIndex,
  }) => throw UnsupportedError('not logged in');

  @override
  Future<void> saveProgress(
    int bookId, {
    required double positionPercent,
    required int chapterIndex,
  }) => throw UnsupportedError('not logged in');
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.form,
    required this.title,
    required this.chapterLabel,
    required this.onBack,
    this.onPage,
    this.onChapters,
  });

  final DeviceForm form;
  final String title;
  final String chapterLabel;
  final String? onPage;
  final VoidCallback onBack;
  final VoidCallback? onChapters;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              IconButton(
                tooltip: '返回',
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: onBack,
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14 * form.typeScale,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      [chapterLabel, ?onPage].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11 * form.typeScale,
                      ),
                    ),
                  ],
                ),
              ),
              if (onChapters != null)
                IconButton(
                  tooltip: '目录',
                  icon: const Icon(Icons.list_alt_rounded, color: Colors.white),
                  onPressed: onChapters,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.form,
    required this.chapterPos,
    required this.chapterCount,
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
    required this.onSlider,
  });

  final DeviceForm form;
  final int chapterPos;
  final int chapterCount;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<double> onSlider;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimens.spacingXs,
            Dimens.spacingXs,
            Dimens.spacingXs,
            Dimens.spacingSm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: '上一章',
                    onPressed: canPrev ? onPrev : null,
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      color: canPrev ? Colors.white : Colors.white24,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: chapterPos.clamp(0, chapterCount - 1).toDouble(),
                      min: 0,
                      max: (chapterCount - 1)
                          .clamp(0, double.infinity)
                          .toDouble(),
                      divisions: chapterCount <= 1 ? 1 : chapterCount - 1,
                      label: '${chapterPos + 1}',
                      onChanged: chapterCount <= 1 ? null : (v) => onSlider(v),
                    ),
                  ),
                  IconButton(
                    tooltip: '下一章',
                    onPressed: canNext ? onNext : null,
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      color: canNext ? Colors.white : Colors.white24,
                    ),
                  ),
                ],
              ),
              Text(
                '第 ${chapterPos + 1} / $chapterCount 章',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11 * form.typeScale,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
