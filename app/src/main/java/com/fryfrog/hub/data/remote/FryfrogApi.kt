package com.fryfrog.hub.data.remote

import com.fryfrog.hub.data.model.*
import retrofit2.http.*

interface FryfrogApi {

    // ========== Video ==========
    @GET("/api/v1/video/series")
    suspend fun getVideoSeries(): ApiResponse<PageResponse<SeriesDTO>>

    @GET("/api/v1/video/series/{id}")
    suspend fun getVideoSeriesDetail(@Path("id") id: Long, @Query("type") type: String? = null): ApiResponse<SeriesDTO>

    @GET("/api/v1/video/{id}")
    suspend fun getVideoDetail(@Path("id") id: Long): ApiResponse<VideoDTO>

    @GET("/api/v1/video/{id}/actors")
    suspend fun getVideoActors(@Path("id") id: Long): ApiResponse<List<VideoActor>>

    @GET("/api/v1/video/{id}/cover")
    suspend fun getVideoCover(@Path("id") id: Long): ApiResponse<String>

    @GET("/api/v1/video/favorites")
    suspend fun getVideoFavorites(): ApiResponse<List<SeriesDTO>>

    @GET("/api/v1/video/{id}/progress")
    suspend fun getVideoProgress(@Path("id") id: Long): ApiResponse<WatchProgressDTO>

    @PUT("/api/v1/video/{id}/progress")
    suspend fun saveVideoProgress(@Path("id") id: Long, @Body request: WatchProgressRequest): ApiResponse<WatchProgressDTO>

    // ========== Music ==========
    @GET("/api/v1/music")
    suspend fun getMusicByAlbum(): ApiResponse<PageResponse<AlbumGroup>>

    @GET("/api/v1/music/list")
    suspend fun getMusicList(): ApiResponse<PageResponse<MusicTrack>>

    @GET("/api/v1/music/{id}")
    suspend fun getMusicDetail(@Path("id") id: Long): ApiResponse<MusicTrack>

    @GET("/api/v1/music/{id}/cover")
    suspend fun getMusicCover(@Path("id") id: Long): ApiResponse<String>

    @GET("/api/v1/music/recently-added")
    suspend fun getRecentlyAddedMusic(): ApiResponse<PageResponse<MusicTrack>>

    @GET("/api/v1/music/recently-played")
    suspend fun getRecentlyPlayedMusic(): ApiResponse<PageResponse<MusicTrack>>

    @GET("/api/v1/music/favorites")
    suspend fun getMusicFavorites(): ApiResponse<PageResponse<MusicTrack>>

    @GET("/api/v1/music/most-played")
    suspend fun getMostPlayedMusic(): ApiResponse<PageResponse<MusicTrack>>

    @GET("/api/v1/music/recommendations")
    suspend fun getMusicRecommendations(): ApiResponse<Map<String, List<MusicTrack>>>

    // ========== Comic ==========
    @GET("/api/v1/comic/series")
    suspend fun getComicSeries(): ApiResponse<PageResponse<ComicSeries>>

    @GET("/api/v1/comic/{id}")
    suspend fun getComicDetail(@Path("id") id: Long): ApiResponse<ComicDTO>

    @GET("/api/v1/comic/{id}/cover")
    suspend fun getComicCover(@Path("id") id: Long): ApiResponse<String>

    @GET("/api/v1/comic/favorites")
    suspend fun getComicFavorites(): ApiResponse<PageResponse<ComicDTO>>

    @GET("/api/v1/comic/{id}/characters")
    suspend fun getComicCharacters(@Path("id") id: Long): ApiResponse<List<MediaCharacter>>

    // ========== Ebook ==========
    @GET("/api/v1/ebook/series")
    suspend fun getEbookSeries(): ApiResponse<PageResponse<EbookSeries>>

    @GET("/api/v1/ebook/{id}")
    suspend fun getEbookDetail(@Path("id") id: Long): ApiResponse<EbookDTO>

    @GET("/api/v1/ebook/{id}/cover")
    suspend fun getEbookCover(@Path("id") id: Long): ApiResponse<String>

    @GET("/api/v1/ebook/recently-added")
    suspend fun getRecentlyAddedEbooks(): ApiResponse<PageResponse<EbookDTO>>

    @GET("/api/v1/ebook/recently-read")
    suspend fun getRecentlyReadEbooks(): ApiResponse<PageResponse<EbookDTO>>

    @GET("/api/v1/ebook/favorites")
    suspend fun getEbookFavorites(): ApiResponse<PageResponse<EbookDTO>>

    @GET("/api/v1/ebook/{id}/characters")
    suspend fun getEbookCharacters(@Path("id") id: Long): ApiResponse<List<MediaCharacter>>

    @GET("/api/v1/ebook/stats")
    suspend fun getEbookStats(): ApiResponse<Map<String, Any>>

    // ========== Auth ==========
    @POST("/api/v1/auth/login")
    suspend fun login(@Body body: Map<String, String>): LoginResponse

    @GET("/api/v1/auth/status")
    suspend fun authStatus(): ApiResponse<Map<String, Any>>

    // ========== Media Libraries ==========
    @GET("/api/v1/media-libraries")
    suspend fun getMediaLibraries(): ApiResponse<List<MediaLibrary>>

    @POST("/api/v1/media-libraries")
    suspend fun createMediaLibrary(@Body library: MediaLibrary): ApiResponse<MediaLibrary>

    @PUT("/api/v1/media-libraries/{id}")
    suspend fun updateMediaLibrary(@Path("id") id: Long, @Body library: MediaLibrary): ApiResponse<MediaLibrary>

    @DELETE("/api/v1/media-libraries/{id}")
    suspend fun deleteMediaLibrary(@Path("id") id: Long): ApiResponse<Map<String, Any>>

    @PUT("/api/v1/media-libraries/{id}/toggle")
    suspend fun toggleMediaLibrary(@Path("id") id: Long): ApiResponse<MediaLibrary>

    @POST("/api/v1/media-libraries/{id}/scan")
    suspend fun scanMediaLibrary(@Path("id") id: Long): ApiResponse<Map<String, Any>>

    @POST("/api/v1/media-libraries/scan")
    suspend fun scanAllMediaLibraries(): ApiResponse<Map<String, Any>>

    @GET("/api/v1/media-libraries/browse")
    suspend fun browseDirectory(@Query("path") path: String? = null): ApiResponse<List<Map<String, Any>>>

    // ========== Settings ==========
    @GET("/api/v1/settings")
    suspend fun getSettings(): ApiResponse<List<Map<String, Any>>>
}
