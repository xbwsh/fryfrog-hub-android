import 'package:flutter_test/flutter_test.dart';
import 'package:fryfrog_hub/app/app.dart';
import 'package:fryfrog_hub/core/network/server_connection.dart';
import 'package:fryfrog_hub/core/state/app_prefs.dart';
import 'package:fryfrog_hub/core/state/session.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Session makeSession() => Session(ServerConnection(), AppPrefs());

  group('savedLoginDefaults', () {
    test('首启没有保存值：公网地址与用户名留空，端口/协议仍是部署默认', () async {
      SharedPreferences.setMockInitialValues({});

      final d = await makeSession().savedLoginDefaults();

      expect(d.publicHost, '', reason: '不能预填 frostine.top');
      expect(d.username, '', reason: '不能预填 admin');
      expect(d.lanHost, '');
      expect(d.port, '20058');
      expect(d.scheme, 'http');
    });

    test('登录成功后保存的服务器与用户名原样回填', () async {
      SharedPreferences.setMockInitialValues({
        'server.publicHost': 'my.example.com',
        'server.lanHost': '192.168.1.10',
        'server.port': '8443',
        'server.scheme': 'https',
        'auth.username': 'alice',
      });

      final d = await makeSession().savedLoginDefaults();

      expect(d.publicHost, 'my.example.com');
      expect(d.lanHost, '192.168.1.10');
      expect(d.port, '8443');
      expect(d.scheme, 'https');
      expect(d.username, 'alice');
    });
  });

  testWidgets('登录页首启：公网地址与用户名输入框为空，端口预填 20058', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const FryfrogHubApp());
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    // 列顺序：公网 → 局域网 → 端口 → 用户名（密码是 GlassPasswordField）。
    final fields = tester
        .widgetList<GlassTextField>(find.byType(GlassTextField))
        .toList();
    expect(fields.length, greaterThanOrEqualTo(4));
    expect(fields[0].controller?.text, '');
    expect(fields[2].controller?.text, '20058');
    expect(fields[3].controller?.text, '');

    expect(find.text('公网服务器地址'), findsOneWidget);
    expect(find.text('用户名'), findsOneWidget);
    expect(
      find.text('输入账号'),
      findsOneWidget,
      reason: '用户名占位不能再是 admin，那是具体账号不是提示',
    );
    expect(find.text('admin'), findsNothing);
  });
}
