import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fryfrog_hub/app/app.dart';
import 'package:fryfrog_hub/core/models/server_profile.dart';
import 'package:fryfrog_hub/core/network/server_connection.dart';
import 'package:fryfrog_hub/core/state/app_prefs.dart';
import 'package:fryfrog_hub/core/state/session.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ServerProfile make({
    String publicHost = 'a.example.com',
    String lanHost = '',
    String port = '20058',
    String scheme = 'http',
    String username = 'alice',
  }) => ServerProfile(
    publicHost: publicHost,
    lanHost: lanHost,
    port: port,
    scheme: scheme,
    username: username,
  );

  Session makeSession() => Session(ServerConnection(), AppPrefs());

  group('ServerProfile', () {
    test('json 往返不丢字段', () {
      final p = make(lanHost: '192.168.1.10', port: '8443', scheme: 'https');
      final back = ServerProfile.fromJson(p.toJson());

      expect(back.publicHost, p.publicHost);
      expect(back.lanHost, p.lanHost);
      expect(back.port, p.port);
      expect(back.scheme, p.scheme);
      expect(back.username, p.username);
    });

    test('key 忽略大小写与空白，但区分协议/地址/端口；账号不参与', () {
      expect(
        make(publicHost: 'A.Example.com').key,
        make(publicHost: 'a.example.com').key,
      );
      expect(
        make(publicHost: ' a.example.com ').key,
        make(publicHost: 'a.example.com').key,
      );
      expect(make(scheme: 'https').key, isNot(make(scheme: 'http').key));
      expect(make(port: '8443').key, isNot(make(port: '20058').key));
      expect(make(username: 'bob').key, make(username: 'alice').key);
    });

    test('label 公网优先，没公网时退回局域网', () {
      expect(make(publicHost: 'a.example.com').label, 'a.example.com:20058');
      expect(
        make(publicHost: '', lanHost: '192.168.1.10').label,
        '192.168.1.10:20058',
      );
    });

    test('normalized 去空白并小写主机名', () {
      final p = make(
        publicHost: ' A.EXAMPLE.COM ',
        lanHost: ' 192.168.1.10 ',
        port: ' 8443 ',
        username: ' alice ',
      ).normalized();

      expect(p.publicHost, 'a.example.com');
      expect(p.lanHost, '192.168.1.10');
      expect(p.port, '8443');
      expect(p.username, 'alice');
    });

    test('decodeList 丢弃坏条目，整串损坏退回空列表', () {
      expect(ServerProfile.decodeList(null), isEmpty);
      expect(ServerProfile.decodeList('not json'), isEmpty);
      expect(ServerProfile.decodeList('{"a":1}'), isEmpty);
      expect(
        ServerProfile.decodeList('[{"port":"20058"}, "junk", {"port":123}]'),
        hasLength(1),
      );
    });
  });

  group('Session 档案存取', () {
    test('首次记住一条并可读回', () async {
      SharedPreferences.setMockInitialValues({});
      final s = makeSession();

      await s.rememberServer(
        publicHost: 'a.example.com',
        lanHost: '',
        port: '20058',
        scheme: 'http',
        username: 'alice',
      );

      final list = await s.listProfiles();
      expect(list, hasLength(1));
      expect(list.first.username, 'alice');
      expect(list.first.label, 'a.example.com:20058');
    });

    test('同地址只覆盖账号并提到最前，不产生重复条目', () async {
      SharedPreferences.setMockInitialValues({});
      final s = makeSession();
      await s.rememberServer(
        publicHost: 'a.example.com',
        lanHost: '',
        port: '20058',
        scheme: 'http',
        username: 'alice',
      );
      await s.rememberServer(
        publicHost: 'b.example.com',
        lanHost: '',
        port: '20058',
        scheme: 'http',
        username: 'bob',
      );
      await s.rememberServer(
        publicHost: 'A.EXAMPLE.COM ',
        lanHost: '',
        port: '20058',
        scheme: 'http',
        username: 'alice2',
      );

      final list = await s.listProfiles();
      expect(list, hasLength(2), reason: '同地址不该长出第三条');
      expect(list.first.label, 'a.example.com:20058');
      expect(
        list.first.publicHost,
        'a.example.com',
        reason: '保存前规整大小写，否则同一条档案 label 会变样',
      );
      expect(list.first.username, 'alice2', reason: '登录成功后账号被覆盖');
      expect(list.last.username, 'bob');
    });

    test('上限截断：只留最近的若干条', () async {
      SharedPreferences.setMockInitialValues({});
      final s = makeSession();
      for (var i = 0; i < 15; i++) {
        await s.rememberServer(
          publicHost: 'host$i.example.com',
          lanHost: '',
          port: '20058',
          scheme: 'http',
          username: 'u$i',
        );
      }

      final list = await s.listProfiles();
      expect(list, hasLength(12));
      expect(list.first.label, 'host14.example.com:20058', reason: '最新登录排最前');
      expect(list.last.label, 'host3.example.com:20058');
    });

    test('损坏的存档不会让 rememberServer 抛异常', () async {
      SharedPreferences.setMockInitialValues({'server.profiles': '{{{'});
      final s = makeSession();

      await expectLater(
        s.rememberServer(
          publicHost: 'a.example.com',
          lanHost: '',
          port: '20058',
          scheme: 'http',
          username: 'alice',
        ),
        completes,
      );
      expect(await s.listProfiles(), hasLength(1));
    });
  });

  testWidgets('登录页：点 chip 用整条档案回填表单', (tester) async {
    final profiles = [
      make(publicHost: 'a.example.com', username: 'alice'),
      make(
        publicHost: 'b.example.com',
        port: '8443',
        scheme: 'https',
        username: 'bob',
      ),
    ];
    SharedPreferences.setMockInitialValues({
      'server.profiles': ServerProfile.encodeList(profiles),
    });

    await tester.pumpWidget(const FryfrogHubApp());
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('已保存服务器'), findsOneWidget);
    expect(find.text('a.example.com:20058'), findsOneWidget);
    expect(find.text('b.example.com:8443'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'b.example.com:8443'));
    await tester.pump(const Duration(milliseconds: 100));

    // 列顺序：公网 → 局域网 → 端口 → 用户名。
    final fields = tester
        .widgetList<GlassTextField>(find.byType(GlassTextField))
        .toList();
    expect(fields[0].controller?.text, 'b.example.com');
    expect(fields[2].controller?.text, '8443');
    expect(fields[3].controller?.text, 'bob');
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'b.example.com:8443'),
          )
          .selected,
      isTrue,
      reason: '被选中的 chip 要高亮',
    );
  });
}
