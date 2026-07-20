package com.fryfrog.hub.data.model

import com.google.gson.annotations.SerializedName

data class ApiResponse<T>(
    val success: Boolean,
    val message: String?,
    val data: T?
)

data class LoginResponse(
    val success: Boolean,
    val message: String?,
    val token: String?
)

data class PageResponse<T>(
    val content: List<T>,
    val page: Int,
    val size: Int,
    val totalElements: Long,
    val totalPages: Int
)

// Video Series
data class SeriesDTO(
    val id: Long,
    val type: String?,
    val title: String,
    val coverUrl: String?,
    val fanartUrl: String?,
    val originalTitle: String?,
    val overview: String?,
    val mediaType: String?,
    val tmdbId: Long?,
    val rating: Double?,
    val year: Int?,
    val seasonNumber: Int?,
    val numberOfSeasons: Int?,
    val totalEpisodes: Int?,
    val status: String?,
    val isAdult: Boolean?,
    val episodeCount: Int?,
    val episodes: List<VideoDTO>?
)

data class VideoDTO(
    val id: Long,
    val title: String,
    val filePath: String?,
    val seriesId: Long?,
    val seasonNumber: Int?,
    val episodeNumber: Int?,
    val overview: String?,
    val rating: Double?,
    val year: Int?,
    val durationMinutes: Int?,
    val watched: Boolean?,
    val progress: Double?,
    val coverUrl: String?,
    val fanartUrl: String?,
    val originalTitle: String?,
    val director: String?,
    val actors: String?,
    val genre: String?,
    val fileName: String?,
    val fileSize: Long?,
    val videoCodec: String?,
    val audioCodec: String?,
    val resolution: String?,
    val frameRate: Double?,
    val bitrateKbps: Int?,
    val format: String?,
    val favorite: Boolean?,
    val tmdbId: Long?,
    val mediaType: String?,
    val isAdult: Boolean?,
    val streamUrl: String?
)

data class VideoActor(
    val id: Long,
    val name: String,
    val character: String?,
    val imageUrl: String?
)

// Music
data class AlbumGroup(
    val artist: String?,
    val album: String?,
    val coverUrl: String?,
    val year: Int?,
    val tracks: List<MusicTrack>?
)

data class MusicTrack(
    val id: Long,
    val title: String,
    val artist: String?,
    val album: String?,
    val duration: Long?,
    val filePath: String?,
    val coverUrl: String?,
    val trackNumber: Int?,
    val year: Int?,
    val genre: String?,
    val favorite: Boolean?
)

// Comic
data class ComicSeries(
    val seriesId: Long?,
    val name: String?,
    val coverUrl: String?,
    val author: String?,
    val hasCover: Boolean?,
    val volumeCount: Int?,
    val seriesSummary: String?,
    val serializationStart: String?,
    val comics: List<ComicDTO>?
)

data class ComicDTO(
    val id: Long,
    val title: String,
    val author: String?,
    val series: String?,
    val volume: Int?,
    val year: Int?,
    val genre: String?,
    val summary: String?,
    val fileName: String?,
    val fileSize: Long?,
    val pageCount: Int?,
    val format: String?,
    val favorite: Boolean?,
    val coverUrl: String?,
    val rating: Double?
)

// Ebook
data class EbookSeries(
    val seriesId: Long?,
    val name: String?,
    val coverUrl: String?,
    val author: String?,
    val hasCover: Boolean?,
    val volumeCount: Int?,
    val seriesSummary: String?,
    val books: List<EbookDTO>?
)

data class EbookDTO(
    val id: Long,
    val title: String,
    val author: String?,
    val series: String?,
    val volume: Int?,
    val year: Int?,
    val genre: String?,
    val summary: String?,
    val fileName: String?,
    val fileSize: Long?,
    val pageCount: Int?,
    val format: String?,
    val favorite: Boolean?,
    val coverUrl: String?,
    val rating: Double?
)

// Character (通用角色模型，用于漫画和电子书)
data class MediaCharacter(
    val id: Long,
    val name: String,
    val originalName: String?,
    val description: String?,
    val role: String?,
    val sourceCharacterId: Long?,
    val source: String?,
    val imageUrl: String?
)
