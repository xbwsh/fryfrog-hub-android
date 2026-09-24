import 'package:flutter_test/flutter_test.dart';
import 'package:fryfrog_hub/app/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots into login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const FryfrogHubApp());
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Fryfrog Hub'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('登录'), findsOneWidget);
  });
}
