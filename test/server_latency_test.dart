import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fryfrog_hub/core/adaptive/device_form.dart';
import 'package:fryfrog_hub/core/network/server_connection.dart';
import 'package:fryfrog_hub/core/state/app_prefs.dart';
import 'package:fryfrog_hub/core/state/session.dart';
import 'package:fryfrog_hub/features/profile/profile_screen.dart';
import 'package:http/http.dart' as http;

/// 「我的-服务器」行右侧的延迟胶囊（对齐 apple ProfileView）：
/// 测 `/api/v1/auth/status` 的 RTT，可见才轮询，不可达显示 `--`。

class _FakeClient extends http.BaseClient {
  int calls = 0;
  bool fail = false;
  Duration delay = Duration.zero;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (fail) throw http.ClientException('boom');
    final body = utf8.encode('{"success":true}');
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable([body]),
      200,
      request: request,
    );
  }
}

ServerConnection _connection(http.Client client, {String? lanHost}) =>
    ServerConnection(probeClient: client)..apply(
      scheme: 'http',
      port: '20058',
      publicHost: 'example.com',
      lanHost: lanHost ?? '',
    );

void main() {
  group('ServerConnection 延迟', () {
    test('measureLatency 记录 RTT（≥1ms），失败返回 null', () async {
      final client = _FakeClient()..delay = const Duration(milliseconds: 40);
      final connection = _connection(client);

      final ms = await connection.measureLatency(ServerConnectionMode.public);
      expect(ms, isNotNull);
      expect(ms, greaterThanOrEqualTo(40));

      client.fail = true;
      expect(
        await connection.measureLatency(ServerConnectionMode.public),
        isNull,
      );
      connection.dispose();
    });

    test('未配置的地址不发请求', () async {
      final client = _FakeClient();
      final connection = _connection(client);

      expect(await connection.measureLatency(ServerConnectionMode.lan), isNull);
      expect(client.calls, 0);
      connection.dispose();
    });

    test('refreshLatencies 并发测已配置地址，变化时通知', () async {
      final client = _FakeClient()..delay = const Duration(milliseconds: 30);
      final connection = _connection(client, lanHost: '192.168.1.2');
      var notifications = 0;
      connection.addListener(() => notifications++);

      await connection.refreshLatencies();

      expect(client.calls, 2, reason: '公网 + 局域网各测一次');
      expect(connection.publicLatencyMs, greaterThanOrEqualTo(30));
      expect(connection.lanLatencyMs, greaterThanOrEqualTo(30));
      expect(connection.latency(ServerConnectionMode.lan), isNotNull);
      expect(notifications, 1);

      // 探测挂掉 → 两个都回落成 null（UI 显示 `--`），并再通知一次。
      client.fail = true;
      await connection.refreshLatencies();
      expect(connection.publicLatencyMs, isNull);
      expect(connection.lanLatencyMs, isNull);
      expect(notifications, 2);
      connection.dispose();
    });
  });

  testWidgets('服务器行右侧显示延迟胶囊，探不通时回退 --', (tester) async {
    final client = _FakeClient()..delay = const Duration(milliseconds: 120);
    final connection = _connection(client);
    final session = Session(connection, AppPrefs());

    await tester.pumpWidget(
      AdaptiveScope(
        form: DeviceForm.phone,
        child: MaterialApp(
          home: Scaffold(body: ProfileScreen(session: session, active: true)),
        ),
      ),
    );
    // initState 立即发起第一轮测量。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining(' ms'), findsOneWidget);
    expect(find.text('--'), findsNothing);

    // 下一轮轮询（3s）时探不通 → 胶囊回退成 `--`。
    client.fail = true;
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('--'), findsOneWidget);
    expect(find.textContaining(' ms'), findsNothing);

    // 卸载页面：停掉轮询计时器（否则测试以 pending timer 失败）。
    await tester.pumpWidget(const SizedBox());
    connection.dispose();
  });

  testWidgets('inactive 的「我的」页不轮询延迟', (tester) async {
    final client = _FakeClient();
    final connection = _connection(client);
    final session = Session(connection, AppPrefs());

    await tester.pumpWidget(
      AdaptiveScope(
        form: DeviceForm.phone,
        child: MaterialApp(
          home: Scaffold(body: ProfileScreen(session: session, active: false)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));

    expect(client.calls, 0, reason: '切到别的 tab 时不该继续打探测请求');
    expect(find.text('--'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    connection.dispose();
  });
}
