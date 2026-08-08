package com.fryfrog.hub.data.repository

import com.fryfrog.hub.data.model.*
import com.fryfrog.hub.data.remote.ApiClient
import kotlinx.coroutines.CancellationException

class MediaRepository {

    private val api get() = ApiClient.getApi()
    private val baseUrl get() = ApiClient.getBaseUrl()

    private fun fixUrl(url: String?): String? {
        if (url == null) return null
        if (url.startsWith("http")) return url
        return "$baseUrl$url"
    }

    // Video
    suspend fun getVideoSeries(page: Int = 0, size: Int = 20, adult: Boolean? = null): Result<PageResponse<SeriesDTO>> = safeApiCall {
        val response = api.getVideoSeries(page, size, adult)
        val data = response.data ?: PageResponse(emptyList(), 0, 20, 0, 0)
        data.copy(content = data.content.map { it.copy(
            coverUrl = fixUrl(it.coverUrl),
            fanartUrl = fixUrl(it.fanartUrl)
        ) })
    }

    suspend fun getVideoSeriesGroupedByLibrary(): Result<List<LibraryGroup>> = safeApiCall {
        val response = api.getVideoSeriesGroupedByLibrary()
        response.data?.map { group ->
            group.copy(
                series = group.series.map { it.copy(
                    coverUrl = fixUrl(it.coverUrl),
                    fanartUrl = fixUrl(it.fanartUrl)
                ) },
                standaloneVideos = group.standaloneVideos.map { it.copy(
                    coverUrl = fixUrl(it.coverUrl),
                    fanartUrl = fixUrl(it.fanartUrl)
                ) }
            )
        } ?: emptyList()
    }

    suspend fun getVideoSeriesDetail(id: Long, type: String? = null): Result<SeriesDTO> = safeApiCall {
        val url = "$baseUrl/api/v1/video/series/$id"
        android.util.Log.d("MediaRepository", "Fetching: $url type=$type")
        api.getVideoSeriesDetail(id, type).data?.let { series ->
            val flatEpisodes = series.seasons?.flatMap { season ->
                season.episodes.orEmpty()
            }
            series.copy(
                coverUrl = fixUrl(series.coverUrl),
                fanartUrl = fixUrl(series.fanartUrl),
                episodes = (flatEpisodes ?: series.episodes)?.map { it.copy(
                    coverUrl = fixUrl(it.coverUrl),
                    fanartUrl = fixUrl(it.fanartUrl)
                ) }
            )
        } ?: throw Exception("Series not found")
    }

    suspend fun getVideoActors(videoId: Long): Result<List<VideoActor>> = safeApiCall {
        android.util.Log.d("MediaRepository", "getVideoActors: videoId=$videoId, url=GET /api/v1/video/$videoId/actors")
        val response = api.getVideoActors(videoId)
        android.util.Log.d("MediaRepository", "getVideoActors response: success=${response.success}, data count=${response.data?.size}")
        response.data?.forEach { actor ->
            android.util.Log.d("MediaRepository", "Actor raw: id=${actor.id}, name=${actor.name}, imageUrl=${actor.imageUrl}")
        }
        response.data?.map { it.copy(
            imageUrl = fixUrl(it.imageUrl)
        ) } ?: emptyList()
    }

    suspend fun getVideoFavorites(): Result<List<SeriesDTO>> = safeApiCall {
        api.getVideoFavorites().data?.content?.map { video ->
            SeriesDTO(
                id = video.id,
                type = video.mediaType,
                title = video.title,
                coverUrl = fixUrl(video.coverUrl),
                fanartUrl = fixUrl(video.fanartUrl),
                originalTitle = video.originalTitle,
                overview = video.overview,
                mediaType = video.mediaType,
                tmdbId = video.tmdbId,
                rating = video.rating,
                year = video.year,
                seasonNumber = null,
                numberOfSeasons = null,
                totalEpisodes = null,
                status = null,
                isAdult = video.isAdult,
                favorite = video.favorite,
                originalFileName = null,
                episodeCount = null,
                seasons = null,
                episodes = null
            )
        } ?: emptyList()
    }

    // TMDB Scraping
    suspend fun searchTmdb(query: String): Result<List<TmdbSearchResult>> = safeApiCall {
        android.util.Log.d("MediaRepository", "searchTmdb: query=$query")
        api.searchTmdb(query).data ?: emptyList()
    }

    suspend fun bindTmdb(videoId: Long, tmdbId: Long, mediaType: String): Result<Map<String, Any>> = safeApiCall {
        android.util.Log.d("MediaRepository", "bindTmdb: videoId=$videoId, tmdbId=$tmdbId, mediaType=$mediaType, url=/api/v1/video/$videoId/tmdb/bind")
        api.bindTmdb(videoId, TmdbBindRequest(tmdbId, mediaType)).data ?: emptyMap()
    }

    suspend fun unbindTmdb(videoId: Long): Result<Map<String, Any>> = safeApiCall {
        android.util.Log.d("MediaRepository", "unbindTmdb: videoId=$videoId, url=POST /api/v1/video/$videoId/tmdb/unbind")
        api.unbindTmdb(videoId).data ?: emptyMap()
    }

    suspend fun refreshTmdb(videoId: Long): Result<Map<String, Any>> = safeApiCall {
        android.util.Log.d("MediaRepository", "refreshTmdb: videoId=$videoId, url=POST /api/v1/video/$videoId/tmdb/refresh")
        api.refreshTmdb(videoId).data ?: emptyMap()
    }

    suspend fun scrapeSupplement(libraryId: Long, force: Boolean = false): Result<Map<String, Any>> = safeApiCall {
        android.util.Log.d("MediaRepository", "scrapeSupplement: libraryId=$libraryId, force=$force")
        val response = api.scrapeSupplement(libraryId, force)
        android.util.Log.d("MediaRepository", "scrapeSupplement response: ${response.data}")
        response.data ?: throw Exception("No data")
    }

    suspend fun generateFrames(videoId: Long): Result<GenerateFramesResponse> = safeApiCall {
        val response = api.generateFrames(videoId)
        android.util.Log.d("MediaRepository", "generateFrames: videoId=$videoId, success=${response.success}")
        response.data?.let { data ->
            data.copy(
                candidates = data.candidates?.map { it.copy(url = fixUrl(it.url)) }
            )
        } ?: throw Exception(response.message ?: "Failed to generate frames")
    }

    suspend fun selectFrame(videoId: Long, index: Int, type: String): Result<SelectFrameResponse> = safeApiCall {
        android.util.Log.d("MediaRepository", "selectFrame: videoId=$videoId, index=$index, type=$type")
        api.selectFrame(videoId, SelectFrameRequest(index, type)).data
            ?: throw Exception("Failed to select frame")
    }

    suspend fun updateVideoMetadata(videoId: Long, body: UpdateMetadataRequest): Result<VideoDTO> = safeApiCall {
        api.updateVideoMetadata(videoId, body).data ?: throw Exception("Failed to update metadata")
    }

    suspend fun updateSeriesMetadata(seriesId: Long, body: UpdateMetadataRequest): Result<SeriesDTO> = safeApiCall {
        api.updateSeriesMetadata(seriesId, body).data ?: throw Exception("Failed to update metadata")
    }

    suspend fun getSeriesCalendar(): Result<List<SeriesCalendarItem>> = safeApiCall {
        api.getSeriesCalendar().data?.map { item ->
            item.copy(
                coverUrl = fixUrl(item.coverUrl),
                fanartUrl = fixUrl(item.fanartUrl)
            )
        } ?: emptyList()
    }

    suspend fun setSeriesFavorite(seriesId: Long, status: Boolean): Result<Map<String, Any>> = safeApiCall {
        api.setSeriesFavorite(seriesId, status).data ?: emptyMap()
    }

    suspend fun getSeriesFavorites(): Result<List<SeriesDTO>> = safeApiCall {
        api.getSeriesFavorites().data?.map { it.copy(
            coverUrl = fixUrl(it.coverUrl),
            fanartUrl = fixUrl(it.fanartUrl)
        ) } ?: emptyList()
    }

    suspend fun setVideoFavorite(videoId: Long, status: Boolean): Result<Map<String, Any>> = safeApiCall {
        api.setVideoFavorite(videoId, status).data ?: emptyMap()
    }

    private suspend fun <T> safeApiCall(call: suspend () -> T): Result<T> {
        return try {
            Result.success(call())
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            android.util.Log.e("MediaRepository", "API call failed", e)
            Result.failure(e)
        }
    }
}
