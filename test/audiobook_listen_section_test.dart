import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fryfrog_hub/core/models/media_models.dart';
import 'package:fryfrog_hub/features/books/book_detail_screen.dart';

void main() {
  testWidgets(
    'long chapter labels stay within the audiobook controls on a phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final detail = AudiobookDetail.fromJson({
        'id': 1,
        'title': '有声书',
        'playType': 'SINGLE',
        'tracks': [
          {
            'id': 10,
            'trackIndex': 0,
            'title': 'M4B',
            'durationSeconds': 3600,
            'streamUrl': '/track',
          },
        ],
        'chapters': [
          {
            'chapterIndex': 0,
            'trackIndex': 0,
            'title': '这是一个非常非常非常非常非常非常非常长的章节标题，用来验证窄屏布局不会横向溢出',
            'startSeconds': 0,
            'endSeconds': 120,
            'startInTrack': 0,
          },
        ],
        'progress': {
          'trackIndex': 0,
          'positionSeconds': 12,
          'completed': false,
        },
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AudiobookListenSection(
                  detail: detail,
                  loading: false,
                  error: null,
                  starting: false,
                  onPlay: () {},
                  onPlayChapter: (_) {},
                  onRetry: () {},
                  typeScale: 1,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final button = tester.getRect(find.byType(FilledButton).first);
      expect(button.width, lessThanOrEqualTo(264));
      expect(button.center.dx, closeTo(160, 1));
    },
  );
}
