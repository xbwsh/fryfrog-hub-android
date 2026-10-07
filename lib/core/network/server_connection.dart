import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// LAN-first server connection model (mirrors apple ServerConnection).
enum ServerConnectionMode { lan, public }

class ServerConnection extends ChangeNotifier {
  ServerConnection();

  String scheme = 'http';
  String port = '20058';
  String publicHost = '';
  String lanHost = '';
  ServerConnectionMode effectiveMode = ServerConnectionMode.public;

  bool get hasPublic => publicHost.trim().isNotEmpty;
  bool get hasLan => lanHost.trim().isNotEmpty;
  bool get hasAnyAddress => hasPublic || hasLan;

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
      final res = await http
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
}
