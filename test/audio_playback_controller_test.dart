import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fryfrog_hub/core/audio/audio_playback_controller.dart';
import 'package:fryfrog_hub/core/models/audiobook.dart';
import 'package:fryfrog_hub/core/models/music.dart';

void main() {
  group('AudioPlaybackController', () {
    test(
      'chapter index resolves its track and seeks to track-local offset',
      () async {
        final player = _FakeAudioPlayer();
        final saves = <(int, int, double)>[];
        final book = AudiobookDetail.fromJson({
          'id': 12,
          'title': 'Book',
          'playType': 'MULTI',
          'tracks': [
            {
              'id': 801,
              'trackIndex': 7,
              'title': 'Track 8',
              'durationSeconds': 90,
              'streamUrl': '/track-8',
            },
            {
              'id': 802,
              'trackIndex': 9,
              'title': 'Track 10',
              'durationSeconds': 90,
              'streamUrl': '/track-10',
            },
          ],
          'chapters': [
            {
              'chapterIndex': 42,
              'trackIndex': 7,
              'title': 'Chapter',
              'startSeconds': 240,
              'endSeconds': 300,
              'startInTrack': 12.5,
            },
          ],
        });
        final controller = _controller(
          player,
          loadAudiobook: (_) async => book,
          save: (bookId, trackIndex, seconds) async {
            saves.add((bookId, trackIndex, seconds));
          },
        );
        await controller.playAudiobook(book, chapterIndex: 42);
        expect(player.openedUrls, ['/resolved/track-8']);
        expect(player.openedStarts.single, const Duration(milliseconds: 12500));

        await controller.pauseForVideo();
        expect(saves.last, (12, 7, 12.5));
        await controller.shutdown();
      },
    );

    test('new song cannot play the old native item after a pending selection is invalidated', () async {
      final player = _FakeAudioPlayer();
      final bFetch = Completer<MusicSong>();
      var bLoads = 0;
      final songs = {1: _song(1, 'A', '/a'), 2: _song(2, 'B', '/b')};
      final controller = AudioPlaybackController(
        player: player,
        loadMusicSong: (id) {
          if (id == 2 && bLoads++ == 0) return bFetch.future;
          return Future.value(songs[id]!);
        },
        loadAudiobook: (_) async => _audiobook(),
        resolveUrl: (path) => '/resolved${path ?? ''}',
        headersForUrl: (_) => const {},
        saveAudiobookProgress: (_, _, _) async {},
      );

      await controller.playSongs([songs[1]!, songs[2]!], 0);
      final selectingB = controller.playSongAt(1);
      await Future<void>.delayed(Duration.zero);
      expect(controller.nowPlaying?.title, 'B');
      expect(controller.isBuffering, isTrue);

      await controller.pauseForVideo();
      bFetch.complete(_song(2, 'B', '/b'));
      await selectingB;
      expect(controller.isPlaying, isFalse);
      expect(player.playCalls, 0);
      expect(player.openedUrls, ['/resolved/a']);

      await controller.togglePlayback();
      expect(player.playCalls, 0);
      expect(player.openedUrls, ['/resolved/a', '/resolved/b']);
      expect(controller.nowPlaying?.title, 'B');
      expect(controller.isPlaying, isTrue);
      await controller.shutdown();
    });

    test(
      'forced pause saves the latest coalesced audiobook snapshot',
      () async {
        final player = _FakeAudioPlayer();
        final firstWriteStarted = Completer<void>();
        final firstWrite = Completer<void>();
        final saved = <double>[];
        final book = _audiobook();
        final controller = AudioPlaybackController(
          player: player,
          loadMusicSong: (_) => throw StateError('unused'),
          loadAudiobook: (_) async => book,
          resolveUrl: (path) => '/resolved${path ?? ''}',
          headersForUrl: (_) => const {},
          saveAudiobookProgress: (_, _, seconds) {
            saved.add(seconds);
            if (saved.length == 1) {
              firstWriteStarted.complete();
              return firstWrite.future;
            }
            return Future<void>.value();
          },
        );
        await controller.playAudiobook(book);

        player.emitPosition(const Duration(seconds: 10));
        await firstWriteStarted.future.timeout(const Duration(seconds: 2));
        player.emitPosition(const Duration(seconds: 23));
        final pausing = controller.pauseForVideo();
        firstWrite.complete();
        await pausing;

        expect(saved, [10, 23]);
        await controller.shutdown();
      },
    );

    test(
      'same-book resume keeps live position and retry fetches a fresh stream URL',
      () async {
        final player = _FakeAudioPlayer();
        final book = _audiobook();
        var signedUrlVersion = 0;
        final controller = AudioPlaybackController(
          player: player,
          loadMusicSong: (_) => throw StateError('unused'),
          loadAudiobook: (_) async {
            signedUrlVersion++;
            return AudiobookDetail(
              id: book.id,
              title: book.title,
              playType: book.playType,
              coverUrl: book.coverUrl,
              totalDurationSeconds: book.totalDurationSeconds,
              tracks: [
                for (final track in book.tracks)
                  AudiobookTrack(
                    id: track.id,
                    trackIndex: track.trackIndex,
                    title: track.title,
                    durationSeconds: track.durationSeconds,
                    fileSize: track.fileSize,
                    streamUrl: '/signed-$signedUrlVersion',
                  ),
              ],
              chapters: book.chapters,
              progress: book.progress,
            );
          },
          resolveUrl: (path) => '/resolved${path ?? ''}',
          headersForUrl: (_) => const {},
          saveAudiobookProgress: (_, _, _) async {},
        );

        await controller.playAudiobook(book);
        player.emitPosition(const Duration(seconds: 20));
        await controller.pauseForVideo();
        await controller.playAudiobook(book);
        expect(controller.position, const Duration(seconds: 20));
        expect(player.openedUrls, ['/resolved/signed-1']);
        expect(signedUrlVersion, 1);

        await controller.pauseForVideo();
        await controller.retry();
        expect(player.openedUrls, ['/resolved/signed-1', '/resolved/signed-2']);
        expect(signedUrlVersion, 2);
        await controller.shutdown();
      },
    );
  });

  test(
    'audiobook DTO keeps chapter, track, global and local indexes distinct',
    () {
      final detail = _audiobook();
      final chapter = detail.chapterAt(40)!;
      expect(chapter.trackIndex, 5);
      expect(chapter.startSeconds, 200);
      expect(chapter.startInTrack, 11.25);
      expect(detail.trackAt(5)?.id, 50);
      expect(detail.progress?.trackIndex, 5);
      expect(detail.progress?.positionSeconds, 8.5);
    },
  );
}

AudioPlaybackController _controller(
  _FakeAudioPlayer player, {
  AudiobookLoader? loadAudiobook,
  required AudiobookProgressSaver save,
}) => AudioPlaybackController(
  player: player,
  loadMusicSong: (_) => throw StateError('unused'),
  loadAudiobook: loadAudiobook ?? (_) async => _audiobook(),
  resolveUrl: (path) => '/resolved${path ?? ''}',
  headersForUrl: (_) => const {},
  saveAudiobookProgress: save,
);

MusicSong _song(int id, String title, String url) =>
    MusicSong(id: id, title: title, streamUrl: url);

AudiobookDetail _audiobook() => AudiobookDetail.fromJson({
  'id': 5,
  'title': 'Book',
  'playType': 'SINGLE',
  'tracks': [
    {
      'id': 50,
      'trackIndex': 5,
      'title': 'M4B',
      'durationSeconds': 360,
      'streamUrl': '/book.m4b',
    },
  ],
  'chapters': [
    {
      'chapterIndex': 40,
      'trackIndex': 5,
      'title': 'Chapter 41',
      'startSeconds': 200,
      'endSeconds': 260,
      'startInTrack': 11.25,
    },
  ],
  'progress': {'trackIndex': 5, 'positionSeconds': 8.5, 'completed': false},
});

class _FakeAudioPlayer implements AudioPlayerPort {
  final _position = StreamController<Duration>.broadcast(sync: true);
  final _duration = StreamController<Duration>.broadcast(sync: true);
  final _playing = StreamController<bool>.broadcast(sync: true);
  final _buffering = StreamController<bool>.broadcast(sync: true);
  final _completed = StreamController<bool>.broadcast(sync: true);
  final _errors = StreamController<String>.broadcast(sync: true);
  AudioPlayerSnapshot _state = const AudioPlayerSnapshot();
  final List<String> openedUrls = [];
  final List<Duration> openedStarts = [];
  int playCalls = 0;

  @override
  AudioPlayerSnapshot get state => _state;
  @override
  Stream<Duration> get position => _position.stream;
  @override
  Stream<Duration> get duration => _duration.stream;
  @override
  Stream<bool> get playing => _playing.stream;
  @override
  Stream<bool> get buffering => _buffering.stream;
  @override
  Stream<bool> get completed => _completed.stream;
  @override
  Stream<String> get errors => _errors.stream;

  @override
  Future<AudioPlayerSnapshot> open(
    String url, {
    Map<String, String> headers = const {},
    Duration start = Duration.zero,
  }) async {
    openedUrls.add(url);
    openedStarts.add(start);
    _state = AudioPlayerSnapshot(
      position: start,
      duration: const Duration(seconds: 60),
      playing: true,
    );
    _position.add(start);
    _duration.add(_state.duration);
    _buffering.add(false);
    _playing.add(true);
    return _state;
  }

  @override
  Future<void> play() async {
    playCalls++;
    _state = AudioPlayerSnapshot(
      position: _state.position,
      duration: _state.duration,
      playing: true,
    );
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    _state = AudioPlayerSnapshot(
      position: _state.position,
      duration: _state.duration,
      playing: false,
    );
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async => emitPosition(position);

  void emitPosition(Duration position) {
    _state = AudioPlayerSnapshot(
      position: position,
      duration: _state.duration,
      playing: _state.playing,
      buffering: _state.buffering,
    );
    _position.add(position);
  }

  @override
  Future<void> stop() async {
    _state = const AudioPlayerSnapshot();
  }

  @override
  Future<void> dispose() async {
    await Future.wait([
      _position.close(),
      _duration.close(),
      _playing.close(),
      _buffering.close(),
      _completed.close(),
      _errors.close(),
    ]);
  }
}
