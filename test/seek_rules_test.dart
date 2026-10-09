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
    const width = 400.0;
    const duration = Duration(minutes: 44, seconds: 30); // 2670000ms

    test('整屏宽右滑走完整集，左滑回到开头', () {
      expect(
        SeekRules.preview(
          start: Duration.zero,
          duration: duration,
          deltaPx: width,
          width: width,
        ),
        duration,
      );
      expect(
        SeekRules.preview(
          start: duration,
          duration: duration,
          deltaPx: -width,
          width: width,
        ),
          Duration.zero,
      );
    });

    test('半屏宽 = 半集时长（从起点算）', () {
      final half = SeekRules.preview(
        start: Duration.zero,
        duration: duration,
        deltaPx: width / 2,
        width: width,
      );
      expect(half.inMilliseconds, duration.inMilliseconds ~/ 2);
    });

    test('越界 clamp 到 [0, 时长]', () {
      expect(
        SeekRules.preview(
          start: Duration.zero,
          duration: duration,
          deltaPx: width * 3,
          width: width,
        ),
        duration,
      );
      expect(
        SeekRules.preview(
          start: duration,
          duration: duration,
          deltaPx: -width * 2,
          width: width,
        ),
        Duration.zero,
      );
    });

    test('从当前位置起步累加，不是重置到 0', () {
      const start = Duration(minutes: 20);
      final moved = SeekRules.preview(
        start: start,
        duration: duration,
        deltaPx: -width / 4,
        width: width,
      );
      expect(
        moved.inMilliseconds,
        start.inMilliseconds - duration.inMilliseconds ~/ 4,
      );
    });

    test('时长/屏宽未知时退回起点，不产生跳转', () {
      expect(
        SeekRules.preview(
          start: Duration(minutes: 3),
          duration: Duration.zero,
          deltaPx: 100,
          width: width,
        ),
        const Duration(minutes: 3),
      );
      expect(
        SeekRules.preview(
          start: Duration(minutes: 3),
          duration: duration,
          deltaPx: 100,
          width: 0,
        ),
        const Duration(minutes: 3),
      );
    });
  });
}
