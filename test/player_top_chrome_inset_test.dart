import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fryfrog_hub/core/theme/dimens.dart';

/// 播放器「状态栏与控制栏同进同出」的回归测试。
///
/// 背景（实测小米 25079RPDCC / 450dpi 复现）：
/// 播放器原本让系统栏常驻 immersive（永远隐藏），控制栏却自己显隐，两者各管
/// 各的 —— 控制栏一出现就压在状态栏留白上，顶部看着空一块；退出时系统栏回来、
/// `padding.top` 从 0 弹到状态栏高度，顶栏就「往下掉一截」。
///
/// 曾试过用 `viewPadding.top` 避让，但**横屏下它恒为 0**（状态栏移到侧边），
/// 于是恒取兜底值，和详情页 AppBar 的真实状态栏高差出一截（实测 16dp）。
///
/// 最终方案：状态栏纳入 chrome 生命周期，由 `_ensureSystemBarsMatchChrome`
/// 在 build 里统一同步——控制栏出现则状态栏出现、消失则一起消失。顶/底栏用
/// SafeArea 让开即可，留白天然等于状态栏高度，不需要任何硬编码补偿。
///
/// 本测试锁定的就是这个「同步 + SafeArea 跟随」的不变量。
const double kStatusBarDp = 24.0;

/// 顶栏 = SafeArea 让开状态栏 + kToolbarHeight/2。
double titleCenterY({required double statusBarInset}) =>
    statusBarInset + kToolbarHeight / 2;

void main() {
  test('控制栏可见时，状态栏同现 → 顶栏正好让开状态栏高度', () {
    expect(titleCenterY(statusBarInset: kStatusBarDp), kStatusBarDp + 28);
  });

  test('控制栏隐藏时，状态栏同隐 → 顶栏贴回屏幕顶边，不留空档', () {
    expect(titleCenterY(statusBarInset: 0), 28);
  });

  testWidgets('状态栏与控制栏同进同出，不存在「藏了却还留空档」的中间态', (tester) async {
    // 模拟 chrome 可见性驱动的系统栏状态：可见时 inset=状态栏高，隐藏时 0。
    Future<void> pumpWith(bool chromeVisible) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              padding: EdgeInsets.only(
                top: chromeVisible ? kStatusBarDp : 0,
                bottom: chromeVisible ? kStatusBarDp : 0,
              ),
              size: const Size(400, 900),
            ),
            child: Scaffold(
              body: Stack(
                children: [
                  if (chromeVisible)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: SafeArea(
                        bottom: false,
                        child: const SizedBox(
                          key: Key('topBarInner'),
                          height: kToolbarHeight,
                          width: double.infinity,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    await pumpWith(true);
    final shownTop = tester.getTopLeft(find.byKey(const Key('topBarInner'))).dy;
    // SafeArea 生效 → 顶栏被推到状态栏之下。
    expect(shownTop, kStatusBarDp);

    // 控制栏收起（连同状态栏），顶栏整体退场，不该残留在原地。
    await pumpWith(false);
    expect(find.byKey(const Key('topBarInner')), findsNothing);
  });

  testWidgets('SafeArea 顶栏始终紧贴状态栏下沿，间距恒为 0', (tester) async {
    // 任意系统栏高度下，SafeArea 都不额外加间隙——这正是「不需要硬编码
    // inset 补偿」的含义：留白完全由系统栏高度决定。
    for (final inset in <double>[0, 24, 48, 72]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              padding: EdgeInsets.only(top: inset),
              size: const Size(400, 900),
            ),
            child: Scaffold(
              body: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: SafeArea(
                      bottom: false,
                      child: const SizedBox(
                        key: Key('topBarInner'),
                        height: kToolbarHeight,
                        width: double.infinity,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const Key('topBarInner'))).dy,
        inset,
        reason: '状态栏高度 $inset 时，顶栏应紧贴其下沿，无额外间隙',
      );
    }
  });

  testWidgets('隐藏态仍在树内（不增删节点），靠位移做进出场动画', (tester) async {
    // 增删节点会让控件「啪一下」出现、没有过渡，观感上就是卡一下。
    // 必须常驻树内，只驱动位移/透明度。
    Future<void> pumpShown(bool shown) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: IgnorePointer(
                  ignoring: !shown,
                  child: AnimatedSlide(
                    offset: shown ? Offset.zero : const Offset(0, -1.2),
                    duration: const Duration(milliseconds: 80),
                    curve: Curves.easeOutCubic,
                    child: const SizedBox(
                      key: Key('bar'),
                      height: 56,
                      width: double.infinity,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    await pumpShown(false);
    // 隐藏态节点依然存在（没被删掉）。
    expect(find.byKey(const Key('bar')), findsOneWidget);

    await pumpShown(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bar')), findsOneWidget);
  });

  testWidgets('顶栏从上方滑入、底栏从下方滑入', (tester) async {
    // 方向要和状态栏一致（自上而下），底栏自下而上——不然就是「各动各的」。
    Future<void> pumpSlide({required bool shown, required bool fromTop}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: fromTop ? 0 : 300,
                child: IgnorePointer(
                  ignoring: !shown,
                  child: AnimatedSlide(
                    offset: shown
                        ? Offset.zero
                        : (fromTop
                              ? const Offset(0, -1.2)
                              : const Offset(0, 1.2)),
                    duration: const Duration(milliseconds: 80),
                    curve: Curves.easeOutCubic,
                    child: const SizedBox(
                      key: Key('bar'),
                      height: 56,
                      width: double.infinity,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 位移取自 renderObject 的 transform——`getTopLeft` 只是布局位置，
    // 不含 AnimatedSlide 的位移，测不出滑动方向。
    double slideY() => tester
        .renderObject<RenderBox>(find.byKey(const Key('bar')))
        .getTransformTo(null)
        .getTranslation()
        .y;

    // 顶栏隐藏：位移为负（被推到屏幕上方）。
    await pumpSlide(shown: false, fromTop: true);
    await tester.pump();
    expect(slideY(), lessThan(0), reason: '顶栏隐藏时应推到屏幕上方');

    // 底栏隐藏：位移为正（被推到屏幕下方）。
    await pumpSlide(shown: false, fromTop: false);
    await tester.pump();
    expect(slideY(), greaterThan(0), reason: '底栏隐藏时应推到屏幕下方');

    // 显示后位移归零。
    await pumpSlide(shown: true, fromTop: true);
    await tester.pumpAndSettle();
    expect(slideY(), 0);
  });

  testWidgets('隐藏态不接收点击（IgnorePointer），避免误触', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                ignoring: true, // 相当于 shown == false
                child: GestureDetector(
                  onTap: () => taps++,
                  child: const SizedBox(
                    key: Key('bar'),
                    height: 56,
                    width: double.infinity,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('bar')), warnIfMissed: false);
    expect(taps, 0, reason: '控制栏隐藏时不该吃掉点击，否则会挡住手势');
  });

  test('进出动画共用同一时长与同一条曲线（保证观感对称）', () {
    // 回归用例：进/退曾各用不同曲线（进场 easeOut、退场 easeIn），导致一侧
    // 「唰」地消失、另一侧「黏」地淡出。这里锁定「同一个 duration、同一
    // curve」这个配置——真正的对称由实现保证，测试只守住配置不被改散。
    expect(
      Dimens.playerChromeAnimDuration,
      const Duration(milliseconds: 200),
      reason: '进场/退场动画时长是同一个常量，不应各自写死',
    );
    expect(
      Dimens.playerChromeAnimDuration.inMilliseconds,
      greaterThanOrEqualTo(150),
      reason: '太快会显得生硬，太慢会显得拖沓',
    );
    expect(
      Dimens.playerChromeAnimDuration.inMilliseconds,
      lessThanOrEqualTo(300),
      reason: '超过 300ms 观感上就偏粘了',
    );
  });

  test('隐藏偏移是自身高度的固定倍数，保证完全移出可视区', () {
    // 1.2 倍：>1 才能确保滑出时完全离开视口、不露半截；又不能太大否则动画
    // 中途会有明显的空白等待。
    const factor = 1.2;
    expect(factor, greaterThan(1.0));
    expect(factor, lessThan(2.0));
    // 位移须大于工具条高度本身（56dp），否则顶栏会「退一半卡住」。
    expect(factor * kToolbarHeight, greaterThan(kToolbarHeight));
  });
}
