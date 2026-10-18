import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fryfrog_hub/core/rules/video_decode_rules.dart';
import 'package:fryfrog_hub/core/state/app_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('video decoder preference', () {
    test('loads and persists even when the theme has never been saved', () async {
      SharedPreferences.setMockInitialValues({
        'prefs.videoDecodeMode': 'software',
      });

      final prefs = AppPrefs();
      await prefs.load();
      expect(prefs.videoDecodeMode, VideoDecodeMode.software);

      await prefs.setVideoDecodeMode(VideoDecodeMode.hardware);
      final restored = AppPrefs();
      await restored.load();
      expect(restored.videoDecodeMode, VideoDecodeMode.hardware);
    });

    test('missing or invalid values use automatic mode', () async {
      SharedPreferences.setMockInitialValues({});
      final missing = AppPrefs();
      await missing.load();
      expect(missing.videoDecodeMode, VideoDecodeMode.automatic);

      SharedPreferences.setMockInitialValues({
        'prefs.videoDecodeMode': 'removed-option',
      });
      final invalid = AppPrefs();
      await invalid.load();
      expect(invalid.videoDecodeMode, VideoDecodeMode.automatic);
    });
  });

  group('video decoder policy', () {
    test('automatic prefers platform defaults, software disables hwdec', () {
      expect(
        videoHwdecForMode(VideoDecodeMode.automatic),
        'auto-safe',
      );
      expect(videoHwdecForMode(VideoDecodeMode.software), 'no');
      expect(videoHwdecForMode(VideoDecodeMode.hardware), 'auto-safe');
    });

    test('only one video codec error can request automatic software retry', () {
      final recovery = VideoDecodeRecovery(VideoDecodeMode.automatic);
      expect(
        recovery.acceptVideoLog(
          prefix: 'vd',
          level: 'error',
          text: 'mpeg2_mediacodec: Both surface and native_window are NULL',
        ),
        isTrue,
      );
      expect(
        recovery.acceptVideoLog(
          prefix: 'vd',
          level: 'error',
          text: 'Could not open codec',
        ),
        isFalse,
      );
    });

    test('ignores audio, transport, and non-error logs', () {
      final recovery = VideoDecodeRecovery(VideoDecodeMode.automatic);
      for (final log in [
        ('ad', 'error', 'Could not open codec'),
        ('stream', 'error', 'Could not open codec'),
        ('vd', 'warn', 'Could not open codec'),
      ]) {
        expect(
          recovery.acceptVideoLog(
            prefix: log.$1,
            level: log.$2,
            text: log.$3,
          ),
          isFalse,
        );
      }
    });

    test('soft and hard modes never request app fallback', () {
      for (final mode in [
        VideoDecodeMode.software,
        VideoDecodeMode.hardware,
      ]) {
        final recovery = VideoDecodeRecovery(mode);
        expect(
          recovery.acceptVideoLog(
            prefix: 'vd',
            level: 'error',
            text: 'Could not open codec',
          ),
          isFalse,
        );
      }
    });

    test('failed first-frame position does not replace the requested resume point', () {
      expect(
        videoFallbackResumeAt(
          requestedStartSeconds: 1800,
          currentPositionSeconds: 0.4,
          hasRenderedFrame: false,
        ),
        1800,
      );
      expect(
        videoFallbackResumeAt(
          requestedStartSeconds: 1800,
          currentPositionSeconds: 42.4,
          hasRenderedFrame: true,
        ),
        42.4,
      );
    });

    test('debug decoder logs retain reason while redacting signed URLs and tokens', () {
      final safe = redactMpvLogText(
        'Could not open codec https://host/media?exp=1&sig=secret '
        'Authorization: Bearer private-token',
      );
      expect(safe, contains('Could not open codec'));
      expect(safe, isNot(contains('secret')));
      expect(safe, isNot(contains('private-token')));
      expect(safe, isNot(contains(r'$1')));
    });
  });
}
