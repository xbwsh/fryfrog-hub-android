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
    this.resolutions = const [],
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

  /// Distinct resolution labels across the item's episodes,
  /// backend-sorted high → low (4K, 2K, 1080p, …).
  final List<String> resolutions;

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
    resolutions: [
      for (final r in (json['resolutions'] as List? ?? const []))
        if (r is String) r,
    ],
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

  /// 库内总条目数（剧卡 + 单片）。
  int get itemCount => series.length + standaloneVideos.length;

  /// 库内视频文件总数：剧按 episodeCount 累加，单片各算 1。
  /// 后端分页返回时这里只统计**已加载**的部分，属预期。
  int get videoCount =>
      standaloneVideos.length +
      series.fold<int>(0, (sum, s) => sum + (s.episodeCount ?? 0));

  /// 库标题旁的统计文案：`12 个系列 · 340 个视频`；
  /// 纯单片库用 `340 个视频`，空库用 `空`。
  String get statsLabel {
    final parts = <String>[
      if (series.isNotEmpty) '${series.length} 个系列',
      if (videoCount > 0) '$videoCount 个视频',
    ];
    return parts.isEmpty ? '空' : parts.join(' · ');
  }

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

/// One TMDB search hit from `GET /api/v1/video/tmdb/search`.
/// All fields camelCase (matches backend DTO, not TMDB's snake_case).
class TmdbSearchItem {
  const TmdbSearchItem({
    required this.id,
    required this.mediaType,
    this.title,
    this.originalTitle,
    this.overview,
    this.releaseDate,
    this.year,
    this.posterPath,
    this.backdropPath,
    this.genreIds = const [],
    this.voteAverage,
    this.voteCount,
    this.popularity,
    this.adult = false,
  });

  final int id;
  final String mediaType; // movie | tv
  final String? title;
  final String? originalTitle;
  final String? overview;
  final String? releaseDate;
  final int? year;
  final String? posterPath;
  final String? backdropPath;
  final List<int> genreIds;
  final double? voteAverage;
  final int? voteCount;
  final double? popularity;
  final bool adult;

  String get displayTitle =>
      (title != null && title!.isNotEmpty) ? title! : (originalTitle ?? '');
  bool get isTv => mediaType.toLowerCase() == 'tv';

  /// TMDB CDN path — [posterPath] is a bare `/xyz.jpg` file name.
  String? get posterUrl {
    final p = posterPath;
    if (p == null || p.isEmpty) return null;
    return 'https://image.tmdb.org/t/p/w200${p.startsWith('/') ? '' : '/'}$p';
  }

  factory TmdbSearchItem.fromJson(Map<String, dynamic> json) => TmdbSearchItem(
    id: (json['id'] as num?)?.toInt() ?? 0,
    mediaType: json['mediaType'] as String? ?? 'movie',
    title: json['title'] as String?,
    originalTitle: json['originalTitle'] as String?,
    overview: json['overview'] as String?,
    releaseDate: json['releaseDate'] as String?,
    year: (json['year'] as num?)?.toInt(),
    posterPath: json['posterPath'] as String?,
    backdropPath: json['backdropPath'] as String?,
    genreIds: ((json['genreIds'] as List?) ?? const [])
        .whereType<num>()
        .map((e) => e.toInt())
        .toList(growable: false),
    voteAverage: (json['voteAverage'] as num?)?.toDouble(),
    voteCount: (json['voteCount'] as num?)?.toInt(),
    popularity: (json['popularity'] as num?)?.toDouble(),
    adult: json['adult'] == true,
  );
}

/// Admin logo candidate from `GET .../logo-options`.
/// [url] is a server-relative TMDB image proxy path (needs Bearer auth).
class LogoOption {
  const LogoOption({
    this.filePath,
    this.iso6391,
    this.width,
    this.height,
    this.voteCount,
    this.url,
  });

  final String? filePath;
  final String? iso6391;
  final int? width;
  final int? height;
  final double? voteCount;
  final String? url;

  String get sizeLabel =>
      (width != null && height != null) ? '${width}x$height' : '';

  factory LogoOption.fromJson(Map<String, dynamic> json) => LogoOption(
    filePath: json['filePath'] as String?,
    iso6391: json['iso6391'] as String?,
    width: (json['width'] as num?)?.toInt(),
    height: (json['height'] as num?)?.toInt(),
    voteCount: (json['voteCount'] as num?)?.toDouble(),
    url: json['url'] as String?,
  );
}

/// One frame screenshot candidate (`POST .../frames`).
/// [url] is server-relative and requires Bearer auth.
class FrameCandidate {
  const FrameCandidate({required this.index, this.position, this.url});

  final int index;
  final double? position;
  final String? url;

  factory FrameCandidate.fromJson(Map<String, dynamic> json) => FrameCandidate(
    index: (json['index'] as num?)?.toInt() ?? 0,
    position: (json['position'] as num?)?.toDouble(),
    url: json['url'] as String?,
  );
}

/// 一张 TMDB「本集剧照」（still）候选，来自 `GET /video/{id}/cover-options`。
/// 分集横屏在本项目里就是本集 still；用户可从中挑一张作为横屏封面。
class CoverOption {
  const CoverOption({
    this.filePath,
    this.url,
    this.width,
    this.height,
    this.voteCount,
    this.iso6391,
  });

  /// TMDB 的 `still_path`，提交时回传这个值。
  final String? filePath;

  /// 走本站代理的预览地址（w780）。
  final String? url;
  final int? width;
  final int? height;
  final double? voteCount;
  final String? iso6391;

  String get sizeLabel =>
      (width != null && height != null) ? '$width×$height' : '';

  factory CoverOption.fromJson(Map<String, dynamic> json) => CoverOption(
    filePath: json['filePath'] as String?,
    url: json['url'] as String?,
    width: (json['width'] as num?)?.toInt(),
    height: (json['height'] as num?)?.toInt(),
    voteCount: (json['voteCount'] as num?)?.toDouble(),
    iso6391: json['iso6391'] as String?,
  );
}

/// 某层级（总览/季/单集）某一类（海报/背景图/剧照）的 TMDB 图片候选。
/// 来自 `GET /video/{id}/tmdb-images?level=`.
class TmdbImageOptions {
  const TmdbImageOptions({
    required this.level,
    this.poster = const [],
    this.backdrop = const [],
    this.still = const [],
    this.seasonNumber,
    this.episodeNumber,
  });

  /// series | season | episode
  final String level;
  final List<CoverOption> poster;
  final List<CoverOption> backdrop;
  final List<CoverOption> still;
  final int? seasonNumber;
  final int? episodeNumber;

  List<CoverOption> byKind(String kind) => switch (kind) {
    'poster' => poster,
    'backdrop' => backdrop,
    'still' => still,
    _ => const [],
  };

  factory TmdbImageOptions.fromJson(Map<String, dynamic> json) {
    List<CoverOption> parse(Object? raw) => (raw as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CoverOption.fromJson)
        .toList(growable: false);
    final options = json['options'];
    final map = options is Map<String, dynamic>
        ? options
        : const <String, dynamic>{};
    return TmdbImageOptions(
      level: json['level'] as String? ?? 'episode',
      poster: parse(map['poster']),
      backdrop: parse(map['backdrop']),
      still: parse(map['still']),
      seasonNumber: (json['seasonNumber'] as num?)?.toInt(),
      episodeNumber: (json['episodeNumber'] as num?)?.toInt(),
    );
  }
}

/// Background scrape/bind task progress
/// (`GET /api/v1/video/scrape/progress?module=`).
class ScrapeProgress {
  const ScrapeProgress({
    this.stage,
    this.running = false,
    this.percent,
    this.completed,
    this.total,
  });

  final String? stage;
  final bool running;
  final double? percent;
  final int? completed;
  final int? total;

  factory ScrapeProgress.fromJson(Map<String, dynamic> json) => ScrapeProgress(
    stage: json['stage'] as String?,
    running: json['running'] as bool? ?? false,
    percent: (json['percent'] as num?)?.toDouble(),
    completed: (json['completed'] as num?)?.toInt(),
    total: (json['total'] as num?)?.toInt(),
  );
}

/// Stats summary of `POST .../series/{id}/refresh-season-covers`.
class SeasonRefreshResult {
  const SeasonRefreshResult({
    this.refreshedSeasonPosters = 0,
    this.refreshedEpisodeCovers = 0,
    this.cleanedEpisodePosters = 0,
    this.totalSeasons = 0,
    this.totalEpisodes = 0,
  });

  final int refreshedSeasonPosters;
  final int refreshedEpisodeCovers;
  final int cleanedEpisodePosters;
  final int totalSeasons;
  final int totalEpisodes;

  String get summary =>
      '刷新季海报 $refreshedSeasonPosters / 更新剧集封面 '
      '$refreshedEpisodeCovers / 清理旧封面 $cleanedEpisodePosters';

  factory SeasonRefreshResult.fromJson(Map<String, dynamic> json) =>
      SeasonRefreshResult(
        refreshedSeasonPosters:
            (json['refreshedSeasonPosters'] as num?)?.toInt() ?? 0,
        refreshedEpisodeCovers:
            (json['refreshedEpisodeCovers'] as num?)?.toInt() ?? 0,
        cleanedEpisodePosters:
            (json['cleanedEpisodePosters'] as num?)?.toInt() ?? 0,
        totalSeasons: (json['totalSeasons'] as num?)?.toInt() ?? 0,
        totalEpisodes: (json['totalEpisodes'] as num?)?.toInt() ?? 0,
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
