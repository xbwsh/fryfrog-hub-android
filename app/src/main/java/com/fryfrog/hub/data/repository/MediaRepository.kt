package com.fryfrog.hub.data.repository

import com.fryfrog.hub.data.model.*
import com.fryfrog.hub.data.remote.ApiClient

class MediaRepository {

    private val api get() = ApiClient.getApi()
    private val baseUrl get() = ApiClient.getBaseUrl()

    private fun fixUrl(url: String?): String? {
        if (url == null) return null
        if (url.startsWith("http")) return url
        return "$baseUrl$url"
    }

    // Video
    suspend fun getVideoSeries(): Result<List<SeriesDTO>> = safeApiCall {
        api.getVideoSeries().data?.content?.map { it.copy(
            coverUrl = fixUrl(it.coverUrl),
            fanartUrl = fixUrl(it.fanartUrl)
        ) } ?: emptyList()
    }

    suspend fun getVideoSeriesDetail(id: Long, type: String? = null): Result<SeriesDTO> = safeApiCall {
        val url = "$baseUrl/api/v1/video/series/$id"
        android.util.Log.d("MediaRepository", "Fetching: $url type=$type")
        api.getVideoSeriesDetail(id, type).data?.let { series ->
            series.copy(
                coverUrl = fixUrl(series.coverUrl),
                fanartUrl = fixUrl(series.fanartUrl),
                episodes = series.episodes?.map { it.copy(
                    coverUrl = fixUrl(it.coverUrl),
                    fanartUrl = fixUrl(it.fanartUrl)
                ) }
            )
        } ?: throw Exception("Series not found")
    }

    suspend fun getVideoActors(videoId: Long): Result<List<VideoActor>> = safeApiCall {
        api.getVideoActors(videoId).data?.map { it.copy(
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

    // Comic
    suspend fun getComicSeries(): Result<List<ComicSeries>> = safeApiCall {
        api.getComicSeries().data?.content?.map { series ->
            series.copy(
                coverUrl = fixUrl(series.coverUrl),
                comics = series.comics?.map { it.copy(coverUrl = fixUrl(it.coverUrl)) }
            )
        } ?: emptyList()
    }

    suspend fun getComicFavorites(): Result<List<ComicDTO>> = safeApiCall {
        api.getComicFavorites().data?.content?.map { it.copy(coverUrl = fixUrl(it.coverUrl)) } ?: emptyList()
    }

    suspend fun getComicCharacters(comicId: Long): Result<List<MediaCharacter>> = safeApiCall {
        api.getComicCharacters(comicId).data?.map { it.copy(imageUrl = fixUrl(it.imageUrl)) } ?: emptyList()
    }

    // Ebook
    suspend fun getEbookSeries(): Result<List<EbookSeries>> = safeApiCall {
        api.getEbookSeries().data?.content?.map { series ->
            series.copy(
                coverUrl = fixUrl(series.coverUrl),
                books = series.books?.map { it.copy(coverUrl = fixUrl(it.coverUrl)) }
            )
        } ?: emptyList()
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

    private suspend fun <T> safeApiCall(call: suspend () -> T): Result<T> {
        return try {
            Result.success(call())
        } catch (e: Exception) {
            android.util.Log.e("MediaRepository", "API call failed", e)
            Result.failure(e)
        }
    }
}
