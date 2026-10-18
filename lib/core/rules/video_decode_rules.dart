import '../state/app_prefs.dart';

/// Native mpv decoder selection for the user's persisted video preference.
String videoHwdecForMode(VideoDecodeMode mode) {
  return switch (mode) {
    VideoDecodeMode.automatic => 'auto-safe',
    VideoDecodeMode.software => 'no',
    // Let mpv select the platform's supported API. The player verifies
    // hwdec-current after a frame is rendered and errors if it used software.
    VideoDecodeMode.hardware => 'auto-safe',
  };
}

double videoFallbackResumeAt({
  required double requestedStartSeconds,
  required double currentPositionSeconds,
  required bool hasRenderedFrame,
}) =>
    hasRenderedFrame && currentPositionSeconds > 0
    ? currentPositionSeconds
    : requestedStartSeconds;

/// Keeps useful decoder diagnostics while excluding URLs and credentials.
String redactMpvLogText(String text) => text
    .replaceAll(RegExp(r'https?://[^\s]+'), '[url redacted]')
    .replaceAll(
      RegExp(r'authorization:\s*bearer\s+[^\s]+', caseSensitive: false),
      '[authorization redacted]',
    )
    .replaceAll(
      RegExp(r'\b(?:sig|token)=([^&\s]+)', caseSensitive: false),
      '[credential redacted]',
    );

/// Tracks the one allowed app-level software retry for a video open.
///
/// Only errors from mpv's video decoder logs can consume the retry. Audio
/// decoder and transport errors stay visible to the player error UI.
class VideoDecodeRecovery {
  VideoDecodeRecovery(this.mode);

  final VideoDecodeMode mode;
  bool softwareRetryUsed = false;

  bool acceptVideoLog({
    required String prefix,
    required String level,
    required String text,
  }) {
    if (mode != VideoDecodeMode.automatic || softwareRetryUsed) return false;
    if (level != 'error') return false;
    if (prefix != 'vd' && prefix != 'ffmpeg/video') return false;

    // `vd` is mpv's video-decoder prefix, so the error itself is sufficient.
    if (prefix == 'vd') {
      softwareRetryUsed = true;
      return true;
    }
    final message = text.toLowerCase();
    if (!const [
      'codec',
      'decoder',
      'decode',
      'mediacodec',
      'surface',
    ].any(message.contains)) {
      return false;
    }

    softwareRetryUsed = true;
    return true;
  }
}
