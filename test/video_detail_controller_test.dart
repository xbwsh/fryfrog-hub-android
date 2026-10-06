import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fryfrog_hub/core/models/media_models.dart';
import 'package:fryfrog_hub/core/network/gateways.dart';
import 'package:fryfrog_hub/features/video/video_detail_controller.dart';

class _FakeVideoGateway implements VideoGateway {
  _FakeVideoGateway({this.detail});

  SeriesDetail? detail;
  List<VideoActorDto> actors = const [];
  int favoriteCalls = 0;
  bool lastFavorite = false;
  int watchedCalls = 0;
  int fetchCalls = 0;

  // Admin action recordings.
  int bindCalls = 0;
  int? lastBindVideoId;
  int? lastBindTmdbId;
  String? lastBindMediaType;
  int unbindCalls = 0;
  int? lastUnbindVideoId;
  final List<String> progressModules = [];
  bool progressRunning = false;
  List<LogoOption> logoOptions = const [];
  int seriesLogoOptionsCalls = 0;
  int? lastSeriesLogoOptionsId;
  int videoLogoOptionsCalls = 0;
  int setSeriesLogoCalls = 0;
  String? lastLogoFilePath;

  // TMDB 本集图片（横屏封面）候选
  List<CoverOption> coverOptions = const [];
  int setCoverCalls = 0;
  String? lastCoverFilePath;

  // TMDB 分层图片
  TmdbImageOptions tmdbImages = const TmdbImageOptions(level: 'episode');
  final List<String> fetchedLevels = [];
  int applyImageCalls = 0;
  (String, String, String)? lastImageSelection;

  @override
  Future<SeriesDetail> fetchSeriesDetail(int id, {String? type}) async {
    fetchCalls++;
    if (detail == null) throw Exception('missing');
    return detail!;
  }

  @override
  @override
  Future<VideoItem> fetchVideoDetail(int id) => throw UnimplementedError();

  @override
  Future<List<VideoActorDto>> fetchVideoActors(int id) async => actors;

  @override
  Future<void> saveWatchProgress(
    int videoId, {
    required double position,
    double? duration,
  }) async {}

  @override
  Future<void> setWatched(int videoId, {required bool completed}) async {
    watchedCalls++;
  }

  @override
  Future<void> deleteWatchProgress(int videoId) async {}

  @override
  Future<void> setSeriesFavorite(int id, {required bool status}) async {
    favoriteCalls++;
    lastFavorite = status;
    final d = detail;
    if (d != null) {
      detail = SeriesDetail(
        id: d.id,
        type: d.type,
        title: d.title,
        coverUrl: d.coverUrl,
        fanartUrl: d.fanartUrl,
        logoUrl: d.logoUrl,
        originalTitle: d.originalTitle,
        overview: d.overview,
        mediaType: d.mediaType,
        tmdbId: d.tmdbId,
        rating: d.rating,
        year: d.year,
        releaseDate: d.releaseDate,
        totalEpisodes: d.totalEpisodes,
        status: d.status,
        favorite: status,
        episodeCount: d.episodeCount,
        resolutions: d.resolutions,
        seasons: d.seasons,
      );
    }
  }

  @override
  String streamUrlFor(VideoItem video) => 'stream';

  @override
  Future<List<TmdbSearchItem>> searchTmdb(String q) async => const [];

  @override
  Future<void> bindTmdb(
    int videoId, {
    required int tmdbId,
    required String mediaType,
  }) async {
    bindCalls++;
    lastBindVideoId = videoId;
    lastBindTmdbId = tmdbId;
    lastBindMediaType = mediaType;
  }

  @override
  Future<int> unbindTmdb(int videoId) async {
    unbindCalls++;
    lastUnbindVideoId = videoId;
    return 1;
  }

  @override
  Future<ScrapeProgress> fetchScrapeProgress(String module) async {
    progressModules.add(module);
    return ScrapeProgress(stage: 'bind', running: progressRunning);
  }

  @override
  Future<void> updateSeriesMetadata(int id, Map<String, dynamic> body) async {}

  @override
  Future<void> updateVideoMetadata(int id, Map<String, dynamic> body) async {}

  @override
  Future<bool> downloadVideoCovers(int videoId) async => true;

  @override
  Future<List<CoverOption>> fetchVideoCoverOptions(int videoId) async =>
      coverOptions;

  @override
  Future<void> setVideoCover(int videoId, {required String filePath}) async {
    setCoverCalls++;
    lastCoverFilePath = filePath;
  }

  @override
  Future<TmdbImageOptions> fetchTmdbImages(
    int videoId, {
    required String level,
  }) async {
    fetchedLevels.add(level);
    return tmdbImages;
  }

  @override
  Future<void> applyTmdbImage(
    int videoId, {
    required String filePath,
    required String level,
    required String kind,
  }) async {
    applyImageCalls++;
    lastImageSelection = (filePath, level, kind);
  }

  @override
  Future<List<FrameCandidate>> generateFrameCandidates(int videoId) async =>
      const [];

  @override
  Future<void> selectFrame(
    int videoId, {
    required int index,
    required String type,
  }) async {}
  @override
  Future<Uint8List> fetchImageBytes(String path) async => Uint8List(0);

  @override
  Future<String> uploadCover(
    int videoId, {
    required Uint8List bytes,
    required String filename,
    required String level,
    required String kind,
  }) async => '/tmp/cover.jpg';


  @override
  Future<SeasonRefreshResult> refreshSeasonCovers(int seriesId) async =>
      const SeasonRefreshResult();

  @override
  Future<bool> refreshVideoLogo(int videoId) async => true;

  @override
  Future<bool> refreshSeriesLogo(int seriesId) async => true;

  @override
  Future<List<LogoOption>> fetchVideoLogoOptions(int videoId) async {
    videoLogoOptionsCalls++;
    return logoOptions;
  }

  @override
  Future<List<LogoOption>> fetchSeriesLogoOptions(int seriesId) async {
    seriesLogoOptionsCalls++;
    lastSeriesLogoOptionsId = seriesId;
    return logoOptions;
  }

  @override
  Future<void> setVideoLogo(int videoId, {required String filePath}) async {
    lastLogoFilePath = filePath;
  }

  @override
  Future<void> setSeriesLogo(int seriesId, {required String filePath}) async {
    setSeriesLogoCalls++;
    lastLogoFilePath = filePath;
  }
}

SeriesDetail _detail({bool favorite = false, List<VideoItem>? eps, int? tmdbId}) {
  return SeriesDetail(
    id: 1,
    type: 'series',
    title: 'Show',
    favorite: favorite,
    tmdbId: tmdbId,
    seasons: [
      SeasonInfo(
        seasonNumber: 1,
        episodes:
            eps ??
            const [
              VideoItem(id: 10, title: 'A'),
              VideoItem(id: 11, title: 'B'),
            ],
      ),
    ],
  );
}

void main() {
  test('load picks resume episode and exposes detail', () async {
    final gw = _FakeVideoGateway(
      detail: _detail(
        eps: const [
          VideoItem(id: 10, title: 'A', watched: true),
          VideoItem(id: 11, title: 'B', watchProgressPercent: 40),
          VideoItem(id: 12, title: 'C'),
        ],
      ),
    );
    final c = VideoDetailController(
      gateway: gw,
      item: const SeriesListDto(id: 1, type: 'series', title: 'Show'),
    );
    expect(c.loading, isTrue);
    await c.load();
    expect(c.loading, isFalse);
    expect(c.error, isNull);
    expect(c.detail!.title, 'Show');
    expect(c.selected!.id, 11);
    c.dispose();
  });

  test('toggleFavorite flips status', () async {
    final gw = _FakeVideoGateway(detail: _detail(favorite: false));
    final c = VideoDetailController(
      gateway: gw,
      item: const SeriesListDto(id: 1, type: 'series', title: 'Show'),
    );
    await c.load();
    await c.toggleFavorite();
    expect(gw.favoriteCalls, 1);
    expect(gw.lastFavorite, isTrue);
    expect(c.detail!.favorite, isTrue);
    c.dispose();
  });

  test('load error surfaces message', () async {
    final gw = _FakeVideoGateway(detail: null);
    final c = VideoDetailController(
      gateway: gw,
      item: const SeriesListDto(id: 9, type: 'standalone', title: 'X'),
    );
    await c.load();
    expect(c.loading, isFalse);
    expect(c.error, isNotNull);
    c.dispose();
  });

  test('unbind targets selected video id and refreshes detail', () async {
    final gw = _FakeVideoGateway(detail: _detail(tmdbId: 77));
    final c = VideoDetailController(
      gateway: gw,
      item: const SeriesListDto(id: 1, type: 'series', title: 'Show'),
    );
    await c.load();
    expect(gw.fetchCalls, 1);

    final unbound = await c.unbind();

    expect(unbound, 1);
    expect(gw.unbindCalls, 1);
    expect(gw.lastUnbindVideoId, 10); // selected episode, not the series id
    expect(gw.fetchCalls, 2); // refreshQuiet ran
    expect(c.busy, isFalse);
    c.dispose();
  });

  test('bindTmdbWithPoll posts bind then polls progress once', () async {
    final gw = _FakeVideoGateway(detail: _detail(tmdbId: null))
      ..progressRunning = false;
    final c = VideoDetailController(
      gateway: gw,
      item: const SeriesListDto(id: 1, type: 'series', title: 'Show'),
    );
    await c.load();

    await c.bindTmdbWithPoll(tmdbId: 500, mediaType: 'tv');

    expect(gw.bindCalls, 1);
    expect(gw.lastBindVideoId, 10);
    expect(gw.lastBindTmdbId, 500);
    expect(gw.lastBindMediaType, 'tv');
    expect(gw.progressModules, ['bind:10']);
    expect(gw.fetchCalls, 2); // load + post-bind refreshQuiet
    expect(c.busy, isFalse);
    c.dispose();
  });

  test('mutated 只在写操作后置位，返回上级据此决定是否重载', () async {
    final gw = _FakeVideoGateway(detail: _detail(tmdbId: null));
    final c = VideoDetailController(
      gateway: gw,
      item: const SeriesListDto(id: 1, type: 'series', title: 'Show'),
    );
    await c.load();
    expect(c.mutated, isFalse, reason: '只读加载不该标记为已变更');

    await c.toggleFavorite();
    expect(c.mutated, isFalse, reason: '收藏不影响列表显示，无需重载');

    await c.bindTmdbWithPoll(tmdbId: 500, mediaType: 'tv');
    expect(c.mutated, isTrue, reason: '绑定会改标题，必须让列表重载');

    c.dispose();
  });

  test('unbind 也标记 mutated', () async {
    final gw = _FakeVideoGateway(detail: _detail(tmdbId: 77));
    final c = VideoDetailController(
      gateway: gw,
      item: const SeriesListDto(id: 1, type: 'series', title: 'Show'),
    );
    await c.load();
    await c.unbind();
    expect(c.mutated, isTrue);
    c.dispose();
  });

  test('fetchCoverOptions 透传候选，applyCover 提交选中图并标记 mutated', () async {
    final gw = _FakeVideoGateway(detail: _detail(tmdbId: 77))
      ..coverOptions = const [
        CoverOption(filePath: '/a.jpg', url: '/proxy?path=/a.jpg', width: 1920, height: 1080),
        CoverOption(filePath: '/b.jpg', url: '/proxy?path=/b.jpg'),
      ];
    final c = VideoDetailController(
      gateway: gw,
      item: const SeriesListDto(id: 1, type: 'series', title: 'Show'),
    );
    await c.load();
    expect(c.mutated, isFalse);

    final options = await c.fetchCoverOptions();
    expect(options, hasLength(2));
    expect(options.first.filePath, '/a.jpg');
    expect(options.first.sizeLabel, '1920×1080');
    expect(c.mutated, isFalse, reason: '只读列候选不该标记已变更');

    await c.applyCover('/b.jpg');
    expect(gw.setCoverCalls, 1);
    expect(gw.lastCoverFilePath, '/b.jpg');
    expect(c.mutated, isTrue, reason: '换封面后列表需要重载');
    expect(c.busy, isFalse);
    c.dispose();
  });

  test('fetchTmdbImages 按层级取图，applyTmdbImage 提交并标记 mutated', () async {
    final gw = _FakeVideoGateway(detail: _detail(tmdbId: 77))
      ..tmdbImages = const TmdbImageOptions(
        level: 'series',
        poster: [CoverOption(filePath: '/p1.jpg', width: 1000, height: 1500)],
        backdrop: [CoverOption(filePath: '/b1.jpg', width: 1920, height: 1080)],
      );
    final c = VideoDetailController(
      gateway: gw,
      item: const SeriesListDto(id: 1, type: 'series', title: 'Show'),
    );
    await c.load();
    expect(c.mutated, isFalse);

    final options = await c.fetchTmdbImages('series');
    expect(gw.fetchedLevels, ['series']);
    expect(options.byKind('poster'), hasLength(1));
    expect(options.byKind('backdrop'), hasLength(1));
    expect(options.byKind('still'), isEmpty);
    expect(c.mutated, isFalse, reason: '只读列候选不该标记已变更');

    await c.applyTmdbImage('/b1.jpg', 'series', 'backdrop');
    expect(gw.applyImageCalls, 1);
    expect(gw.lastImageSelection, ('/b1.jpg', 'series', 'backdrop'));
    expect(c.mutated, isTrue);
    expect(c.busy, isFalse);
    c.dispose();
  });

  test('isEpisodeTarget 区分分集与单片（决定是否给出季/单集层级）', () async {
    // 剧集：item.type=series → 允许季/单集层级
    final ep = VideoItem(
      id: 5,
      title: 'E1',
      isSeries: true,
      seasonNumber: 1,
      episodeNumber: 7,
    );
    final seriesGw = _FakeVideoGateway(detail: _detail(eps: [ep]));
    final c1 = VideoDetailController(
      gateway: seriesGw,
      item: const SeriesListDto(id: 1, type: 'series', title: 'Show'),
    );
    await c1.load();
    expect(c1.isEpisodeTarget, isTrue);
    expect(c1.targetSeasonNumber, 1);
    expect(c1.targetEpisodeNumber, 7);
    c1.dispose();

    // 单片：item.type=standalone → 只给总览层级
    final movieGw = _FakeVideoGateway(detail: _detail(eps: const []));
    final c2 = VideoDetailController(
      gateway: movieGw,
      item: const SeriesListDto(id: 2, type: 'standalone', title: 'Movie'),
    );
    await c2.load();
    expect(c2.isEpisodeTarget, isFalse, reason: '单片不该给出季/单集层级');
    c2.dispose();
  });

  test('fetchLogoOptions routes to the series endpoint', () async {
    const option = LogoOption(
      filePath: '/tmp/logo.png',
      iso6391: 'zh',
      width: 400,
      height: 80,
      url: '/api/v1/video/tmdb-image-proxy?path=/l.png',
    );
    final gw = _FakeVideoGateway(detail: _detail(tmdbId: 77))
      ..logoOptions = const [option];
    final c = VideoDetailController(
      gateway: gw,
      item: const SeriesListDto(id: 1, type: 'series', title: 'Show'),
    );
    await c.load();

    final options = await c.fetchLogoOptions();

    expect(gw.seriesLogoOptionsCalls, 1);
    expect(gw.lastSeriesLogoOptionsId, 1);
    expect(gw.videoLogoOptionsCalls, 0);
    expect(options, hasLength(1));
    expect(options.single.filePath, '/tmp/logo.png');
    expect(c.busy, isFalse);
    c.dispose();
  });
}
