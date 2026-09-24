/// DTOs matching fryfrog-hub-api / apple models.
class ApiResponse<T> {
  ApiResponse({required this.success, this.message, this.data});
  final bool success;
  final String? message;
  final T? data;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T? Function(Object? raw) parseData,
  ) =>
      ApiResponse(
        success: json['success'] == true,
        message: json['message'] as String?,
        data: parseData(json['data']),
      );
}

class PageResponse<T> {
  PageResponse({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  factory PageResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parseItem,
  ) {
    final raw = json['content'] as List? ?? const [];
    return PageResponse(
      content: raw
          .whereType<Map<String, dynamic>>()
          .map(parseItem)
          .toList(growable: false),
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 0,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    );
  }
}

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

  String get displayTitle =>
      (title != null && title!.isNotEmpty) ? title! : (originalTitle ?? '(未命名)');
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

class MusicLibraryGroup {
  MusicLibraryGroup({
    required this.libraryId,
    required this.libraryName,
    required this.albums,
    required this.artists,
  });

  final int libraryId;
  final String libraryName;
  final List<MusicAlbum> albums;
  final List<MusicArtist> artists;

  factory MusicLibraryGroup.fromJson(Map<String, dynamic> json) {
    List<MusicAlbum> parseAlbums(Object? raw) => (raw as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MusicAlbum.fromJson)
        .toList(growable: false);
    List<MusicArtist> parseArtists(Object? raw) => (raw as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MusicArtist.fromJson)
        .toList(growable: false);
    return MusicLibraryGroup(
      libraryId: (json['libraryId'] as num?)?.toInt() ?? 0,
      libraryName: json['libraryName'] as String? ?? '',
      albums: parseAlbums(json['albums']),
      artists: parseArtists(json['artists']),
    );
  }
}

class MusicAlbum {
  const MusicAlbum({
    required this.id,
    required this.title,
    this.artistName,
    this.artistId,
    this.year,
    this.genre,
    this.coverUrl,
    this.trackCount,
  });

  final int id;
  final String title;
  final String? artistName;
  final int? artistId;
  final int? year;
  final String? genre;
  final String? coverUrl;
  final int? trackCount;

  factory MusicAlbum.fromJson(Map<String, dynamic> json) => MusicAlbum(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? '',
        artistName: json['artistName'] as String?,
        artistId: (json['artistId'] as num?)?.toInt(),
        year: (json['year'] as num?)?.toInt(),
        genre: json['genre'] as String?,
        coverUrl: json['coverUrl'] as String?,
        trackCount: (json['trackCount'] as num?)?.toInt(),
      );
}

class MusicArtist {
  const MusicArtist({
    required this.id,
    required this.name,
    this.coverUrl,
    this.albumCount = 0,
  });

  final int id;
  final String name;
  final String? coverUrl;
  final int albumCount;

  factory MusicArtist.fromJson(Map<String, dynamic> json) => MusicArtist(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        coverUrl: json['coverUrl'] as String?,
        albumCount: (json['albumCount'] as num?)?.toInt() ?? 0,
      );
}

class MusicSong {
  const MusicSong({
    required this.id,
    required this.title,
    this.artistName,
    this.albumName,
    this.trackNumber,
    this.durationSeconds,
    this.coverUrl,
    this.streamUrl,
  });

  final int id;
  final String title;
  final String? artistName;
  final String? albumName;
  final int? trackNumber;
  final double? durationSeconds;
  final String? coverUrl;
  final String? streamUrl;

  factory MusicSong.fromJson(Map<String, dynamic> json) => MusicSong(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? '',
        artistName: json['artistName'] as String?,
        albumName: json['albumName'] as String?,
        trackNumber: (json['trackNumber'] as num?)?.toInt(),
        durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
        coverUrl: json['coverUrl'] as String?,
        streamUrl: json['streamUrl'] as String?,
      );
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    this.nickname,
    this.avatar,
    this.role,
    this.enabled,
  });

  final int id;
  final String username;
  final String? nickname;
  final String? avatar;
  final String? role;
  final bool? enabled;

  bool get isAdmin => role?.toUpperCase() == 'ADMIN';
  String get roleText => isAdmin ? '管理员' : '普通用户';
  String get title =>
      (nickname != null && nickname!.isNotEmpty) ? nickname! : username;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: (json['id'] as num?)?.toInt() ?? 0,
        username: json['username'] as String? ?? '',
        nickname: json['nickname'] as String?,
        avatar: json['avatar'] as String?,
        role: json['role'] as String?,
        enabled: json['enabled'] as bool?,
      );
}
