import 'package:flutter_test/flutter_test.dart';
import 'package:fryfrog_hub/core/rules/lyrics_rules.dart';

void main() {
  test('parses LRC milliseconds, multiple timestamps, and offsets', () {
    final lyrics = parseLrc('''
[ti:Title]
[offset:100]
[00:02.5]第二行
[00:01.05][00:01.50]第一行
普通纯文本
''');

    expect(lyrics.map((line) => line.text), [
      '第一行',
      '第一行',
      '第二行',
    ]);
    expect(lyrics.map((line) => line.at.inMilliseconds), [1150, 1600, 2600]);
    expect(activeLyricIndex(lyrics, const Duration(milliseconds: 1599)), 0);
    expect(activeLyricIndex(lyrics, const Duration(milliseconds: 1600)), 1);
    expect(activeLyricIndex(lyrics, const Duration(milliseconds: 500)), -1);
  });

  test('untimed text is handled as plain text rather than an empty LRC list', () {
    expect(parseLrc('第一句\n第二句'), isEmpty);
  });
}
