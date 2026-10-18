import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../models/audiobook.dart';
import '../models/music.dart';

/// Small player port so queue and progress behavior can be tested without
/// creating a native media_kit player.
abstract interface class AudioPlayerPort {
  AudioPlayerSnapshot get state;
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<bool> get playing;
  Stream<bool> get buffering;
  Stream<bool> get completed;
  Stream<String> get errors;

  Future<AudioPlayerSnapshot> open(
    String url, {
    Map<String, String> headers = const {},
    Duration start = Duration.zero,
  });
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> stop();
  Future<void> dispose();
}

class AudioPlayerSnapshot {
  const AudioPlayerSnapshot({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playing = false,
    this.buffering = false,
  });

  final Duration position;
  final Duration duration;
  final bool playing;
  final bool buffering;
}

class MediaKitAudioPlayerPort implements AudioPlayerPort {
  MediaKitAudioPlayerPort() : _player = Player();

  final Player _player;

  @override
  AudioPlayerSnapshot get state => AudioPlayerSnapshot(
    position: _player.state.position,
    duration: _player.state.duration,
    playing: _player.state.playing,
    buffering: _player.state.buffering,
  );

  @override
  Stream<Duration> get position => _player.stream.position;
  @override
  Stream<Duration> get duration => _player.stream.duration;
  @override
  Stream<bool> get playing => _player.stream.playing;
  @override
  Stream<bool> get buffering => _player.stream.buffering;
  @override
  Stream<bool> get completed => _player.stream.completed;
  @override
  Stream<String> get errors => _player.stream.error;

  @override
  Future<AudioPlayerSnapshot> open(
    String url, {
    Map<String, String> headers = const {},
    Duration start = Duration.zero,
  }) async {
    final media = headers.isEmpty
        ? Media(url, start: start)
        : Media(url, start: start, httpHeaders: headers);
    await _player.open(media, play: true);
    return state;
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> dispose() => _player.dispose();
}

enum AudioPlaybackKind { music, audiobook }

class AudioNowPlaying {
  const AudioNowPlaying({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.queueIndex,
    required this.queueLength,
    this.songId,
  });

  final AudioPlaybackKind kind;
  final String title;
  final String subtitle;
  final String? coverUrl;
  final int queueIndex;
  final int queueLength;
  final int? songId;
}

typedef MusicSongLoader = Future<MusicSong> Function(int songId);
typedef AudiobookLoader = Future<AudiobookDetail> Function(int audiobookId);
typedef AudioUrlResolver = String Function(String? path);
typedef AudioHeadersForUrl = Map<String, String> Function(String url);
typedef AudiobookProgressSaver = Future<void> Function(
  int audiobookId,
  int trackIndex,
  double positionSeconds,
);

/// One audio session shared by music and audiobook UI. It owns a lazily
/// constructed media_kit player through [AudioPlayerPort].
class AudioPlaybackController extends ChangeNotifier {
  factory AudioPlaybackController({
    required AudioPlayerPort player,
    required MusicSongLoader loadMusicSong,
    required AudiobookLoader loadAudiobook,
    required AudioUrlResolver resolveUrl,
    required AudioHeadersForUrl headersForUrl,
    required AudiobookProgressSaver saveAudiobookProgress,
  }) => AudioPlaybackController._(
    player,
    loadMusicSong,
    loadAudiobook,
    resolveUrl,
    headersForUrl,
    saveAudiobookProgress,
  );

  AudioPlaybackController._(
    this._player,
    this._loadMusicSong,
    this._loadAudiobook,
    this._resolveUrl,
    this._headersForUrl,
    this._saveAudiobookProgress,
  ) {
    _subscriptions.addAll([
      _player.position.listen((value) {
        if (_closing || _closed) return;
        if (_opening) {
          _openingPosition = value;
          return;
        }
        _position = value;
        _notify();
        _maybeSaveProgress();
      }),
      _player.duration.listen((value) {
        if (_closing || _closed) return;
        if (_opening) {
          if (value > Duration.zero) _openingDuration = value;
          return;
        }
        if (value > Duration.zero) _duration = value;
        _notify();
      }),
      _player.playing.listen((value) {
        if (_closing || _closed) return;
        if (_opening) {
          _openingPlaying = value;
          return;
        }
        _playing = value;
        _notify();
        if (!value) _maybeSaveProgress(force: true);
      }),
      _player.buffering.listen((value) {
        if (_closing || _closed) return;
        if (_opening) {
          _openingBuffering = value;
          return;
        }
        _buffering = value;
        _notify();
      }),
      _player.errors.listen((value) {
        if (_closing || _closed || value.isEmpty) return;
        // Native player errors can include a signed URL; show a safe summary.
        if (_opening) {
          _openingError = '音频播放失败，请检查媒体文件或服务器连接';
          return;
        }
        _error = '音频播放失败，请检查媒体文件或服务器连接';
        _notify();
      }),
      _player.completed.listen((value) {
        if (value && !_closing && !_closed && !_opening) {
          unawaited(_handleCompletion());
        }
      }),
    ]);
  }

  final AudioPlayerPort _player;
  final MusicSongLoader _loadMusicSong;
  final AudiobookLoader _loadAudiobook;
  final AudioUrlResolver _resolveUrl;
  final AudioHeadersForUrl _headersForUrl;
  final AudiobookProgressSaver _saveAudiobookProgress;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  List<MusicSong> _musicQueue = const [];
  AudiobookDetail? _audiobook;
  int _musicIndex = -1;
  int _audiobookTrackListIndex = -1;
  AudiobookTrack? _audiobookTrack;
  AudioNowPlaying? _nowPlaying;
  AudioPlaybackKind? _kind;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _buffering = false;
  bool _currentMediaReady = false;
  String? _error;
  bool _opening = false;
  bool _closing = false;
  bool _closed = false;
  bool _disposing = false;
  Future<void>? _shutdownFuture;
  Future<void> _openTail = Future<void>.value();
  Future<void>? _progressDrain;
  _AudiobookProgressSnapshot? _pendingProgress;
  int _selectionVersion = 0;
  int _lastHandledCompletionVersion = -1;
  DateTime? _lastProgressEnqueuedAt;
  String? _lastSavedProgressKey;
  String? _lastEnqueuedProgressKey;
  Duration? _openingPosition;
  Duration? _openingDuration;
  bool? _openingPlaying;
  bool? _openingBuffering;
  String? _openingError;

  AudioNowPlaying? get nowPlaying => _nowPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _playing;
  bool get isBuffering => _buffering;
  int? get activeAudiobookId => _audiobook?.id;
  bool get canResumeAudiobook =>
      _kind == AudioPlaybackKind.audiobook &&
      _audiobook != null &&
      (_duration <= Duration.zero || _position < _duration);
  bool get canSeek =>
      _currentMediaReady && !_opening && _duration > Duration.zero;
  String? get error => _error;
  bool get hasPrevious => switch (_kind) {
    AudioPlaybackKind.music => _musicIndex > 0,
    AudioPlaybackKind.audiobook => _audiobookTrackListIndex > 0,
    null => false,
  };
  bool get hasNext => switch (_kind) {
    AudioPlaybackKind.music =>
      _musicIndex >= 0 && _musicIndex < _musicQueue.length - 1,
    AudioPlaybackKind.audiobook =>
      _audiobookTrackListIndex >= 0 &&
          _audiobookTrackListIndex < (_audiobook?.tracks.length ?? 0) - 1,
    null => false,
  };

  Future<void> playSongs(List<MusicSong> queue, int index) async {
    if (queue.isEmpty || index < 0 || index >= queue.length) {
      _error = '当前没有可播放的歌曲';
      _notify();
      return;
    }
    final version = ++_selectionVersion;
    await _pauseNative();
    await _saveCurrentProgress(force: true);
    if (!_isCurrent(version)) return;
    _kind = AudioPlaybackKind.music;
    _musicQueue = List<MusicSong>.unmodifiable(queue);
    _audiobook = null;
    _audiobookTrack = null;
    _audiobookTrackListIndex = -1;
    _musicIndex = index;
    await _openMusic(index, version);
  }

  Future<void> playSongAt(int index) async {
    if (_kind != AudioPlaybackKind.music ||
        index < 0 ||
        index >= _musicQueue.length) {
      _error = '找不到要播放的歌曲';
      _notify();
      return;
    }
    final version = ++_selectionVersion;
    await _pauseNative();
    if (!_isCurrent(version)) return;
    _playing = false;
    _musicIndex = index;
    await _openMusic(index, version);
  }

  Future<void> playAudiobook(
    AudiobookDetail audiobook, {
    int? chapterIndex,
  }) async {
    if (chapterIndex == null &&
        _kind == AudioPlaybackKind.audiobook &&
        _audiobook?.id == audiobook.id &&
        canResumeAudiobook &&
        audiobook.progress?.completed != true) {
      await resumeAudiobook();
      return;
    }
    if (audiobook.tracks.isEmpty) {
      _error = '这本有声书没有可播放的音轨';
      _notify();
      return;
    }
    final chapter = chapterIndex == null
        ? null
        : audiobook.chapterAt(chapterIndex);
    final preferredTrackIndex =
        chapter?.trackIndex ??
        ((chapterIndex == null && audiobook.progress?.completed != true)
            ? audiobook.progress?.trackIndex
            : null) ??
        audiobook.tracks.first.trackIndex;
    final track = audiobook.trackAt(preferredTrackIndex);
    if (track == null) {
      _error = '找不到对应音轨';
      _notify();
      return;
    }

    final version = ++_selectionVersion;
    await _pauseNative();
    await _saveCurrentProgress(force: true);
    if (!_isCurrent(version)) return;

    _kind = AudioPlaybackKind.audiobook;
    _musicQueue = const [];
    _musicIndex = -1;
    _audiobook = audiobook;
    final trackListIndex = audiobook.tracks.indexOf(track);
    final resumeSeconds =
        chapter?.startInTrack ??
        ((chapterIndex == null && audiobook.progress?.completed != true)
            ? audiobook.progress?.positionSeconds ?? 0
            : 0);
    await _openAudiobookTrack(
      track,
      trackListIndex,
      version,
      initialPosition: Duration(milliseconds: (resumeSeconds * 1000).round()),
    );
  }

  Future<void> togglePlayback() async {
    if (_nowPlaying == null || _closing || _closed || _opening) return;
    if (!_currentMediaReady) {
      await retry();
      return;
    }
    _error = null;
    try {
      if (_playing) {
        await _player.pause();
        _syncPlayerState();
        await _saveCurrentProgress(force: true);
      } else {
        await _player.play();
        _syncPlayerState();
      }
    } catch (_) {
      _error = '无法控制音频播放，请重试';
    }
    _notify();
  }

  /// Resumes the current book without fetching potentially stale server progress.
  Future<void> resumeAudiobook() async {
    if (_kind != AudioPlaybackKind.audiobook ||
        _nowPlaying == null ||
        _playing) {
      return;
    }
    await togglePlayback();
  }

  Future<void> playPrevious() async {
    if (!hasPrevious) return;
    if (_kind == AudioPlaybackKind.music) {
      await playSongAt(_musicIndex - 1);
      return;
    }
    final version = ++_selectionVersion;
    await _pauseNative();
    await _saveCurrentProgress(force: true);
    if (!_isCurrent(version)) return;
    final index = _audiobookTrackListIndex - 1;
    final book = _audiobook!;
    await _openAudiobookTrack(book.tracks[index], index, version);
  }

  Future<void> playNext() async {
    if (!hasNext) return;
    if (_kind == AudioPlaybackKind.music) {
      await playSongAt(_musicIndex + 1);
      return;
    }
    final version = ++_selectionVersion;
    await _pauseNative();
    await _saveCurrentProgress(force: true);
    if (!_isCurrent(version)) return;
    final index = _audiobookTrackListIndex + 1;
    final book = _audiobook!;
    await _openAudiobookTrack(book.tracks[index], index, version);
  }

  Future<void> retry() async {
    if (_nowPlaying == null || _closing || _closed) return;
    final version = ++_selectionVersion;
    await _pauseNative();
    if (!_isCurrent(version)) return;
    await _saveCurrentProgress(force: true);
    if (!_isCurrent(version)) return;
    if (_kind == AudioPlaybackKind.music && _musicIndex >= 0) {
      await _openMusic(_musicIndex, version);
    } else if (_kind == AudioPlaybackKind.audiobook &&
        _audiobookTrack != null) {
      await _openAudiobookTrack(
        _audiobookTrack!,
        _audiobookTrackListIndex,
        version,
        initialPosition: _position,
      );
    }
  }

  Future<void> seek(Duration target) async {
    if (_nowPlaying == null ||
        _duration <= Duration.zero ||
        _closed ||
        _opening ||
        _closing) {
      return;
    }
    final clamped = Duration(
      milliseconds: target.inMilliseconds.clamp(0, _duration.inMilliseconds),
    );
    await _openTail;
    _position = clamped;
    _notify();
    try {
      await _player.seek(clamped);
      await _saveCurrentProgress(force: true);
    } catch (_) {
      _error = '无法跳转到该位置，请重试';
      _notify();
    }
  }

  Future<void> pauseForVideo() async {
    if (_closing || _closed) return;
    // Invalidate loads still resolving a signed URL as well as an open already
    // inside media_kit. Always pause after the native open gate, even if the
    // stream had not emitted `playing=true` yet.
    _selectionVersion++;
    await _pauseNative();
    _opening = false;
    _buffering = false;
    await _saveCurrentProgress(force: true);
    _notify();
  }

  Future<void> _openMusic(int index, int version) async {
    final song = _musicQueue[index];
    _musicIndex = index;
    _nowPlaying = AudioNowPlaying(
      kind: AudioPlaybackKind.music,
      title: song.title,
      subtitle: [
        if (song.artistName?.isNotEmpty == true) song.artistName!,
        if (song.albumName?.isNotEmpty == true) song.albumName!,
      ].join(' · '),
      coverUrl: song.coverPath,
      queueIndex: index,
      queueLength: _musicQueue.length,
      songId: song.id,
    );
    _position = Duration.zero;
    _duration = Duration.zero;
    _currentMediaReady = false;
    _buffering = true;
    _error = null;
    _opening = true;
    _clearOpeningEvents();
    _notify();

    try {
      final fresh = await _loadMusicSong(song.id);
      if (!_isCurrent(version)) return;
      final signed = fresh.streamUrl;
      if (signed == null || signed.isEmpty) {
        throw StateError('歌曲缺少播放地址');
      }
      final url = _resolveUrl(signed);
      if (url.isEmpty) throw StateError('歌曲播放地址无效');
      await _openMedia(url, version);
    } catch (_) {
      if (!_isCurrent(version)) return;
      _failCurrentItem();
    }
  }

  Future<void> _openAudiobookTrack(
    AudiobookTrack track,
    int listIndex,
    int version, {
    Duration initialPosition = Duration.zero,
  }) async {
    final book = _audiobook!;
    _audiobookTrack = track;
    _audiobookTrackListIndex = listIndex;
    _nowPlaying = AudioNowPlaying(
      kind: AudioPlaybackKind.audiobook,
      title: track.title.isEmpty ? book.title : track.title,
      subtitle: book.title,
      coverUrl: book.coverUrl ?? '/api/v1/audiobooks/${book.id}/cover',
      queueIndex: listIndex,
      queueLength: book.tracks.length,
    );
    _position = initialPosition;
    _duration = Duration(milliseconds: (track.durationSeconds * 1000).round());
    _currentMediaReady = false;
    _buffering = true;
    _error = null;
    _opening = true;
    _clearOpeningEvents();
    _notify();

    try {
      // Media URLs expire. Each actual native open (first play, next/previous,
      // retry) fetches a fresh signed track URL from the detail endpoint.
      final freshBook = await _loadAudiobook(book.id);
      if (!_isCurrent(version)) return;
      final freshTrack = freshBook.trackAt(track.trackIndex);
      if (freshTrack == null) throw StateError('找不到对应音轨');
      final freshListIndex = freshBook.tracks.indexOf(freshTrack);
      _audiobook = freshBook;
      _audiobookTrack = freshTrack;
      _audiobookTrackListIndex = freshListIndex;
      _duration = Duration(
        milliseconds: (freshTrack.durationSeconds * 1000).round(),
      );
      _nowPlaying = AudioNowPlaying(
        kind: AudioPlaybackKind.audiobook,
        title: freshTrack.title.isEmpty ? freshBook.title : freshTrack.title,
        subtitle: freshBook.title,
        coverUrl:
            freshBook.coverUrl ?? '/api/v1/audiobooks/${freshBook.id}/cover',
        queueIndex: freshListIndex,
        queueLength: freshBook.tracks.length,
      );
      final signed = freshTrack.streamUrl;
      if (signed == null || signed.isEmpty) {
        throw StateError('音轨缺少播放地址');
      }
      final url = _resolveUrl(signed);
      if (url.isEmpty) throw StateError('音轨播放地址无效');
      await _openMedia(url, version, initialPosition: initialPosition);
    } catch (_) {
      if (!_isCurrent(version)) return;
      _failCurrentItem();
    }
  }

  Future<void> _openMedia(
    String url,
    int version, {
    Duration initialPosition = Duration.zero,
  }) async {
    final previousOpen = _openTail;
    final gate = Completer<void>();
    _openTail = gate.future;
    await previousOpen;
    try {
      if (!_isCurrent(version)) return;
      final start = _clampToDuration(initialPosition, _duration);
      final snapshot = await _player.open(
        url,
        headers: _headersForUrl(url),
        start: start,
      );
      if (!_isCurrent(version)) return;
      if ((_openingDuration ?? snapshot.duration) > Duration.zero) {
        _duration = _openingDuration ?? snapshot.duration;
      }
      final openedPosition =
          _openingPosition != null &&
              (_openingPosition! > Duration.zero || start == Duration.zero)
          ? _openingPosition!
          : (snapshot.position > Duration.zero ? snapshot.position : start);
      _position = openedPosition > Duration.zero ? openedPosition : start;
      _playing = _openingPlaying ?? snapshot.playing;
      _buffering = _openingBuffering ?? snapshot.buffering;
      _opening = false;
      if (_openingError != null) {
        _error = _openingError;
        _currentMediaReady = false;
        _playing = false;
        _buffering = false;
      } else {
        _currentMediaReady = true;
      }
      _clearOpeningEvents();
      _notify();
    } finally {
      gate.complete();
    }
  }

  Future<void> _handleCompletion() async {
    final version = _selectionVersion;
    if (_lastHandledCompletionVersion == version) return;
    _lastHandledCompletionVersion = version;
    if (_duration > Duration.zero) _position = _duration;
    if (hasNext) {
      await playNext();
      return;
    }
    await _saveCurrentProgress(force: true);
    _playing = false;
    _notify();
  }

  void _maybeSaveProgress({bool force = false}) {
    if (_kind != AudioPlaybackKind.audiobook || _closing || _closed) return;
    unawaited(_saveCurrentProgress(force: force));
  }

  Future<void> _saveCurrentProgress({bool force = false}) {
    final book = _audiobook;
    final track = _audiobookTrack;
    if (_kind != AudioPlaybackKind.audiobook || book == null || track == null) {
      return Future<void>.value();
    }
    final positionSeconds = _position.inMilliseconds / 1000.0;
    final key =
        '${book.id}:${track.trackIndex}:${positionSeconds.toStringAsFixed(2)}';
    final now = DateTime.now();
    final snapshot = _AudiobookProgressSnapshot(
      audiobookId: book.id,
      trackIndex: track.trackIndex,
      positionSeconds: positionSeconds,
      key: key,
    );

    if (_progressDrain != null) {
      // While a write is in flight, keep at most one pending write. Once it is
      // eligible, every later position tick replaces that pending snapshot so
      // the eventual write contains the newest position.
      if (_pendingProgress != null) {
        _pendingProgress = snapshot;
        _lastEnqueuedProgressKey = key;
        return force ? _progressDrain! : Future<void>.value();
      }
      if (_lastEnqueuedProgressKey == key) {
        return force ? _progressDrain! : Future<void>.value();
      }
      if (!force &&
          _lastProgressEnqueuedAt != null &&
          now.difference(_lastProgressEnqueuedAt!) <
              const Duration(seconds: 15)) {
        return Future<void>.value();
      }
      _pendingProgress = snapshot;
      _lastEnqueuedProgressKey = key;
      _lastProgressEnqueuedAt = now;
      return force ? _progressDrain! : Future<void>.value();
    }

    if (_lastSavedProgressKey == key) return Future<void>.value();
    if (!force &&
        (_lastEnqueuedProgressKey == key ||
            (_lastProgressEnqueuedAt != null &&
                now.difference(_lastProgressEnqueuedAt!) <
                    const Duration(seconds: 15)))) {
      return Future<void>.value();
    }

    _pendingProgress = snapshot;
    _lastEnqueuedProgressKey = key;
    _lastProgressEnqueuedAt = now;
    final drain = _progressDrain ??= _drainProgressSaves();
    return force ? drain : Future<void>.value();
  }

  Future<void> _drainProgressSaves() async {
    while (_pendingProgress != null) {
      final snapshot = _pendingProgress!;
      _pendingProgress = null;
      try {
        await _saveAudiobookProgress(
          snapshot.audiobookId,
          snapshot.trackIndex,
          snapshot.positionSeconds,
        );
        _lastSavedProgressKey = snapshot.key;
        if (_error == '收听进度保存失败') _error = null;
      } catch (_) {
        _error = '收听进度保存失败';
        _notify();
      }
    }
    _progressDrain = null;
  }

  bool _isCurrent(int version) =>
      !_closing && !_closed && version == _selectionVersion;

  Future<void> _pauseNative() async {
    if (_closing || _closed) return;
    try {
      await _openTail;
      if (_closing || _closed) return;
      await _player.pause();
      _syncPlayerState();
      _opening = false;
      _notify();
    } catch (_) {
      _error = '无法暂停音频，请重试';
      _notify();
    }
  }

  void _syncPlayerState() {
    final state = _player.state;
    if (_currentMediaReady) {
      _position = state.position;
      if (state.duration > Duration.zero) _duration = state.duration;
    }
    _playing = state.playing;
    _buffering = state.buffering;
  }

  Duration _clampToDuration(Duration position, Duration duration) {
    if (duration <= Duration.zero) return position;
    return Duration(
      milliseconds: position.inMilliseconds.clamp(0, duration.inMilliseconds),
    );
  }

  void _clearOpeningEvents() {
    _openingPosition = null;
    _openingDuration = null;
    _openingPlaying = null;
    _openingBuffering = null;
    _openingError = null;
  }

  void _failCurrentItem() {
    _opening = false;
    _buffering = false;
    _playing = false;
    _currentMediaReady = false;
    _error = '音频播放失败，请检查媒体文件或服务器连接';
    _notify();
  }

  void _notify() {
    if (!_closing && !_closed) notifyListeners();
  }

  Future<void> shutdown() => _shutdownFuture ??= _shutdown();

  Future<void> _shutdown() async {
    if (_closed || _closing) return;
    _closing = true;
    _selectionVersion++;
    try {
      await _openTail;
    } catch (_) {}
    try {
      await _player.pause();
      _syncPlayerState();
    } catch (_) {}
    await _saveCurrentProgress(force: true);
    _closed = true;
    _opening = false;
    _buffering = false;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await _player.dispose();
    } catch (_) {}
    dispose();
  }

  @override
  void dispose() {
    if (_disposing) return;
    _disposing = true;
    // Session.logout awaits shutdown; app teardown is synchronous, so finish
    // the same save/release sequence in the background if needed.
    unawaited(shutdown());
    super.dispose();
  }
}

class _AudiobookProgressSnapshot {
  const _AudiobookProgressSnapshot({
    required this.audiobookId,
    required this.trackIndex,
    required this.positionSeconds,
    required this.key,
  });

  final int audiobookId;
  final int trackIndex;
  final double positionSeconds;
  final String key;
}
