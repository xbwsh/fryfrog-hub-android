import 'common.dart';

/// Music catalog DTOs.

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

  String get coverPath => (coverUrl != null && coverUrl!.isNotEmpty)
      ? coverUrl!
      : '/api/v1/music/albums/$id/cover';

  factory MusicAlbum.fromJson(Map<String, dynamic> json) => MusicAlbum(
    id: (json['id'] as num?)?.toInt() ?? 0,
    title: json['title'] as String? ?? '',
    artistName: (json['artistName'] ?? json['artist']) as String?,
    artistId: (json['artistId'] as num?)?.toInt(),
    year: (json['year'] as num?)?.toInt(),
    genre: json['genre'] as String?,
    coverUrl: readCoverJson(json),
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

  String get coverPath => (coverUrl != null && coverUrl!.isNotEmpty)
      ? coverUrl!
      : '/api/v1/music/artists/$id/cover';

  factory MusicArtist.fromJson(Map<String, dynamic> json) => MusicArtist(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    coverUrl: readCoverJson(json),
    albumCount: (json['albumCount'] as num?)?.toInt() ?? 0,
  );
}

class MusicSong {
  const MusicSong({
    required this.id,
    required this.title,
    this.artistName,
    this.albumName,
    this.albumId,
    this.trackNumber,
    this.durationSeconds,
    this.coverUrl,
    this.streamUrl,
  });

  final int id;
  final String title;
  final String? artistName;
  final String? albumName;
  final int? albumId;
  final int? trackNumber;
  final double? durationSeconds;
  final String? coverUrl;
  final String? streamUrl;

  String get coverPath => (coverUrl != null && coverUrl!.isNotEmpty)
      ? coverUrl!
      : '/api/v1/music/songs/$id/cover';

  factory MusicSong.fromJson(Map<String, dynamic> json) => MusicSong(
    id: (json['id'] as num?)?.toInt() ?? 0,
    title: (json['title'] ?? json['name']) as String? ?? '',
    artistName: (json['artistName'] ?? json['artist']) as String?,
    albumName: (json['albumName'] ?? json['album']) as String?,
    albumId: (json['albumId'] as num?)?.toInt(),
    trackNumber: (json['trackNumber'] as num?)?.toInt(),
    durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
    coverUrl: readCoverJson(json),
    streamUrl: (json['streamUrl'] ?? json['stream']) as String?,
  );
}
