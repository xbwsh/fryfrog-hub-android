package com.fryfrog.hub.data.remote

import com.fryfrog.hub.data.model.*
import retrofit2.http.*

interface FryfrogApi {

    // ========== Video ==========
    @GET("/api/v1/video/series")
    suspend fun getVideoSeries(): ApiResponse<List<SeriesDTO>>

    @GET("/api/v1/video/series/{id}")
    suspend fun getVideoSeriesDetail(@Path("id") id: Long): ApiResponse<SeriesDTO>

    @GET("/api/v1/video/{id}")
    suspend fun getVideoDetail(@Path("id") id: Long): ApiResponse<VideoDTO>

    @GET("/api/v1/video/{id}/cover")
    suspend fun getVideoCover(@Path("id") id: Long): ApiResponse<String>

    @GET("/api/v1/video/favorites")
    suspend fun getVideoFavorites(): ApiResponse<List<SeriesDTO>>

    // ========== Music ==========
    @GET("/api/v1/music")
    suspend fun getMusicByAlbum(): ApiResponse<List<AlbumGroup>>

    @GET("/api/v1/music/list")
    suspend fun getMusicList(): ApiResponse<List<MusicTrack>>

    @GET("/api/v1/music/{id}")
    suspend fun getMusicDetail(@Path("id") id: Long): ApiResponse<MusicTrack>

    @GET("/api/v1/music/{id}/cover")
    suspend fun getMusicCover(@Path("id") id: Long): ApiResponse<String>

    @GET("/api/v1/music/recently-added")
    suspend fun getRecentlyAddedMusic(): ApiResponse<List<MusicTrack>>

    @GET("/api/v1/music/recently-played")
    suspend fun getRecentlyPlayedMusic(): ApiResponse<List<MusicTrack>>

    @GET("/api/v1/music/favorites")
    suspend fun getMusicFavorites(): ApiResponse<List<MusicTrack>>

    @GET("/api/v1/music/most-played")
    suspend fun getMostPlayedMusic(): ApiResponse<List<MusicTrack>>

    @GET("/api/v1/music/recommendations")
    suspend fun getMusicRecommendations(): ApiResponse<Map<String, List<MusicTrack>>>

    // ========== Comic ==========
    @GET("/api/v1/comic/series")
    suspend fun getComicSeries(): ApiResponse<List<ComicSeries>>

    @GET("/api/v1/comic/{id}")
    suspend fun getComicDetail(@Path("id") id: Long): ApiResponse<ComicDTO>

    @GET("/api/v1/comic/{id}/cover")
    suspend fun getComicCover(@Path("id") id: Long): ApiResponse<String>

    @GET("/api/v1/comic/favorites")
    suspend fun getComicFavorites(): ApiResponse<List<ComicDTO>>

    // ========== Ebook ==========
    @GET("/api/v1/ebook/series")
    suspend fun getEbookSeries(): ApiResponse<List<EbookSeries>>

    @GET("/api/v1/ebook/{id}")
    suspend fun getEbookDetail(@Path("id") id: Long): ApiResponse<EbookDTO>

    @GET("/api/v1/ebook/{id}/cover")
    suspend fun getEbookCover(@Path("id") id: Long): ApiResponse<String>

    @GET("/api/v1/ebook/recently-added")
    suspend fun getRecentlyAddedEbooks(): ApiResponse<List<EbookDTO>>

    @GET("/api/v1/ebook/recently-read")
    suspend fun getRecentlyReadEbooks(): ApiResponse<List<EbookDTO>>

    @GET("/api/v1/ebook/favorites")
    suspend fun getEbookFavorites(): ApiResponse<List<EbookDTO>>

    @GET("/api/v1/ebook/stats")
    suspend fun getEbookStats(): ApiResponse<Map<String, Any>>

    // ========== Auth ==========
    @POST("/api/v1/auth/login")
    suspend fun login(@Body body: Map<String, String>): ApiResponse<Map<String, String>>

    @GET("/api/v1/auth/status")
    suspend fun authStatus(): ApiResponse<Map<String, Any>>

    // ========== Settings ==========
    @GET("/api/v1/settings")
    suspend fun getSettings(): ApiResponse<List<Map<String, Any>>>
}
