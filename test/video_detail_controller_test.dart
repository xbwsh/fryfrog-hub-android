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

  @override
  Future<SeriesDetail> fetchSeriesDetail(int id, {String? type}) async {
    if (detail == null) throw Exception('missing');
    return detail!;
  }

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
}

SeriesDetail _detail({bool favorite = false, List<VideoItem>? eps}) {
  return SeriesDetail(
    id: 1,
    type: 'series',
    title: 'Show',
    favorite: favorite,
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
}
