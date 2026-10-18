/// A timed line from an LRC lyric file.
class TimedLyricLine {
  const TimedLyricLine({required this.at, required this.text});

  final Duration at;
  final String text;
}

/// Parses basic LRC timestamps, including multiple timestamps on one line.
/// Untimed plain text deliberately returns no timed lines and can be rendered
/// as ordinary lyric text by the player sheet.
List<TimedLyricLine> parseLrc(String source) {
  final timestamp = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
  final offset = RegExp(r'\[offset:([+-]?\d+)\]', caseSensitive: false)
      .firstMatch(source);
  final offsetMs = int.tryParse(offset?.group(1) ?? '') ?? 0;
  final lines = <({int order, TimedLyricLine line})>[];
  var order = 0;

  for (final rawLine in source.split(RegExp(r'\r?\n'))) {
    final matches = timestamp.allMatches(rawLine).toList(growable: false);
    if (matches.isEmpty) continue;
    final text = rawLine.replaceAll(timestamp, '').trim();
    if (text.isEmpty) continue;

    for (final match in matches) {
      final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
      final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
      final fraction = match.group(3) ?? '';
      final milliseconds = fraction.isEmpty
          ? 0
          : int.tryParse(fraction.padRight(3, '0').substring(0, 3)) ?? 0;
      final at = Duration(
        seconds: minutes * 60 + seconds,
        milliseconds: milliseconds + offsetMs,
      );
      lines.add((order: order++, line: TimedLyricLine(at: at, text: text)));
    }
  }

  lines.sort((a, b) {
    final byTime = a.line.at.compareTo(b.line.at);
    return byTime == 0 ? a.order.compareTo(b.order) : byTime;
  });
  return [for (final entry in lines) entry.line];
}

/// Returns the last lyric line whose timestamp has passed, or -1 before the
/// first line.
int activeLyricIndex(List<TimedLyricLine> lines, Duration position) {
  var active = -1;
  for (var index = 0; index < lines.length; index++) {
    if (lines[index].at > position) break;
    active = index;
  }
  return active;
}
