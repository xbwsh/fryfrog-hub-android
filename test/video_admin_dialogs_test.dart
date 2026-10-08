import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fryfrog_hub/features/video/video_admin_dialogs.dart';

void main() {
  late BuildContext hostContext;

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            hostContext = context;
            return const Scaffold(body: Text('host-screen'));
          },
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('成功时关闭进度框，宿主页保留', (tester) async {
    await pumpHost(tester);
    final work = Completer<void>();
    final future = runWithProgress<void>(hostContext, '处理中', () => work.future);
    await tester.pump();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('host-screen'), findsOneWidget);

    work.complete();
    await future;
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.text('host-screen'), findsOneWidget);
  });

  testWidgets('work 抛错时仍关闭进度框并向上抛', (tester) async {
    await pumpHost(tester);
    final work = Completer<void>();
    final future = runWithProgress<void>(hostContext, '处理中', () => work.future);
    await tester.pump();
    expect(find.byType(Dialog), findsOneWidget);

    work.completeError(StateError('boom'));
    await expectLater(future, throwsA(isA<StateError>()));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.text('host-screen'), findsOneWidget);
  });

  // 回归：barrierDismissible: false 拦不住系统返回键。用户在 work 进行中按返回
  // 关掉进度框后，旧实现的 finally 仍然无条件 nav.pop() —— 把宿主页一起弹掉。
  testWidgets('系统返回关掉进度框后，finally 不再弹掉宿主页', (tester) async {
    await pumpHost(tester);
    final work = Completer<void>();
    final future = runWithProgress<void>(hostContext, '处理中', () => work.future);
    await tester.pump();
    expect(find.byType(Dialog), findsOneWidget);

    // 系统返回键
    await WidgetsBinding.instance.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('host-screen'), findsOneWidget);

    work.complete();
    await future;
    await tester.pumpAndSettle();

    expect(
      find.text('host-screen'),
      findsOneWidget,
      reason: 'work 结束后不应把宿主页 pop 掉，只应关掉自己的进度框',
    );
  });

  testWidgets('进度框被外部移除时，finally 不误弹宿主页', (tester) async {
    await pumpHost(tester);
    final work = Completer<void>();
    final future = runWithProgress<void>(hostContext, '处理中', () => work.future);
    await tester.pump();
    expect(find.byType(Dialog), findsOneWidget);

    // 进度框被外部直接移除（非 pop），所以 PopScope 不会把 dismissed 置位。
    final dialogRoute = ModalRoute.of(tester.element(find.byType(Dialog)))!;
    Navigator.of(hostContext, rootNavigator: true).removeRoute(dialogRoute);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);

    work.complete();
    await expectLater(future, completes);
    await tester.pumpAndSettle();

    expect(find.text('host-screen'), findsOneWidget);
  });
}
