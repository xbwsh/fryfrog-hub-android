import 'common.dart';

/// Video / series / actor DTOs.

class SeriesListDto {
  const SeriesListDto({
    required this.id,
    this.type,
    this.title,
    this.originalTitle,
    this.coverUrl,
    this.fanartUrl,
    this.logoUrl,
    this.mediaType,
    this.rating,
    this.year,
    this.releaseDate,
    this.isAdult = false,
    this.favorite = false,
    this.episodeCount,
  });

  final int id;
  final String? type;
  final String? title;
  final String? originalTitle;
  final String? coverUrl;
  final String? fanartUrl;
  final String? logoUrl;
  final String? mediaType;
  final double? rating;
  final int? year;
  final String? releaseDate;
  final bool isAdult;
  final bool favorite;
  final int? episodeCount;

  String get displayTitle => (title != null && title!.isNotEmpty)
      ? title!
      : (originalTitle ?? '(未命名)');
  bool get isTv => mediaType?.toLowerCase() == 'tv';
  bool get isStandalone => type == 'standalone';

  factory SeriesListDto.fromJson(Map<String, dynamic> json) => SeriesListDto(
    id: (json['id'] as num?)?.toInt() ?? 0,
    type: json['type'] as String?,
    title: json['title'] as String?,
    originalTitle: json['originalTitle'] as String?,
    coverUrl: json['coverUrl'] as String?,
    fanartUrl: json['fanartUrl'] as String?,
    logoUrl: json['logoUrl'] as String?,
    mediaType: json['mediaType'] as String?,
    rating: (json['rating'] as num?)?.toDouble(),
    year: (json['year'] as num?)?.toInt(),
    releaseDate: json['releaseDate'] as String?,
    isAdult: json['isAdult'] == true,
    favorite: json['favorite'] == true,
    episodeCount: (json['episodeCount'] as num?)?.toInt(),
  );
}

class LibrarySeriesGroup {
  LibrarySeriesGroup({
    required this.libraryId,
    required this.libraryName,
    required this.series,
    required this.standaloneVideos,
    this.libraryPath,
    this.subType,
  });

  final int libraryId;
  final String libraryName;
  final String? libraryPath;
  final String? subType;
  final List<SeriesListDto> series;
  final List<SeriesListDto> standaloneVideos;

  String get name => libraryName.isEmpty ? '(未命名资源库)' : libraryName;
  List<SeriesListDto> get allItems => [...series, ...standaloneVideos];

  factory LibrarySeriesGroup.fromJson(Map<String, dynamic> json) {
    List<SeriesListDto> parseList(Object? raw) => (raw as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SeriesListDto.fromJson)
        .toList(growable: false);
    return LibrarySeriesGroup(
      libraryId: (json['libraryId'] as num?)?.toInt() ?? -1,
      libraryName: json['libraryName'] as String? ?? '',
      libraryPath: json['libraryPath'] as String?,
      subType: json['subType'] as String?,
      series: parseList(json['series']),
      standaloneVideos: parseList(json['standaloneVideos']),
    );
  }
}

/// Watch progress from video detail / `PUT /video/{id}/progress`.
class WatchProgress {
  const WatchProgress({
    this.videoId,
    this.positionSeconds,
    this.durationSeconds,
    this.completed,
    this.progressPercent,
  });

  final int? videoId;
  final double? positionSeconds;
  final double? durationSeconds;
  final bool? completed;
  final double? progressPercent;

  bool get hasPosition => (positionSeconds ?? 0) > 0;

  factory WatchProgress.fromJson(Map<String, dynamic> json) => WatchProgress(
    videoId: (json['videoId'] as num?)?.toInt(),
    positionSeconds: (json['positionSeconds'] as num?)?.toDouble(),
    durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
    completed: json['completed'] as bool?,
    progressPercent: (json['progressPercent'] as num?)?.toDouble(),
  );
}

/// One episode / movie payload inside series detail seasons.
class VideoItem {
  const VideoItem({
    required this.id,
    required this.title,
    this.coverUrl,
    this.fanartUrl,
    this.streamUrl,
    this.originalTitle,
    this.director,
    this.actors,
    this.genre,
    this.year,
    this.releaseDate,
    this.durationMinutes,
    this.overview,
    this.resolutionLabel,
    this.rating,
    this.mediaType,
    this.favorite,
    this.isSeries,
    this.seriesId,
    this.seriesTitle,
    this.seasonNumber,
    this.episodeNumber,
    this.watchPosition,
    this.watchProgressPercent,
    this.watched,
  });

  final int id;
  final String title;
  final String? coverUrl;
  final String? fanartUrl;
  final String? streamUrl;
  final String? originalTitle;
  final String? director;
  final String? actors;
  final String? genre;
  final int? year;
  final String? releaseDate;
  final int? durationMinutes;
  final String? overview;
  final String? resolutionLabel;
  final double? rating;
  final String? mediaType;
  final bool? favorite;
  final bool? isSeries;
  final int? seriesId;
  final String? seriesTitle;
  final int? seasonNumber;
  final int? episodeNumber;
  final double? watchPosition;
  final double? watchProgressPercent;
  final bool? watched;

  bool get isWatched => watched == true;
  bool get hasProgress => (watchProgressPercent ?? 0) > 0;
  bool get isMovie => (mediaType?.toLowerCase() ?? 'movie') == 'movie';

  String get episodeLabel {
    final s = seasonNumber;
    final e = episodeNumber;
    if (s != null && e != null) {
      return 'S${s.toString().padLeft(2, '0')}'
          'E${e.toString().padLeft(2, '0')}';
    }
    if (e != null) return '第 $e 集';
    return title;
  }

  factory VideoItem.fromJson(Map<String, dynamic> json) => VideoItem(
    id: (json['id'] as num?)?.toInt() ?? 0,
    title: json['title'] as String? ?? '',
    coverUrl: readCoverJson(json),
    fanartUrl: json['fanartUrl'] as String?,
    streamUrl: json['streamUrl'] as String?,
    originalTitle: json['originalTitle'] as String?,
    director: json['director'] as String?,
    actors: json['actors'] as String?,
    genre: json['genre'] as String?,
    year: (json['year'] as num?)?.toInt(),
    releaseDate: json['releaseDate'] as String?,
    durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
    overview: json['overview'] as String?,
    resolutionLabel: json['resolutionLabel'] as String?,
    rating: (json['rating'] as num?)?.toDouble(),
    mediaType: json['mediaType'] as String?,
    favorite: json['favorite'] as bool?,
    isSeries: json['isSeries'] as bool?,
    seriesId: (json['seriesId'] as num?)?.toInt(),
    seriesTitle: json['seriesTitle'] as String?,
    seasonNumber: (json['seasonNumber'] as num?)?.toInt(),
    episodeNumber: (json['episodeNumber'] as num?)?.toInt(),
    watchPosition: (json['watchPosition'] as num?)?.toDouble(),
    watchProgressPercent: (json['watchProgressPercent'] as num?)?.toDouble(),
    watched: json['watched'] as bool?,
  );
}

class SeasonInfo {
  const SeasonInfo({
    required this.seasonNumber,
    this.coverUrl,
    this.episodes = const [],
  });

  final int seasonNumber;
  final String? coverUrl;
  final List<VideoItem> episodes;

  factory SeasonInfo.fromJson(Map<String, dynamic> json) => SeasonInfo(
    seasonNumber: (json['seasonNumber'] as num?)?.toInt() ?? 1,
    coverUrl: json['coverUrl'] as String?,
    episodes: ((json['episodes'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(VideoItem.fromJson)
        .toList(growable: false),
  );
}

/// Detail payload of `GET /api/v1/video/series/{id}`.
class SeriesDetail {
  const SeriesDetail({
    required this.id,
    required this.type,
    required this.title,
    this.coverUrl,
    this.fanartUrl,
    this.logoUrl,
    this.originalTitle,
    this.overview,
    this.mediaType,
    this.tmdbId,
    this.rating,
    this.year,
    this.releaseDate,
    this.totalEpisodes,
    this.status,
    this.favorite,
    this.episodeCount,
    this.resolutions = const [],
    this.seasons = const [],
  });

  final int id;
  final String type; // series | standalone
  final String title;
  final String? coverUrl;
  final String? fanartUrl;
  final String? logoUrl;
  final String? originalTitle;
  final String? overview;
  final String? mediaType;
  final int? tmdbId;
  final double? rating;
  final int? year;
  final String? releaseDate;
  final int? totalEpisodes;
  final String? status;
  final bool? favorite;
  final int? episodeCount;
  final List<String> resolutions;
  final List<SeasonInfo> seasons;

  bool get isStandalone => type == 'standalone';
  bool get isTv => mediaType?.toLowerCase() == 'tv';

  List<VideoItem> get allEpisodes => [for (final s in seasons) ...s.episodes];

  VideoItem? get firstEpisode => allEpisodes.isEmpty ? null : allEpisodes.first;

  String get displayTitle => title.isEmpty ? '(未命名)' : title;

  factory SeriesDetail.fromJson(Map<String, dynamic> json) => SeriesDetail(
    id: (json['id'] as num?)?.toInt() ?? 0,
    type: json['type'] as String? ?? 'series',
    title: json['title'] as String? ?? '',
    coverUrl: json['coverUrl'] as String?,
    fanartUrl: json['fanartUrl'] as String?,
    logoUrl: json['logoUrl'] as String?,
    originalTitle: json['originalTitle'] as String?,
    overview: json['overview'] as String?,
    mediaType: json['mediaType'] as String?,
    tmdbId: (json['tmdbId'] as num?)?.toInt(),
    rating: (json['rating'] as num?)?.toDouble(),
    year: (json['year'] as num?)?.toInt(),
    releaseDate: json['releaseDate'] as String?,
    totalEpisodes: (json['totalEpisodes'] as num?)?.toInt(),
    status: json['status'] as String?,
    favorite: json['favorite'] as bool?,
    episodeCount: (json['episodeCount'] as num?)?.toInt(),
    resolutions: ((json['resolutions'] as List?) ?? const [])
        .whereType<String>()
        .toList(growable: false),
    seasons: ((json['seasons'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SeasonInfo.fromJson)
        .toList(growable: false),
  );
}

class VideoActorDto {
  const VideoActorDto({
    required this.id,
    required this.name,
    this.character,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String? character;
  final String? imageUrl;

  factory VideoActorDto.fromJson(Map<String, dynamic> json) => VideoActorDto(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    character: json['character'] as String?,
    imageUrl: json['imageUrl'] as String?,
  );
}
