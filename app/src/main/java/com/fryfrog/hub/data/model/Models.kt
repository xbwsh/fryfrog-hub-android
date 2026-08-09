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
    val logoUrl: String? = null,
    val originalTitle: String?,
    val overview: String?,
    val mediaType: String?,
    val tmdbId: Long?,
    val tmdbTitle: String? = null,
    val rating: Double?,
    val year: Int?,
    val releaseDate: String? = null,
    val seasonNumber: Int?,
    val numberOfSeasons: Int?,
    val totalEpisodes: Int?,
    val status: String?,
    val isAdult: Boolean?,
    val favorite: Boolean? = null,
    val originalFileName: String?,
    val episodeCount: Int?,
    val seasons: List<SeasonDTO>?,
    val episodes: List<VideoDTO>?,
    // 系列/电影的分辨率标签（去重 + 清晰度降序，如 ["4K", "1080p"]）
    val resolutions: List<String>? = null
)

data class SeasonDTO(
    val seasonNumber: Int,
    val coverUrl: String? = null,
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
    val releaseDate: String? = null,
    val durationMinutes: Int?,
    val watched: Boolean?,
    val progress: Double?,
    val coverUrl: String?,
    val fanartUrl: String?,
    val logoUrl: String? = null,
    val originalTitle: String?,
    val director: String?,
    val actors: String?,
    val genre: String?,
    val fileName: String?,
    val fileSize: Long?,
    val videoCodec: String?,
    val audioCodec: String?,
    val resolution: String?,
    // 展示标签（如 "4K"），null = 未探测到分辨率
    val resolutionLabel: String? = null,
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

// Subtitle
data class SubtitleDTO(
    val filename: String,
    val language: String?,
    val url: String?
)

// Watch Progress
data class WatchProgressRequest(
    val position: Double,
    val duration: Double? = null,
    val completed: Boolean? = null
)

data class WatchProgressDTO(
    val videoId: Long,
    val positionSeconds: Double,
    val durationSeconds: Double,
    val completed: Boolean,
    val progressPercent: Double,
    val updatedAt: String?
)

// Media Library
data class MediaLibrary(
    val id: Long,
    val name: String,
    val path: String,
    val type: String,
    val subType: String?,
    val enabled: Boolean,
    val enableScraping: Boolean? = null,
    val isAdult: Boolean? = null,
    val sortOrder: Int?,
    val description: String?,
    val createdAt: String?,
    val updatedAt: String?
)

// TMDB Scraping
data class TmdbSearchResult(
    val id: Long,
    val title: String,
    @SerializedName("original_title") val originalTitle: String?,
    val overview: String?,
    @SerializedName("release_date") val releaseDate: String?,
    @SerializedName("poster_path") val posterPath: String?,
    @SerializedName("backdrop_path") val backdropPath: String?,
    @SerializedName("vote_average") val voteAverage: Double?,
    @SerializedName("media_type") val mediaType: String?,
    @SerializedName("genre_ids") val genreIds: List<Int>?
)

data class TmdbBindRequest(
    val tmdbId: Long,
    val mediaType: String
)

// Library Grouped Videos
data class LibraryGroup(
    val libraryId: Long?,
    val libraryName: String,
    val libraryPath: String? = null,
    val subType: String? = null,
    val series: List<SeriesDTO>,
    val standaloneVideos: List<SeriesDTO>,
    val seriesCount: Int,
    val standaloneCount: Int
)

// 视频刮削进度（module 形如 "supplement:{libraryId}" / "adult:{libraryId}" / "adult:all"）
data class ScrapeProgress(
    val module: String?,
    val stage: String?,
    val running: Boolean,
    val total: Int,
    val completed: Int,
    val failed: Int,
    val skipped: Int,
    val pending: Int,
    val percent: Double,
    val currentItem: String?,
    val startedAt: String?,
    val updatedAt: String?
)

// 封面候选帧
data class FrameCandidate(
    val index: Int,
    val position: Int,
    val url: String?
)

data class GenerateFramesResponse(
    val videoId: Long,
    val total: Int,
    val candidates: List<FrameCandidate>? = emptyList()
)

data class SelectFrameRequest(
    val index: Int,
    val type: String
)

data class SelectFrameResponse(
    val videoId: Long,
    val type: String?,
    val path: String?
)

// 编辑元数据（局部更新：null 字段不提交，Gson 默认省略）
data class UpdateMetadataRequest(
    val title: String? = null,
    val overview: String? = null,
    val rating: Double? = null,
    val year: Int? = null,
    val releaseDate: String? = null,
    val originalTitle: String? = null,
    val genre: String? = null,
    val director: String? = null,
    val actors: String? = null,
    val tags: String? = null,
    val status: String? = null
)

// 追更日历条目
data class SeriesCalendarItem(
    val seriesId: Long,
    val title: String,
    val coverUrl: String?,
    val fanartUrl: String?,
    val nextEpisodeDate: String?,
    val nextEpisodeNumber: String?
)

// 单系列 Logo 补全（downloaded=false 表示本地已有或未找到）
data class RefreshLogoResponse(
    val downloaded: Boolean,
    val logoUrl: String?
)

// Logo 可选列表（logo-options 接口），url 直接用于预览
data class LogoOption(
    val filePath: String,
    val iso6391: String? = null,
    val width: Int? = null,
    val height: Int? = null,
    val voteCount: Int? = null,
    val url: String? = null
)

// 设置选中 Logo（POST /logo，body: {filePath}）
data class LogoSetRequest(
    val filePath: String
)

// 批量 Logo 补全（异步提交，module 固定 "logo:all"，total = 系列+电影合并总数）
data class RefreshAllLogosResponse(
    val totalSeries: Int? = null,
    val totalMovies: Int? = null,
    val total: Int? = null,
    val status: String?,
    val module: String? = null
)

// 批量补分辨率（异步提交，module 形如 "resolution"）
data class RefreshAllResolutionsResponse(
    val totalVideos: Int? = null,
    val pendingVideos: Int? = null,
    val status: String?,
    val module: String? = null
)

// 批量刷新演员（电影 + 剧集，异步提交，module 形如 "actors"）
data class RefreshAllActorsResponse(
    val totalVideos: Int? = null,
    val status: String?,
    val module: String? = null,
    val message: String? = null
)

// 扫描流水线进度（聚合接口：scan/scrape/actors/assets/done 全阶段）
data class PipelineProgress(
    val libraryId: Long,
    val stage: String?,
    val running: Boolean,
    val percent: Double,
    val currentItem: String?,
    val scrapingEnabled: Boolean,
    val scanPercent: Double,
    val scrapePercent: Double
)
