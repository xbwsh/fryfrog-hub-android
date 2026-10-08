import 'dart:convert';

/// 已保存的服务器档案 —— 登录成功后自动记一笔，登录页用它快速切换服务器。
///
/// **不存密码**：切服务器仍要重新输入密码（明文落盘的凭据不可吊销，
/// 比 token 风险高）。这里只记地址与该地址上次登录成功的账号。
class ServerProfile {
  const ServerProfile({
    required this.publicHost,
    required this.lanHost,
    required this.port,
    required this.scheme,
    required this.username,
  });

  factory ServerProfile.fromJson(Map<String, dynamic> json) => ServerProfile(
    publicHost: json['publicHost'] as String? ?? '',
    lanHost: json['lanHost'] as String? ?? '',
    port: (json['port'] as String?) ?? '20058',
    scheme: (json['scheme'] as String?) ?? 'http',
    username: json['username'] as String? ?? '',
  );

  final String publicHost;
  final String lanHost;
  final String port;
  final String scheme;
  final String username;

  /// 档案身份：同协议/地址/端口即同一服务器（账号可被后续登录覆盖）。
  /// 大小写与两端空白不参与区分，避免同一台服务器因写法不同重复堆条目。
  String get key {
    final pub = publicHost.trim().toLowerCase();
    final lan = lanHost.trim().toLowerCase();
    return '$scheme|$pub|$lan|${port.trim()}';
  }

  /// chip 上显示的地址；没填公网地址时退回局域网地址。
  String get label {
    final host = publicHost.trim().isNotEmpty
        ? publicHost.trim()
        : lanHost.trim();
    return '$host:${port.trim()}';
  }

  /// 保存前规整：去空白 + 主机名小写。
  /// 否则用户先后输入 `A.Example.com` 与 `a.example.com` 会得到两条
  /// key 相同、label 不同的档案，去重了却展示成两台服务器。
  ServerProfile normalized() => ServerProfile(
    publicHost: publicHost.trim().toLowerCase(),
    lanHost: lanHost.trim().toLowerCase(),
    port: port.trim(),
    scheme: scheme,
    username: username.trim(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'publicHost': publicHost,
    'lanHost': lanHost,
    'port': port,
    'scheme': scheme,
    'username': username,
  };

  /// 解析存档列表。**单条损坏直接丢弃**，不让一处脏数据毁掉整个列表
  /// （整份解析失败时退回空列表，同样不能把登录页卡死）。
  static List<ServerProfile> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final out = <ServerProfile>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        try {
          out.add(ServerProfile.fromJson(item));
        } catch (_) {
          // 跳过坏条目
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static String encodeList(List<ServerProfile> list) =>
      jsonEncode(list.map((p) => p.toJson()).toList(growable: false));
}
