import 'package:flutter_test/flutter_test.dart';
import 'package:fryfrog_hub/core/rules/seek_rules.dart';

void main() {
  group('SeekRules.readyToDecide', () {
    test('攒够 slop 之前不动进度也不动亮度音量', () {
      expect(SeekRules.readyToDecide(0, 0), isFalse);
      expect(SeekRules.readyToDecide(4, 3), isFalse); // 7px，未到 8
      expect(SeekRules.readyToDecide(8, 0), isTrue);
      expect(SeekRules.readyToDecide(-8, 0), isTrue);
      expect(SeekRules.readyToDecide(3, 5), isTrue);
    });
  });

  group('SeekRules.isHorizontal', () {
    test('横移更大 → 快进；竖移更大 → 亮度/音量', () {
      expect(SeekRules.isHorizontal(30, 4), isTrue);
      expect(SeekRules.isHorizontal(-42, 9), isTrue);
      expect(SeekRules.isHorizontal(4, 30), isFalse);
      expect(SeekRules.isHorizontal(5, 5), isTrue); // 打平归横滑
    });
  });

  group('SeekRules.preview', () {
    const duration = Duration(minutes: 44, seconds: 30);

    test('精细段 0.1s/px + 整秒量化：退几秒指哪打哪', () {
      // 10px → 1.0s → 1 秒
      expect(
        SeekRules.preview(
          start: Duration.zero,
          duration: duration,
          deltaPx: 10,
        ),
        const Duration(seconds: 1),
      );
      // 从 3:00 退 10px → 精确 -1 秒
      expect(
        SeekRules.preview(
          start: const Duration(minutes: 3),
          duration: duration,
          deltaPx: -10,
        ),
        const Duration(minutes: 2, seconds: 59),
      );
      // 30px → 3 秒
      expect(
        SeekRules.preview(
          start: Duration.zero,
          duration: duration,
          deltaPx: 30,
        ),
        const Duration(seconds: 3),
      );
    });

    test('亚秒位移按秒量化到 1 秒内', () {
      // 4px → 0.4s → round 到 0 秒？0.4.round()=0 → 0s
      expect(
        SeekRules.preview(
          start: Duration.zero,
          duration: duration,
          deltaPx: 4,
        ),
        Duration.zero,
      );
      // 6px → 0.6s → 1 秒
      expect(
        SeekRules.preview(
          start: Duration.zero,
          duration: duration,
          deltaPx: 6,
        ),
        const Duration(seconds: 1),
      );
    });

    test('加速段：超过 150px 后 0.75s/px', () {
      // 150px 精细段 = 15s；再 +100px 加速段 = 75s；合计 90s
      expect(
        SeekRules.preview(
          start: Duration.zero,
          duration: duration,
          deltaPx: 250,
        ),
        const Duration(seconds: 90),
      );
      // 整屏 ~400px：150*0.1 + 250*0.75 = 15 + 187.5 = 202.5 → 203s
      //（Dart .round() 半数远离零）
      expect(
        SeekRules.preview(
          start: Duration.zero,
          duration: duration,
          deltaPx: 400,
        ),
        const Duration(seconds: 203),
      );
    });

    test('越界 clamp 到 [0, 时长]', () {
      expect(
        SeekRules.preview(
          start: Duration.zero,
          duration: duration,
          deltaPx: -9999,
        ),
        Duration.zero,
      );
      expect(
        SeekRules.preview(
          start: duration,
          duration: duration,
          deltaPx: 9999,
        ),
        duration,
      );
    });

    test('从当前位置起步累加，不是重置到 0', () {
      const start = Duration(minutes: 20);
      final moved = SeekRules.preview(
        start: start,
        duration: duration,
        deltaPx: -20,
      );
      expect(moved, const Duration(minutes: 19, seconds: 58));
    });

    test('时长未知时退回起点，不产生跳转', () {
      expect(
        SeekRules.preview(
          start: const Duration(minutes: 3),
          duration: Duration.zero,
          deltaPx: 100,
        ),
        const Duration(minutes: 3),
      );
    });
  });
}
