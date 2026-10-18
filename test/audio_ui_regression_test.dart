import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fryfrog_hub/core/audio/audio_playback_controller.dart';
import 'package:fryfrog_hub/core/models/music.dart';
import 'package:fryfrog_hub/core/network/api_client.dart';
import 'package:fryfrog_hub/core/network/server_connection.dart';
import 'package:fryfrog_hub/core/state/app_prefs.dart';
import 'package:fryfrog_hub/core/state/session.dart';
import 'package:fryfrog_hub/widgets/mini_player.dart';

void main() {
  testWidgets('late lyrics from the previous song are discarded', (
    tester,
  ) async {
    final api = _LyricsApi();
    final player = _FakeAudioPlayer();
    final session = _session(api, player);
    final songs = [
      const MusicSong(id: 1, title: '第一首', streamUrl: '/one'),
      const MusicSong(id: 2, title: '第二首', streamUrl: '/two'),
    ];
    api.songs.addEntries(songs.map((song) => MapEntry(song.id, song)));
    api.lyrics[1] = Completer<String>();
    api.lyrics[2] = Completer<String>();
    await session.playMusicQueue(songs, 0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MiniPlayerBar(session: session)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('audio-mini-player')));
    await tester.pump(const Duration(milliseconds: 400));

    final pauseButton = find.byTooltip('暂停').last;
    expect(find.byTooltip('暂停'), findsNWidgets(2));
    expect(tester.getSize(pauseButton).width, greaterThanOrEqualTo(64));
    _showLyrics(tester);
    await tester.pump();
    expect(api.lyricsRequested, [1]);

    await session.audioController!.playSongAt(1);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('封面'), findsOneWidget);
    api.lyrics[1]!.complete('[00:01.00]旧歌歌词');
    await tester.pump();
    expect(find.text('旧歌歌词'), findsNothing);

    _showLyrics(tester);
    await tester.pump();
    expect(api.lyricsRequested, [1, 2]);
    api.lyrics[2]!.complete('[00:01.00]新歌歌词');
    await tester.pump();
    expect(find.text('新歌歌词'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    // This test uses only an in-memory AudioPlayerPort fake. The pending
    // controller teardown is outside the async lyrics behavior under test.
  });
}

void _showLyrics(WidgetTester tester) {
  final toggle = tester.widget<SegmentedButton<bool>>(
    find.byType(SegmentedButton<bool>),
  );
  toggle.onSelectionChanged!({true});
}

Session _session(_LyricsApi api, _FakeAudioPlayer player) {
  return Session(
    ServerConnection(),
    AppPrefs(),
    audioPlayerFactory: () => player,
  )..api = api;
}

class _LyricsApi extends ApiClient {
  _LyricsApi() : super('http://127.0.0.1');

  final Map<int, MusicSong> songs = {};
  final Map<int, Completer<String>> lyrics = {};
  final List<int> lyricsRequested = [];

  @override
  Future<MusicSong> fetchMusicSong(int songId) async => songs[songId]!;

  @override
  Future<String> fetchMusicLyrics(int songId) {
    lyricsRequested.add(songId);
    return lyrics[songId]!.future;
  }

  @override
  String resolveUrl(String? path) => path ?? '';
}

class _FakeAudioPlayer implements AudioPlayerPort {
  final StreamController<Duration> _position = StreamController.broadcast();
  final StreamController<Duration> _duration = StreamController.broadcast();
  final StreamController<bool> _playing = StreamController.broadcast();
  final StreamController<bool> _buffering = StreamController.broadcast();
  final StreamController<bool> _completed = StreamController.broadcast();
  final StreamController<String> _errors = StreamController.broadcast();
  AudioPlayerSnapshot _state = const AudioPlayerSnapshot();

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
    _state = AudioPlayerSnapshot(
      position: start,
      duration: const Duration(minutes: 2),
      playing: true,
    );
    _position.add(start);
    _duration.add(_state.duration);
    _playing.add(true);
    return _state;
  }

  @override
  Future<void> play() async {
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
  Future<void> seek(Duration position) async {
    _state = AudioPlayerSnapshot(
      position: position,
      duration: _state.duration,
      playing: _state.playing,
    );
    _position.add(position);
  }

  @override
  Future<void> stop() async {
    await pause();
  }

  @override
  Future<void> dispose() async {
    await _position.close();
    await _duration.close();
    await _playing.close();
    await _buffering.close();
    await _completed.close();
    await _errors.close();
  }
}
