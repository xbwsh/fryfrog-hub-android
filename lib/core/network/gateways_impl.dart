import '../models/media_models.dart';
import 'api_client.dart';
import 'gateways.dart';

/// Infra adapter: `ApiClient` → [VideoGateway] / [ComicGateway].
class ApiVideoGateway implements VideoGateway {
  ApiVideoGateway(this._api);

  final ApiClient _api;

  @override
  Future<SeriesDetail> fetchSeriesDetail(int id, {String? type}) =>
      _api.fetchSeriesDetail(id, type: type);

  @override
  Future<VideoItem> fetchVideoDetail(int id) => _api.fetchVideoDetail(id);

  @override
  Future<List<VideoActorDto>> fetchVideoActors(int id) =>
      _api.fetchVideoActors(id);

  @override
  Future<void> saveWatchProgress(
    int videoId, {
    required double position,
    double? duration,
  }) => _api
      .saveWatchProgress(videoId, position: position, duration: duration)
      .then((_) {});

  @override
  Future<void> setWatched(int videoId, {required bool completed}) =>
      _api.setWatched(videoId, completed: completed).then((_) {});

  @override
  Future<void> deleteWatchProgress(int videoId) =>
      _api.deleteWatchProgress(videoId);

  @override
  Future<void> setSeriesFavorite(int id, {required bool status}) =>
      _api.setSeriesFavorite(id, status: status);

  @override
  String streamUrlFor(VideoItem video) => _api.videoStreamUrl(video);

  @override
  Future<List<TmdbSearchItem>> searchTmdb(String q) => _api.searchTmdb(q);

  @override
  Future<void> bindTmdb(
    int videoId, {
    required int tmdbId,
    required String mediaType,
  }) => _api.bindTmdb(videoId, tmdbId: tmdbId, mediaType: mediaType);

  @override
  Future<void> refreshTmdbMetadata(int videoId) =>
      _api.refreshTmdbMetadata(videoId);

  @override
  Future<int> unbindTmdb(int videoId) => _api.unbindTmdb(videoId);

  @override
  Future<ScrapeProgress> fetchScrapeProgress(String module) =>
      _api.fetchScrapeProgress(module);

  @override
  Future<void> updateSeriesMetadata(int id, Map<String, dynamic> body) =>
      _api.updateSeriesMetadata(id, body);

  @override
  Future<void> updateVideoMetadata(int id, Map<String, dynamic> body) =>
      _api.updateVideoMetadata(id, body);

  @override
  Future<bool> downloadVideoCovers(int videoId) =>
      _api.downloadVideoCovers(videoId);

  @override
  Future<List<FrameCandidate>> generateFrameCandidates(int videoId) =>
      _api.generateFrameCandidates(videoId);

  @override
  Future<void> selectFrame(
    int videoId, {
    required int index,
    required String type,
  }) => _api.selectFrame(videoId, index: index, type: type);

  @override
  Future<SeasonRefreshResult> refreshSeasonCovers(int seriesId) =>
      _api.refreshSeasonCovers(seriesId);

  @override
  Future<bool> refreshVideoLogo(int videoId) => _api.refreshVideoLogo(videoId);

  @override
  Future<bool> refreshSeriesLogo(int seriesId) =>
      _api.refreshSeriesLogo(seriesId);

  @override
  Future<List<LogoOption>> fetchVideoLogoOptions(int videoId) =>
      _api.fetchVideoLogoOptions(videoId);

  @override
  Future<List<LogoOption>> fetchSeriesLogoOptions(int seriesId) =>
      _api.fetchSeriesLogoOptions(seriesId);

  @override
  Future<void> setVideoLogo(int videoId, {required String filePath}) =>
      _api.setVideoLogo(videoId, filePath: filePath);

  @override
  Future<void> setSeriesLogo(int seriesId, {required String filePath}) =>
      _api.setSeriesLogo(seriesId, filePath: filePath);
}

class ApiComicGateway implements ComicGateway {
  ApiComicGateway(this._api);

  final ApiClient _api;

  @override
  Future<List<String>> fetchChapterPages(int chapterId) =>
      _api.fetchComicChapterPages(chapterId);

  @override
  Future<void> saveReadingProgress(
    int comicId, {
    required int chapterIndex,
    required int pageIndex,
  }) => _api
      .saveComicProgress(
        comicId,
        chapterIndex: chapterIndex,
        pageIndex: pageIndex,
      )
      .then((_) {});
}

class ApiEbookGateway implements EbookGateway {
  ApiEbookGateway(this._api);

  final ApiClient _api;

  @override
  Future<List<BookChapter>> fetchChapters(int bookId) =>
      _api.fetchEbookChapters(bookId);

  @override
  Future<EbookChapterContent> fetchChapterContent(
    int bookId, {
    required int chapterIndex,
  }) => _api.fetchEbookChapterContent(bookId, chapterIndex: chapterIndex);

  @override
  Future<void> saveProgress(
    int bookId, {
    required double positionPercent,
    required int chapterIndex,
  }) => _api
      .saveEbookProgress(
        bookId,
        positionPercent: positionPercent,
        chapterIndex: chapterIndex,
      );
}

class ApiMediaLibraryGateway implements MediaLibraryGateway {
  ApiMediaLibraryGateway(this._api);

  final ApiClient _api;

  @override
  Future<List<MediaLibrary>> fetchLibraries() => _api.fetchMediaLibraries();

  @override
  Future<MediaLibrary> createLibrary({
    required String name,
    required String path,
    String? subType,
    required bool enabled,
    String? description,
  }) => _api.createMediaLibrary(
    name: name,
    path: path,
    subType: subType,
    enabled: enabled,
    description: description,
  );

  @override
  Future<MediaLibrary> updateLibrary(
    int id, {
    String? name,
    String? path,
    String? subType,
    bool? enabled,
    String? description,
  }) => _api.updateMediaLibrary(
    id,
    name: name,
    path: path,
    subType: subType,
    enabled: enabled,
    description: description,
  );

  @override
  Future<void> deleteLibrary(int id) => _api.deleteMediaLibrary(id);

  @override
  Future<MediaLibrary> toggleLibrary(int id) => _api.toggleMediaLibrary(id);

  @override
  Future<int> scanAll() => _api.scanAllMediaLibraries();

  @override
  Future<void> scanOne(int id) => _api.scanMediaLibrary(id);

  @override
  Future<List<LibraryScanProgress>> fetchScanProgress() =>
      _api.fetchLibraryScanProgress();

  @override
  Future<LibraryPipelineProgress> fetchPipelineProgress(int id) =>
      _api.fetchLibraryPipelineProgress(id);

  @override
  Future<List<LibraryDirItem>> browse({String? path}) =>
      _api.browseLibraryDirs(path: path);
}
