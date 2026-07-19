package com.fryfrog.hub.data.repository

import com.fryfrog.hub.data.model.*
import com.fryfrog.hub.data.remote.ApiClient

class MediaRepository {

    private val api get() = ApiClient.getApi()

    // Video
    suspend fun getVideoSeries(): Result<List<SeriesDTO>> = safeApiCall {
        api.getVideoSeries().data ?: emptyList()
    }

    suspend fun getVideoFavorites(): Result<List<SeriesDTO>> = safeApiCall {
        api.getVideoFavorites().data ?: emptyList()
    }

    // Music
    suspend fun getMusicByAlbum(): Result<List<AlbumGroup>> = safeApiCall {
        api.getMusicByAlbum().data ?: emptyList()
    }

    suspend fun getRecentlyAddedMusic(): Result<List<MusicTrack>> = safeApiCall {
        api.getRecentlyAddedMusic().data ?: emptyList()
    }

    suspend fun getMusicFavorites(): Result<List<MusicTrack>> = safeApiCall {
        api.getMusicFavorites().data ?: emptyList()
    }

    // Comic
    suspend fun getComicSeries(): Result<List<ComicSeries>> = safeApiCall {
        api.getComicSeries().data ?: emptyList()
    }

    suspend fun getComicFavorites(): Result<List<ComicDTO>> = safeApiCall {
        api.getComicFavorites().data ?: emptyList()
    }

    // Ebook
    suspend fun getEbookSeries(): Result<List<EbookSeries>> = safeApiCall {
        api.getEbookSeries().data ?: emptyList()
    }

    suspend fun getRecentlyAddedEbooks(): Result<List<EbookDTO>> = safeApiCall {
        api.getRecentlyAddedEbooks().data ?: emptyList()
    }

    suspend fun getEbookFavorites(): Result<List<EbookDTO>> = safeApiCall {
        api.getEbookFavorites().data ?: emptyList()
    }

    // Cover URL helper
    fun getVideoCoverUrl(id: Long): String = "${ApiClient.getBaseUrl()}/api/v1/video/$id/cover"
    fun getMusicCoverUrl(id: Long): String = "${ApiClient.getBaseUrl()}/api/v1/music/$id/cover"
    fun getComicCoverUrl(id: Long): String = "${ApiClient.getBaseUrl()}/api/v1/comic/$id/cover"
    fun getEbookCoverUrl(id: Long): String = "${ApiClient.getBaseUrl()}/api/v1/ebook/$id/cover"

    private suspend fun <T> safeApiCall(call: suspend () -> T): Result<T> {
        return try {
            Result.success(call())
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
