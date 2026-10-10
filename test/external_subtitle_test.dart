import 'package:flutter_test/flutter_test.dart';
import 'package:fryfrog_hub/core/models/video.dart';

/// 外挂字幕显示名的规则。
///
/// 字幕菜单里一行只放得下短标签，所以不能直接显示完整文件名——
/// `Movie.2024.1080p.zh.srt` 这种又长又带画质信息，既挤又难看。
void main() {
  group('ExternalSubtitle.displayName', () {
    test('有语言标识时优先显示语言', () {
      const sub = ExternalSubtitle(
        filename: 'Your.Name.S01E01.1080p.zh.srt',
        language: 'zh',
        url: 'http://x/1',
      );
      expect(sub.displayName, 'zh');
    });

    test('无语言标识时用文件主名', () {
      const sub = ExternalSubtitle(filename: 'episode1.srt', url: 'http://x/1');
      expect(sub.displayName, 'episode1');
    });

    test('剥掉画质与编码后缀噪声', () {
      const sub = ExternalSubtitle(
        filename: 'Movie.2024.1080p.x264.srt',
        url: 'http://x/1',
      );
      final name = sub.displayName;
      expect(name, isNot(contains('1080p')));
      expect(name, isNot(contains('x264')));
      // 下划线/点换成空格，读起来更像词而不是文件名。
      expect(name, isNot(contains('_')));
    });

    test('语言标识为空白串时视为没有', () {
      const sub = ExternalSubtitle(
        filename: 'sample.srt',
        language: '   ',
        url: 'http://x/1',
      );
      expect(sub.displayName, 'sample');
    });

    test('无扩展名的文件名也能处理', () {
      const sub = ExternalSubtitle(filename: 'subtitles', url: 'http://x/1');
      expect(sub.displayName, 'subtitles');
    });
  });
}
