import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/adaptive/device_form.dart';
import '../../core/models/video.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import 'library_poster_grid.dart';

/// 库内搜索：单库范围、服务端模糊匹配，结果复用库详情的海报网格。
///
/// 输入防抖 300ms 后请求，竞态保护（只采纳最后一次请求的结果），
/// 命中语义与库视图一致：剧按剧名返回剧卡，片按片名返回片卡。
class InLibrarySearchScreen extends StatefulWidget {
  const InLibrarySearchScreen({
    super.key,
    required this.session,
    required this.libraryId,
    required this.libraryName,
  });

  final Session session;
  final int libraryId;
  final String libraryName;

  @override
  State<InLibrarySearchScreen> createState() => _InLibrarySearchScreenState();
}

class _InLibrarySearchScreenState extends State<InLibrarySearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  LibrarySeriesGroup? _result;
  String? _error;
  bool _loading = false;
  int _requestSeq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.session.api;
    if (app == null) {
      // 进入页面总是先有 Session，理论上不会走到这里；仍兜底避免崩溃。
      return const Scaffold(body: Center(child: Text('服务未连接')));
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: '搜索 ${widget.libraryName}',
            border: InputBorder.none,
          ),
          style: TextStyle(fontSize: 17 * AdaptiveScope.of(context).typeScale),
          onChanged: _onQueryChanged,
          onSubmitted: (_) => _runSearch(_controller.text.trim()),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Dimens.spacingSm),
            child: IconButton(
              tooltip: '清空',
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _controller.clear();
                _onQueryChanged('');
              },
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  void _onQueryChanged(String raw) {
    final q = raw.trim();
    if (q == _query) return;
    _query = q;
    _debounce?.cancel();
    if (q.isEmpty) {
      setState(() {
        _result = null;
        _error = null;
        _loading = false;
        _requestSeq++; // 作废在途请求
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _runSearch(q),
    );
  }

  Future<void> _runSearch(String q) async {
    final app = widget.session.api;
    if (app == null) return;
    final seq = ++_requestSeq;
    try {
      final result = await app.searchInLibrary(
        libraryId: widget.libraryId,
        q: q,
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _result = result;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _result = null;
        _loading = false;
        _error = '搜索失败，请稍后重试';
      });
    }
  }

  Widget _buildBody() {
    final form = AdaptiveScope.of(context);
    if (_query.isEmpty) {
      return _hint(form, '输入关键词搜索「${widget.libraryName}」库内容');
    }
    if (_error != null) {
      return _hint(form, _error!);
    }
    final result = _result;
    if (result == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_loading && result.allItems.isEmpty) {
      return _hint(form, '未找到“$_query”相关内容');
    }
    return LibraryPosterGrid(
      items: result.allItems,
      portrait: true,
      form: form,
      session: widget.session,
      // 搜索结果是服务端一次性返回的快照，不在 session 里；详情页改完数据
      // 卡片会 loadCatalog，但本页这份结果只能自己重查。
      onChanged: () {
        if (_query.isNotEmpty) _runSearch(_query);
      },
    );
  }

  Widget _hint(DeviceForm form, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Dimens.spacingXl),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15 * form.typeScale,
            color: Theme.of(context).hintColor,
          ),
        ),
      ),
    );
  }
}
