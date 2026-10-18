/// Playback DTOs for audiobook details. Kept separate from [BookDetail] so
/// embedded chapters and audio tracks retain their own indexes and positions.
library;

import 'common.dart';

class AudiobookTrack {
  const AudiobookTrack({
    required this.id,
    required this.trackIndex,
    required this.title,
    required this.durationSeconds,
    this.fileSize,
    this.streamUrl,
  });

  final int id;
  final int trackIndex;
  final String title;
  final double durationSeconds;
  final int? fileSize;
  final String? streamUrl;

  factory AudiobookTrack.fromJson(Map<String, dynamic> json) => AudiobookTrack(
    id: (json['id'] as num?)?.toInt() ?? 0,
    trackIndex: (json['trackIndex'] as num?)?.toInt() ?? 0,
    title: json['title'] as String? ?? '',
    durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 0,
    fileSize: (json['fileSize'] as num?)?.toInt(),
    streamUrl: json['streamUrl'] as String?,
  );
}

class AudiobookChapter {
  const AudiobookChapter({
    required this.chapterIndex,
    required this.trackIndex,
    required this.startSeconds,
    required this.endSeconds,
    required this.startInTrack,
    this.title,
  });

  final int chapterIndex;
  final int trackIndex;
  final double startSeconds;
  final double endSeconds;
  final double startInTrack;
  final String? title;

  String get label =>
      title?.isNotEmpty == true ? title! : '第 ${chapterIndex + 1} 章';

  factory AudiobookChapter.fromJson(Map<String, dynamic> json) =>
      AudiobookChapter(
        chapterIndex: (json['chapterIndex'] as num?)?.toInt() ?? 0,
        trackIndex: (json['trackIndex'] as num?)?.toInt() ?? 0,
        startSeconds: (json['startSeconds'] as num?)?.toDouble() ?? 0,
        endSeconds: (json['endSeconds'] as num?)?.toDouble() ?? 0,
        startInTrack: (json['startInTrack'] as num?)?.toDouble() ?? 0,
        title: json['title'] as String?,
      );
}

class AudiobookProgress {
  const AudiobookProgress({
    required this.trackIndex,
    required this.positionSeconds,
    this.completed = false,
    this.percent,
  });

  final int trackIndex;
  final double positionSeconds;
  final bool completed;
  final double? percent;

  factory AudiobookProgress.fromJson(Map<String, dynamic> json) =>
      AudiobookProgress(
        trackIndex: (json['trackIndex'] as num?)?.toInt() ?? 0,
        positionSeconds: (json['positionSeconds'] as num?)?.toDouble() ?? 0,
        completed: json['completed'] == true,
        percent: (json['percent'] as num?)?.toDouble(),
      );
}

class AudiobookDetail {
  const AudiobookDetail({
    required this.id,
    required this.title,
    required this.playType,
    required this.tracks,
    required this.chapters,
    this.coverUrl,
    this.totalDurationSeconds,
    this.progress,
  });

  final int id;
  final String title;
  final String playType;
  final String? coverUrl;
  final double? totalDurationSeconds;
  final List<AudiobookTrack> tracks;
  final List<AudiobookChapter> chapters;
  final AudiobookProgress? progress;

  factory AudiobookDetail.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(Object? raw, T Function(Map<String, dynamic>) parse) =>
        (raw as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(parse)
            .toList(growable: false);

    final rawProgress = json['progress'];
    return AudiobookDetail(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      playType: json['playType'] as String? ?? 'MULTI',
      coverUrl: readCoverJson(json),
      totalDurationSeconds: (json['totalDurationSeconds'] as num?)?.toDouble(),
      tracks: parseList(json['tracks'], AudiobookTrack.fromJson),
      chapters: parseList(json['chapters'], AudiobookChapter.fromJson),
      progress: rawProgress is Map<String, dynamic>
          ? AudiobookProgress.fromJson(rawProgress)
          : null,
    );
  }

  AudiobookTrack? trackAt(int trackIndex) {
    for (final track in tracks) {
      if (track.trackIndex == trackIndex) return track;
    }
    return null;
  }

  AudiobookChapter? chapterAt(int chapterIndex) {
    for (final chapter in chapters) {
      if (chapter.chapterIndex == chapterIndex) return chapter;
    }
    return null;
  }
}
