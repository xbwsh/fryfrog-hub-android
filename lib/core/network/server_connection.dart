import 'package:flutter/foundation.dart';

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
    effectiveMode = hasLan ? ServerConnectionMode.lan : ServerConnectionMode.public;
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
}
