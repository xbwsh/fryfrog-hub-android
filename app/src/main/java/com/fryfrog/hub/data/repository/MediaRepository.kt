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
        api.getRecentlyAddedMusic().data?.map { it.copy(coverUrl = fixUrl(it.coverUrl)) } ?: emptyList()
    }

    suspend fun getMusicFavorites(): Result<List<MusicTrack>> = safeApiCall {
        api.getMusicFavorites().data?.map { it.copy(coverUrl = fixUrl(it.coverUrl)) } ?: emptyList()
    }

    // Comic
    suspend fun getComicSeries(): Result<List<ComicSeries>> = safeApiCall {
        api.getComicSeries().data?.content?.map { it.copy(
            coverUrl = fixUrl(it.coverUrl)
        ) } ?: emptyList()
    }

    suspend fun getComicFavorites(): Result<List<ComicDTO>> = safeApiCall {
        api.getComicFavorites().data?.map { it.copy(coverUrl = fixUrl(it.coverUrl)) } ?: emptyList()
    }

    // Ebook
    suspend fun getEbookSeries(): Result<List<EbookSeries>> = safeApiCall {
        api.getEbookSeries().data?.content?.map { it.copy(
            coverUrl = fixUrl(it.coverUrl)
        ) } ?: emptyList()
    }

    suspend fun getRecentlyAddedEbooks(): Result<List<EbookDTO>> = safeApiCall {
        api.getRecentlyAddedEbooks().data?.map { it.copy(coverUrl = fixUrl(it.coverUrl)) } ?: emptyList()
    }

    suspend fun getEbookFavorites(): Result<List<EbookDTO>> = safeApiCall {
        api.getEbookFavorites().data?.map { it.copy(coverUrl = fixUrl(it.coverUrl)) } ?: emptyList()
    }

    private suspend fun <T> safeApiCall(call: suspend () -> T): Result<T> {
        return try {
            Result.success(call())
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
