import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// LAN-first server connection model (mirrors apple ServerConnection).
enum ServerConnectionMode { lan, public }

class ServerConnection extends ChangeNotifier {
  ServerConnection({http.Client? probeClient})
    : _probe = probeClient ?? http.Client(),
      _ownsProbe = probeClient == null;

  /// 探测专用 client（可达性 + 延迟）；测试通过参数注入 fake。
  final http.Client _probe;
  final bool _ownsProbe;

  String scheme = 'http';
  String port = '20058';
  String publicHost = '';
  String lanHost = '';
  ServerConnectionMode effectiveMode = ServerConnectionMode.public;

  bool get hasPublic => publicHost.trim().isNotEmpty;
  bool get hasLan => lanHost.trim().isNotEmpty;
  bool get hasAnyAddress => hasPublic || hasLan;

  // ── Latency (mirrors apple ServerConnection) ────────────────────────

  /// 各连接方式最近一次测得的延迟（毫秒）；null = 尚未测量或不可达。
  int? publicLatencyMs;
  int? lanLatencyMs;

  int? latency(ServerConnectionMode mode) =>
      mode == ServerConnectionMode.lan ? lanLatencyMs : publicLatencyMs;

  /// 对指定地址发一次探测请求并测 RTT；不可达返回 null。
  /// 复用 `/api/v1/auth/status`（与 refreshActiveMode 同端点），3s 超时。
  Future<int?> measureLatency(ServerConnectionMode mode) async {
    final base = urlString(mode);
    if (base == null) return null;
    final start = DateTime.now();
    try {
      final res = await _probe
          .get(Uri.parse('$base/api/v1/auth/status'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode != 200) return null;
      // 最少显示 1ms：本机回环四舍五入会得 0，看着像没测。
      return switch (DateTime.now().difference(start).inMilliseconds) {
        <= 0 => 1,
        final ms => ms,
      };
    } catch (_) {
      return null;
    }
  }

  /// 并发测量所有已配置地址的延迟；结果变化时通知监听者。
  Future<void> refreshLatencies() async {
    final modes = ServerConnectionMode.values
        .where((m) => urlString(m) != null)
        .toList(growable: false);
    final results = await Future.wait([
      for (final mode in modes) measureLatency(mode),
    ]);
    var changed = false;
    for (var i = 0; i < modes.length; i++) {
      final ms = results[i];
      if (modes[i] == ServerConnectionMode.lan) {
        changed = changed || lanLatencyMs != ms;
        lanLatencyMs = ms;
      } else {
        changed = changed || publicLatencyMs != ms;
        publicLatencyMs = ms;
      }
    }
    // 值没变就不通知：轮询每 3s 一轮，无谓通知会让整页重建。
    if (changed) notifyListeners();
  }

  String hostOf(ServerConnectionMode mode) =>
      mode == ServerConnectionMode.lan ? lanHost.trim() : publicHost.trim();

  String? urlString(ServerConnectionMode mode) {
    final host = hostOf(mode);
    if (host.isEmpty) return null;
    final normalized = host.contains(':') && !host.startsWith('[')
        ? '[$host]'
        : host;
    return '$scheme://$normalized:$port';
  }

  String? get activeBaseUrl => urlString(effectiveMode);
  String? get alternateBaseUrl => urlString(
    effectiveMode == ServerConnectionMode.lan
        ? ServerConnectionMode.public
        : ServerConnectionMode.lan,
  );

  void apply({
    required String scheme,
    required String port,
    required String publicHost,
    String lanHost = '',
  }) {
    this.scheme = scheme;
    this.port = port;
    this.publicHost = publicHost;
    this.lanHost = lanHost;
    // 不再在这里写死 lan 优先：由 refreshActiveMode() 探测决定，
    // 避免 LAN 不可达时永远连不上、也不回退公网。
    notifyListeners();
  }

  /// Relative API paths (e.g. `/api/v1/video/2/cover`) resolve against base.
  Uri? imageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    final base = activeBaseUrl;
    if (base == null) return null;
    if (path.startsWith('http')) return Uri.tryParse(path);
    return Uri.tryParse('$base${path.startsWith('/') ? '' : '/'}$path');
  }

  void setMode(ServerConnectionMode mode) {
    if (effectiveMode == mode) return;
    effectiveMode = mode;
    notifyListeners();
  }

  Future<bool> _probeOk(String base) async {
    try {
      final res = await _probe
          .get(Uri.parse('$base/api/v1/auth/status'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// LAN 可达则走 LAN，否则退回公网（对齐 iOS refreshActiveMode）。
  /// 未配置 LAN 时直接走公网。
  Future<void> refreshActiveMode() async {
    if (!hasLan) {
      if (effectiveMode != ServerConnectionMode.public) {
        setMode(ServerConnectionMode.public);
      }
      return;
    }
    final lan = urlString(ServerConnectionMode.lan);
    final lanOk = lan != null && await _probeOk(lan);
    setMode(lanOk ? ServerConnectionMode.lan : ServerConnectionMode.public);
  }

  @override
  void dispose() {
    if (_ownsProbe) _probe.close();
    super.dispose();
  }
}
