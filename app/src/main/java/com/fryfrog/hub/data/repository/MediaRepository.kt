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
    suspend fun getVideoSeries(page: Int = 0, size: Int = 20): Result<PageResponse<SeriesDTO>> = safeApiCall {
        val response = api.getVideoSeries(page, size)
        val data = response.data ?: PageResponse(emptyList(), 0, 20, 0, 0)
        data.copy(content = data.content.map { it.copy(
            coverUrl = fixUrl(it.coverUrl),
            fanartUrl = fixUrl(it.fanartUrl)
        ) })
    }

    suspend fun getVideoSeriesDetail(id: Long, type: String? = null): Result<SeriesDTO> = safeApiCall {
        val url = "$baseUrl/api/v1/video/series/$id"
        android.util.Log.d("MediaRepository", "Fetching: $url type=$type")
        api.getVideoSeriesDetail(id, type).data?.let { series ->
            // Flatten seasons into episodes for UI compatibility
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

    // Music
    suspend fun getMusicByAlbum(): Result<List<AlbumGroup>> = safeApiCall {
        api.getMusicByAlbum().data?.content?.map { album ->
            album.copy(
                coverUrl = fixUrl(album.coverUrl),
                tracks = album.tracks?.map { it.copy(coverUrl = fixUrl(it.coverUrl)) }
            )
        } ?: emptyList()
    }

    suspend fun getRecentlyAddedMusic(): Result<List<MusicTrack>> = safeApiCall {
        api.getRecentlyAddedMusic().data?.content?.map { it.copy(coverUrl = fixUrl(it.coverUrl)) } ?: emptyList()
    }

    suspend fun getMusicFavorites(): Result<List<MusicTrack>> = safeApiCall {
        api.getMusicFavorites().data?.content?.map { it.copy(coverUrl = fixUrl(it.coverUrl)) } ?: emptyList()
    }

    suspend fun getMusicEmbeddedLyrics(trackId: Long): Result<String?> = safeApiCall {
        api.getMusicEmbeddedLyrics(trackId).data
    }

    suspend fun getMusicExternalLyrics(trackId: Long): Result<String?> = safeApiCall {
        api.getMusicExternalLyrics(trackId).data
    }

    // Comic
    suspend fun getComicSeries(page: Int = 0, size: Int = 20): Result<PageResponse<ComicSeries>> = safeApiCall {
        val response = api.getComicSeries(page, size)
        val data = response.data ?: PageResponse(emptyList(), 0, 20, 0, 0)
        data.copy(content = data.content.map { series ->
            series.copy(
                coverUrl = fixUrl(series.coverUrl),
                comics = series.comics?.map { it.copy(coverUrl = fixUrl(it.coverUrl)) }
            )
        })
    }

    suspend fun getComicFavorites(): Result<List<ComicDTO>> = safeApiCall {
        api.getComicFavorites().data?.content?.map { it.copy(coverUrl = fixUrl(it.coverUrl)) } ?: emptyList()
    }

    suspend fun getComicCharacters(comicId: Long): Result<List<MediaCharacter>> = safeApiCall {
        api.getComicCharacters(comicId).data?.map { it.copy(imageUrl = fixUrl(it.imageUrl)) } ?: emptyList()
    }

    // Ebook
    suspend fun getEbookSeries(page: Int = 0, size: Int = 20): Result<PageResponse<EbookSeries>> = safeApiCall {
        val response = api.getEbookSeries(page, size)
        val data = response.data ?: PageResponse(emptyList(), 0, 20, 0, 0)
        data.copy(content = data.content.map { series ->
            series.copy(
                coverUrl = fixUrl(series.coverUrl),
                books = series.books?.map { it.copy(coverUrl = fixUrl(it.coverUrl)) }
            )
        })
    }

    suspend fun getRecentlyAddedEbooks(): Result<List<EbookDTO>> = safeApiCall {
        api.getRecentlyAddedEbooks().data?.content?.map { it.copy(coverUrl = fixUrl(it.coverUrl)) } ?: emptyList()
    }

    suspend fun getEbookFavorites(): Result<List<EbookDTO>> = safeApiCall {
        api.getEbookFavorites().data?.content?.map { it.copy(coverUrl = fixUrl(it.coverUrl)) } ?: emptyList()
    }

    suspend fun getEbookCharacters(ebookId: Long): Result<List<MediaCharacter>> = safeApiCall {
        api.getEbookCharacters(ebookId).data?.map { it.copy(imageUrl = fixUrl(it.imageUrl)) } ?: emptyList()
    }

    // Book Source (书源管理)
    suspend fun getBookSources(): Result<List<BookSource>> = safeApiCall {
        api.getBookSources().data ?: emptyList()
    }

    suspend fun importBookSources(url: String): Result<List<BookSource>> = safeApiCall {
        api.importBookSources(url).data ?: emptyList()
    }

    suspend fun toggleBookSource(id: Long, enabled: Boolean): Result<BookSource> = safeApiCall {
        api.toggleBookSource(id, enabled).data ?: throw Exception("Failed to toggle book source")
    }

    suspend fun deleteBookSource(id: Long): Result<Map<String, Any>> = safeApiCall {
        api.deleteBookSource(id).data ?: emptyMap()
    }

    // Online Book Search (在线搜索)
    suspend fun searchOnlineBooks(keyword: String, sourceId: Long? = null): Result<List<OnlineBookResult>> = safeApiCall {
        api.searchOnlineBooks(keyword, sourceId).data ?: emptyList()
    }

    suspend fun getOnlineBookChapters(bookUrl: String, sourceId: Long): Result<List<OnlineChapterInfo>> = safeApiCall {
        api.getOnlineBookChapters(bookUrl, sourceId).data ?: emptyList()
    }

    suspend fun addToShelfOnline(request: AddToShelfRequest): Result<EbookDTO> = safeApiCall {
        api.addToShelfOnline(request).data ?: throw Exception("Failed to add to shelf")
    }

    // Unified Ebook API (统一电子书接口)
    suspend fun getUnifiedEbookDetail(id: Long): Result<EbookDTO> = safeApiCall {
        api.getEbookDetail(id).data?.let { ebook ->
            ebook.copy(coverUrl = fixUrl(ebook.coverUrl))
        } ?: throw Exception("Ebook not found")
    }

    suspend fun getOnlineChapters(ebookId: Long): Result<List<UnifiedEbookChapterInfo>> = safeApiCall {
        api.getOnlineChapters(ebookId).data ?: emptyList()
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
