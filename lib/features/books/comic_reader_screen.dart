import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/media_models.dart';
import '../../core/network/gateways.dart';
import '../../core/network/gateways_impl.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import 'comic_reader_controller.dart';

/// Full-screen comic chapter reader: continuous scroll or page flip.
/// Orchestration lives in [ComicReaderController].
class ComicReaderScreen extends StatefulWidget {
  const ComicReaderScreen({
    super.key,
    required this.session,
    required this.comicId,
    required this.title,
    required this.chapters,
    this.initialChapterIndex = 0,
    this.initialPageIndex = 0,
  });

  final Session session;
  final int comicId;
  final String title;
  final List<BookChapter> chapters;
  final int initialChapterIndex;
  final int initialPageIndex;

  @override
  State<ComicReaderScreen> createState() => _ComicReaderScreenState();
}

class _ComicReaderScreenState extends State<ComicReaderScreen>
    with WidgetsBindingObserver {
  late final ComicReaderController _c;
  final ScrollController _scrollCtrl = ScrollController(
    keepScrollOffset: false,
  );
  final PageController _pageCtrl = PageController();
  final List<GlobalKey> _pageKeys = [];
  int _verticalAnchor = 0;
  bool _positioning = false;
  final GlobalKey _anchorKey = GlobalKey();
  Timer? _reHideTimer;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Reading owns the screen — hide status / navigation bars like the
    // video player does; restored in dispose.
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    final api = widget.session.api;
    _c = ComicReaderController(
      gateway: api == null ? _NullComicGateway() : ApiComicGateway(api),
      comicId: widget.comicId,
      chapters: widget.chapters,
      initialChapterIndex: widget.initialChapterIndex,
      initialPageIndex: widget.initialPageIndex,
    );
    _c.addListener(_onChanged);
    if (api != null) {
      unawaited(
        _c.loadPages(initial: true).then((_) {
          if (!mounted) return;
          _syncKeys();
          if (_c.pageIndex > 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (_c.mode == ComicReaderController.readerModePage) {
                if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(_c.pageIndex);
              } else {
                _restoreVerticalOffset();
              }
            });
          }
        }),
      );
    }
  }

  void _onChanged() {
    if (mounted) setState(_syncKeys);
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

  void _syncKeys() {
    if (_c.loading) _verticalAnchor = 0;
    final n = _c.pageUrls.length;
    while (_pageKeys.length > n) {
      _pageKeys.removeLast();
    }
    while (_pageKeys.length < n) {
      _pageKeys.add(GlobalKey());
    }
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
    _pageCtrl.dispose();
    super.dispose();
  }

  void _restoreVerticalOffset() {
    if (_c.pageUrls.isEmpty) return;
    _positioning = true;
    setState(() => _verticalAnchor = _c.pageIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
      _positioning = false;
    });
  }

  String _resolve(String path) {
    if (path.startsWith('http')) return path;
    return widget.session.resolveImage(path) ?? path;
  }

  Map<String, String> get _headers {
    final token = widget.session.token;
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  void _goToPage(int index) {
    if (_c.pageUrls.isEmpty) return;
    _c.goToPage(index);
    if (_c.mode == ComicReaderController.readerModePage) {
      if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(_c.pageIndex);
    } else {
      _restoreVerticalOffset();
    }
  }

  void _onHorizontalPage(int index) {
    if (index == _c.pageIndex) return;
    _c.goToPage(index);
  }

  void _onVerticalScroll() {
    final urls = _c.pageUrls;
    if (_positioning || _pageKeys.isEmpty || _c.loading || urls.isEmpty) return;
    int best = -1;
    double bestScore = double.negativeInfinity;
    final size = MediaQuery.sizeOf(context);
    final focusY = size.height * 0.45;
    for (var i = 0; i < _pageKeys.length; i++) {
      final ctx = _pageKeys[i].currentContext;
      final box = ctx?.findRenderObject();
      if (box is! RenderBox || !box.attached || box.size.height <= 0) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      final bottom = top + box.size.height;
      if (bottom < 0 || top > size.height) continue;
      final center = (top + bottom) / 2;
      final score = -((center - focusY).abs());
      if (score > bestScore) {
        bestScore = score;
        best = i;
      }
    }
    if (best < 0) return;
    if (best != _c.pageIndex) {
      _c.onScrollPageCandidate(best);
    }
  }

  Future<void> _openChapterSheet() async {
    final chapters = _c.chapters;
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
              itemCount: chapters.length,
              itemBuilder: (context, i) {
                final c = chapters[i];
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
                      : (c.pageCount != null
                            ? Text(
                                '${c.pageCount}P',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).hintColor,
                                ),
                              )
                            : null),
                  onTap: () => Navigator.pop(context, i),
                );
              },
            ),
          ),
        );
      },
    );
    if (selected != null) {
      _pageKeys.clear();
      _verticalAnchor = 0;
      await _c.switchChapter(selected);
      if (mounted) {
        _syncKeys();
      }
    }
  }

  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select) {
      if (_c.pageIndex + 1 < _c.pageCount) {
        _goToPage(_c.pageIndex + 1);
      } else if (_c.hasNextChapter) {
        _c.switchChapter(_c.chapterPos + 1);
      }
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.pageUp) {
      if (_c.pageIndex > 0) {
        _goToPage(_c.pageIndex - 1);
      } else if (_c.hasPrevChapter) {
        _c.switchChapter(_c.chapterPos - 1);
      }
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
    final mode = _c.mode;

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
                    chapterLabel: _c.chapters.isEmpty ? '' : _c.chapterLabel,
                    onPage: _c.pageUrls.isEmpty
                        ? null
                        : '${_c.pageIndex + 1}/${_c.pageCount}',
                    onBack: _exit,
                    onChapters: _c.chapters.length > 1
                        ? _openChapterSheet
                        : null,
                    onToggleMode: () {
                      final page = _c.pageIndex;
                      _c.setMode(
                        mode == ComicReaderController.readerModeScroll
                            ? ComicReaderController.readerModePage
                            : ComicReaderController.readerModeScroll,
                      );
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        if (_c.mode == ComicReaderController.readerModePage) {
                          if (_pageCtrl.hasClients && page < _c.pageCount) {
                            _pageCtrl.jumpToPage(page);
                          }
                        } else {
                          _restoreVerticalOffset();
                        }
                      });
                    },
                    modeIcon: mode == ComicReaderController.readerModeScroll
                        ? Icons.swap_vert_rounded
                        : Icons.swap_horiz_rounded,
                    modeTooltip: mode == ComicReaderController.readerModeScroll
                        ? '切换为翻页'
                        : '切换为滚动',
                  ),
                ),
              if (_c.chromeVisible && _c.pageUrls.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _BottomBar(
                    form: form,
                    pageIndex: _c.pageIndex,
                    pageCount: _c.pageCount,
                    canPrevChapter: _c.hasPrevChapter,
                    canNextChapter: _c.hasNextChapter,
                    onPrevPage: () => _goToPage(_c.pageIndex - 1),
                    onNextPage: () {
                      if (_c.pageIndex + 1 < _c.pageCount) {
                        _goToPage(_c.pageIndex + 1);
                      } else if (_c.hasNextChapter) {
                        _c.switchChapter(_c.chapterPos + 1);
                      }
                    },
                    onPrevChapter: () => _c.switchChapter(_c.chapterPos - 1),
                    onNextChapter: () => _c.switchChapter(_c.chapterPos + 1),
                    onSlider: (v) => _goToPage(v.round()),
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
                onPressed: _c.chapters.isEmpty ? null : () => _c.loadPages(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_c.loading || _c.pageUrls.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color: AppColors.accentOf(context),
          strokeWidth: 2.5,
        ),
      );
    }

    final topPad = pad.top + kToolbarHeight;
    final bottomPad = pad.bottom + (_c.chromeVisible ? 88.0 : Dimens.spacingLg);

    if (_c.mode == ComicReaderController.readerModePage) {
      return PageView.builder(
        controller: _pageCtrl,
        itemCount: _c.pageCount,
        onPageChanged: _onHorizontalPage,
        itemBuilder: (context, i) => _ReaderPage(
          url: _resolve(_c.pageUrls[i]),
          headers: _headers,
          fit: BoxFit.contain,
          // Hidden chrome = true fullscreen; shown chrome keeps the content
          // clear of the overlaid bars.
          padding: _c.chromeVisible
              ? EdgeInsets.fromLTRB(
                  Dimens.spacingSm,
                  topPad,
                  Dimens.spacingSm,
                  bottomPad,
                )
              : EdgeInsets.zero,
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _onVerticalScroll();
        return false;
      },
      child: CustomScrollView(
        key: ValueKey((_c.chapter.id, _verticalAnchor)),
        controller: _scrollCtrl,
        center: _anchorKey,
        slivers: [
          SliverList.builder(
            itemCount: _verticalAnchor,
            itemBuilder: (context, i) =>
                _buildScrollPage(_verticalAnchor - i - 1),
          ),
          SliverPadding(
            key: _anchorKey,
            padding: EdgeInsets.only(top: topPad, bottom: bottomPad),
            sliver: SliverList.builder(
              itemCount: _c.pageCount - _verticalAnchor,
              itemBuilder: (context, i) =>
                  _buildScrollPage(_verticalAnchor + i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollPage(int index) => Padding(
    key: _pageKeys[index],
    padding: const EdgeInsets.only(bottom: Dimens.readerPageGap),
    child: _ReaderPage(
      url: _resolve(_c.pageUrls[index]),
      headers: _headers,
      fit: BoxFit.fitWidth,
      padding: EdgeInsets.zero,
    ),
  );
}

/// Signed page URLs rotate their query string (token/expiry), which would
/// make every refresh a cache miss and pile duplicate entries on disk.
/// Key the cache on the path only — it uniquely identifies the page.
String _stablePageCacheKey(String url) {
  final q = url.indexOf('?');
  return q == -1 ? url : url.substring(0, q);
}

/// Fail-fast stub when Session has no ApiClient.
class _NullComicGateway implements ComicGateway {
  @override
  Future<List<String>> fetchChapterPages(int chapterId) =>
      throw UnsupportedError('not logged in');

  @override
  Future<void> saveReadingProgress(
    int comicId, {
    required int chapterIndex,
    required int pageIndex,
  }) => throw UnsupportedError('not logged in');
}

class _ReaderPage extends StatelessWidget {
  const _ReaderPage({
    required this.url,
    required this.headers,
    required this.fit,
    required this.padding,
  });

  final String url;
  final Map<String, String> headers;
  final BoxFit fit;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: url,
      httpHeaders: headers,
      fit: fit,
      width: double.infinity,
      memCacheWidth: 1600,
      cacheKey: _stablePageCacheKey(url),
      placeholder: (_, _) => const _PagePlaceholder(),
      errorWidget: (_, _, _) => const _PageError(),
    );

    if (padding == EdgeInsets.zero) return image;
    return Padding(padding: padding, child: image);
  }
}

class _PagePlaceholder extends StatelessWidget {
  const _PagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF12141A),
      alignment: Alignment.center,
      constraints: const BoxConstraints(minHeight: 240),
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
      ),
    );
  }
}

class _PageError extends StatelessWidget {
  const _PageError();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF12141A),
      alignment: Alignment.center,
      constraints: const BoxConstraints(minHeight: 200),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: Colors.white38, size: 36),
          SizedBox(height: Dimens.spacingSm),
          Text('页面加载失败', style: TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.form,
    required this.title,
    required this.chapterLabel,
    required this.onBack,
    required this.onToggleMode,
    required this.modeIcon,
    required this.modeTooltip,
    this.onPage,
    this.onChapters,
  });

  final DeviceForm form;
  final String title;
  final String chapterLabel;
  final String? onPage;
  final VoidCallback onBack;
  final VoidCallback? onChapters;
  final VoidCallback onToggleMode;
  final IconData modeIcon;
  final String modeTooltip;

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
                    if (chapterLabel.isNotEmpty)
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
                  tooltip: '章节',
                  icon: const Icon(Icons.list_alt_rounded, color: Colors.white),
                  onPressed: onChapters,
                ),
              IconButton(
                tooltip: modeTooltip,
                icon: Icon(modeIcon, color: Colors.white),
                onPressed: onToggleMode,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatefulWidget {
  const _BottomBar({
    required this.form,
    required this.pageIndex,
    required this.pageCount,
    required this.canPrevChapter,
    required this.canNextChapter,
    required this.onPrevPage,
    required this.onNextPage,
    required this.onPrevChapter,
    required this.onNextChapter,
    required this.onSlider,
  });

  final DeviceForm form;
  final int pageIndex;
  final int pageCount;
  final bool canPrevChapter;
  final bool canNextChapter;
  final VoidCallback onPrevPage;
  final VoidCallback onNextPage;
  final VoidCallback onPrevChapter;
  final VoidCallback onNextChapter;
  final ValueChanged<double> onSlider;

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  double? _dragPage;

  @override
  Widget build(BuildContext context) {
    final form = widget.form;
    final pageCount = widget.pageCount;
    final pageIndex = (_dragPage?.round() ?? widget.pageIndex).clamp(
      0,
      pageCount - 1,
    );
    final canPrevChapter = widget.canPrevChapter;
    final canNextChapter = widget.canNextChapter;
    final onPrevChapter = widget.onPrevChapter;
    final onNextChapter = widget.onNextChapter;
    final onPrevPage = widget.onPrevPage;
    final onNextPage = widget.onNextPage;
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
                    tooltip: '上一话',
                    onPressed: canPrevChapter ? onPrevChapter : null,
                    icon: Icon(
                      Icons.first_page_rounded,
                      color: canPrevChapter ? Colors.white : Colors.white24,
                    ),
                  ),
                  IconButton(
                    tooltip: '上一页',
                    onPressed: pageIndex > 0 ? onPrevPage : null,
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      color: pageIndex > 0 ? Colors.white : Colors.white24,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: pageCount <= 1
                          ? 0
                          : pageIndex.clamp(0, pageCount - 1).toDouble(),
                      min: 0,
                      max: (pageCount - 1).clamp(0, double.infinity).toDouble(),
                      divisions: pageCount <= 1 ? 1 : pageCount - 1,
                      label: '${pageIndex + 1}',
                      onChanged: pageCount <= 1
                          ? null
                          : (v) => setState(() => _dragPage = v),
                      onChangeEnd: pageCount <= 1
                          ? null
                          : (v) {
                              setState(() => _dragPage = null);
                              widget.onSlider(v);
                            },
                    ),
                  ),
                  IconButton(
                    tooltip: '下一页',
                    onPressed: pageIndex + 1 < pageCount ? onNextPage : null,
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      color: pageIndex + 1 < pageCount
                          ? Colors.white
                          : Colors.white24,
                    ),
                  ),
                  IconButton(
                    tooltip: '下一话',
                    onPressed: canNextChapter ? onNextChapter : null,
                    icon: Icon(
                      Icons.last_page_rounded,
                      color: canNextChapter ? Colors.white : Colors.white24,
                    ),
                  ),
                ],
              ),
              Text(
                '${pageIndex + 1} / $pageCount',
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
