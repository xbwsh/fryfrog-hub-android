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
        api.getVideoFavorites().data?.map { it.copy(
            coverUrl = fixUrl(it.coverUrl),
            fanartUrl = fixUrl(it.fanartUrl)
        ) } ?: emptyList()
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
