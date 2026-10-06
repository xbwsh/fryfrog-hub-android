/// Port for video detail + progress use-cases.
/// UI/Controllers depend on this — not on `ApiClient`.
///
/// `ApiVideoGateway` adapts `ApiClient` (infra) to this port.
library;

import '../models/media_models.dart';

abstract class VideoGateway {
  Future<SeriesDetail> fetchSeriesDetail(int id, {String? type});

  Future<VideoItem> fetchVideoDetail(int id);

  Future<List<VideoActorDto>> fetchVideoActors(int id);

  Future<void> saveWatchProgress(
    int videoId, {
    required double position,
    double? duration,
  });

  Future<void> setWatched(int videoId, {required bool completed});

  Future<void> deleteWatchProgress(int videoId);

  Future<void> setSeriesFavorite(int id, {required bool status});

  String streamUrlFor(VideoItem video);

  // ── Admin: TMDB binding / metadata / covers / logo ───────────────────

  Future<List<TmdbSearchItem>> searchTmdb(String q);

  /// Async job — poll [fetchScrapeProgress] with `bind:{videoId}` after.
  Future<void> bindTmdb(
    int videoId, {
    required int tmdbId,
    required String mediaType,
  });

  /// Returns how many rows were unbound (`data.unbound`).
  Future<int> unbindTmdb(int videoId);

  Future<ScrapeProgress> fetchScrapeProgress(String module);

  Future<void> updateSeriesMetadata(int id, Map<String, dynamic> body);

  Future<void> updateVideoMetadata(int id, Map<String, dynamic> body);

  Future<bool> downloadVideoCovers(int videoId);

  /// 本集在 TMDB 的横屏图（本集剧照 still）候选；空列表 = 没有候选。
  Future<List<CoverOption>> fetchVideoCoverOptions(int videoId);

  /// 把选中的 TMDB 图应用为本集横屏封面（落 fanart.jpg）。
  Future<void> setVideoCover(int videoId, {required String filePath});

  Future<List<FrameCandidate>> generateFrameCandidates(int videoId);

  /// [type] = poster | fanart.
  Future<void> selectFrame(
    int videoId, {
    required int index,
    required String type,
  });

  /// Long-running (300s timeout server-side).
  Future<SeasonRefreshResult> refreshSeasonCovers(int seriesId);

  Future<bool> refreshVideoLogo(int videoId);

  Future<bool> refreshSeriesLogo(int seriesId);

  Future<List<LogoOption>> fetchVideoLogoOptions(int videoId);

  Future<List<LogoOption>> fetchSeriesLogoOptions(int seriesId);

  Future<void> setVideoLogo(int videoId, {required String filePath});

  Future<void> setSeriesLogo(int seriesId, {required String filePath});
}

/// Port for comic chapter pages + reading progress.
abstract class ComicGateway {
  Future<List<String>> fetchChapterPages(int chapterId);

  Future<void> saveReadingProgress(
    int comicId, {
    required int chapterIndex,
    required int pageIndex,
  });
}

/// Port for TXT ebook chapters + reading progress.
abstract class EbookGateway {
  Future<List<BookChapter>> fetchChapters(int bookId);

  Future<EbookChapterContent> fetchChapterContent(
    int bookId, {
    required int chapterIndex,
  });

  Future<void> saveProgress(
    int bookId, {
    required double positionPercent,
    required int chapterIndex,
  });
}

/// Port for media library admin (list / CRUD / browse / scan).
abstract class MediaLibraryGateway {
  Future<List<MediaLibrary>> fetchLibraries();

  Future<MediaLibrary> createLibrary({
    required String name,
    required String path,
    String? subType,
    required bool enabled,
    bool enableScraping = true,
    bool isAdult = false,
    String? description,
  });

  Future<MediaLibrary> updateLibrary(
    int id, {
    String? name,
    String? path,
    String? subType,
    bool? enabled,
    bool? enableScraping,
    bool? isAdult,
    String? description,
  });

  Future<void> deleteLibrary(int id);

  Future<MediaLibrary> toggleLibrary(int id);

  /// Starts a scan of every enabled library; returns enabled library count.
  Future<int> scanAll();

  Future<void> scanOne(int id);

  Future<List<LibraryScanProgress>> fetchScanProgress();

  Future<LibraryPipelineProgress> fetchPipelineProgress(int id);

  /// Null/empty [path] lists the server's disk roots.
  Future<List<LibraryDirItem>> browse({String? path});
}
