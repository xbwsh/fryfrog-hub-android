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
    String? description,
  });

  Future<MediaLibrary> updateLibrary(
    int id, {
    String? name,
    String? path,
    String? subType,
    bool? enabled,
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
