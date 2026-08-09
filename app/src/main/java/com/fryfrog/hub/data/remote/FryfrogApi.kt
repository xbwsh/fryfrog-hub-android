package com.fryfrog.hub.data.remote

import com.fryfrog.hub.data.model.*
import retrofit2.http.*

interface FryfrogApi {

    // ========== Video ==========
    @GET("/api/v1/video/series")
    suspend fun getVideoSeries(
        @Query("page") page: Int = 0,
        @Query("size") size: Int = 20,
        @Query("adult") adult: Boolean? = null
    ): ApiResponse<PageResponse<SeriesDTO>>

    @GET("/api/v1/video/series/grouped-by-library")
    suspend fun getVideoSeriesGroupedByLibrary(): ApiResponse<List<LibraryGroup>>

    @GET("/api/v1/video/series/{id}")
    suspend fun getVideoSeriesDetail(@Path("id") id: Long, @Query("type") type: String? = null): ApiResponse<SeriesDTO>

    @POST("/api/v1/video/series/{id}/refresh-season-covers")
    suspend fun refreshSeasonCovers(@Path("id") id: Long): ApiResponse<Map<String, Any>>

    @POST("/api/v1/video/series/refresh-all-season-covers")
    suspend fun refreshAllSeasonCovers(): ApiResponse<Map<String, Any>>

    @POST("/api/v1/video/series/{id}/refresh-logo")
    suspend fun refreshSeriesLogo(@Path("id") id: Long): ApiResponse<RefreshLogoResponse>

    @POST("/api/v1/video/refresh-all-logos")
    suspend fun refreshAllLogos(): ApiResponse<RefreshAllLogosResponse>

    @POST("/api/v1/video/{id}/refresh-logo")
    suspend fun refreshVideoLogo(@Path("id") id: Long): ApiResponse<RefreshLogoResponse>

    @POST("/api/v1/video/refresh-all-resolutions")
    suspend fun refreshAllResolutions(): ApiResponse<RefreshAllResolutionsResponse>

    @GET("/api/v1/video/series/{id}/logo-options")
    suspend fun getSeriesLogoOptions(@Path("id") id: Long): ApiResponse<List<LogoOption>>

    @POST("/api/v1/video/series/{id}/logo")
    suspend fun setSeriesLogo(@Path("id") id: Long, @Body body: LogoSetRequest): ApiResponse<RefreshLogoResponse>

    @GET("/api/v1/video/{id}/logo-options")
    suspend fun getVideoLogoOptions(@Path("id") id: Long): ApiResponse<List<LogoOption>>

    @POST("/api/v1/video/{id}/logo")
    suspend fun setVideoLogo(@Path("id") id: Long, @Body body: LogoSetRequest): ApiResponse<RefreshLogoResponse>

    @POST("/api/v1/video/refresh-all-actors")
    suspend fun refreshAllActors(): ApiResponse<RefreshAllActorsResponse>

    @GET("/api/v1/video/{id}")
    suspend fun getVideoDetail(@Path("id") id: Long): ApiResponse<VideoDTO>

    @GET("/api/v1/video/{id}/actors")
    suspend fun getVideoActors(@Path("id") id: Long): ApiResponse<List<VideoActor>>

    @GET("/api/v1/video/{id}/cover")
    suspend fun getVideoCover(@Path("id") id: Long): ApiResponse<String>

    @GET("/api/v1/video/{id}/fanart")
    suspend fun getVideoFanart(@Path("id") id: Long): ApiResponse<String>

    @GET("/api/v1/video/favorites")
    suspend fun getVideoFavorites(
        @Query("page") page: Int = 0,
        @Query("size") size: Int = 20
    ): ApiResponse<PageResponse<VideoDTO>>

    @PUT("/api/v1/video/{id}/favorite")
    suspend fun setVideoFavorite(@Path("id") id: Long, @Query("status") status: Boolean): ApiResponse<Map<String, Any>>

    @GET("/api/v1/video/{id}/subtitles")
    suspend fun getVideoSubtitles(@Path("id") id: Long): ApiResponse<List<SubtitleDTO>>

    @GET("/api/v1/video/{id}/subtitles/{filename}")
    suspend fun getVideoSubtitleContent(
        @Path("id") id: Long,
        @Path("filename") filename: String
    ): ApiResponse<String>

    @GET("/api/v1/video/{id}/progress")
    suspend fun getVideoProgress(@Path("id") id: Long): ApiResponse<WatchProgressDTO>

    @PUT("/api/v1/video/{id}/progress")
    suspend fun saveVideoProgress(@Path("id") id: Long, @Body request: WatchProgressRequest): ApiResponse<WatchProgressDTO>

    // ========== TMDB Scraping ==========
    @GET("/api/v1/video/tmdb/search")
    suspend fun searchTmdb(@Query("q") query: String): ApiResponse<List<TmdbSearchResult>>

    @POST("/api/v1/video/{id}/tmdb/bind")
    suspend fun bindTmdb(@Path("id") id: Long, @Body request: TmdbBindRequest): ApiResponse<Map<String, Any>>

    @POST("/api/v1/video/{id}/tmdb/unbind")
    suspend fun unbindTmdb(@Path("id") id: Long): ApiResponse<Map<String, Any>>

    @POST("/api/v1/video/{id}/tmdb/refresh")
    suspend fun refreshTmdb(@Path("id") id: Long): ApiResponse<Map<String, Any>>

    @GET("/api/v1/video/scrape/progress")
    suspend fun getScrapeProgress(@Query("module") module: String? = null): ApiResponse<ScrapeProgress>

    @POST("/api/v1/video/scrape/adult-only")
    suspend fun scrapeAdultOnly(@Query("libraryId") libraryId: Long? = null): ApiResponse<Map<String, Any>>

    @POST("/api/v1/video/scrape/supplement/{libraryId}")
    suspend fun scrapeSupplement(
        @Path("libraryId") libraryId: Long,
        @Query("force") force: Boolean = false
    ): ApiResponse<Map<String, Any>>

    // ========== Frame Cover ==========
    @POST("/api/v1/video/{id}/frames")
    suspend fun generateFrames(@Path("id") id: Long): ApiResponse<GenerateFramesResponse>

    @POST("/api/v1/video/{id}/frames/select")
    suspend fun selectFrame(@Path("id") id: Long, @Body body: SelectFrameRequest): ApiResponse<SelectFrameResponse>

    // ========== Metadata Edit ==========
    @PUT("/api/v1/video/{id}/metadata")
    suspend fun updateVideoMetadata(@Path("id") id: Long, @Body body: UpdateMetadataRequest): ApiResponse<VideoDTO>

    @PUT("/api/v1/video/series/{id}/metadata")
    suspend fun updateSeriesMetadata(@Path("id") id: Long, @Body body: UpdateMetadataRequest): ApiResponse<SeriesDTO>

    // ========== Upcoming Calendar ==========
    @GET("/api/v1/video/series/calendar")
    suspend fun getSeriesCalendar(): ApiResponse<List<SeriesCalendarItem>>

    // ========== Series Favorite ==========
    @PUT("/api/v1/video/series/{id}/favorite")
    suspend fun setSeriesFavorite(@Path("id") id: Long, @Query("status") status: Boolean): ApiResponse<Map<String, Any>>

    @GET("/api/v1/video/series/favorites")
    suspend fun getSeriesFavorites(): ApiResponse<List<SeriesDTO>>

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

    @POST("/api/v1/media-libraries/{id}/scan")
    suspend fun scanMediaLibrary(@Path("id") id: Long): ApiResponse<Map<String, Any>>

    @GET("/api/v1/media-libraries/{id}/pipeline-progress")
    suspend fun getPipelineProgress(@Path("id") id: Long): ApiResponse<PipelineProgress>

    @POST("/api/v1/media-libraries/scan")
    suspend fun scanAllMediaLibraries(): ApiResponse<Map<String, Any>>

    @GET("/api/v1/media-libraries/browse")
    suspend fun browseDirectory(@Query("path") path: String? = null): ApiResponse<List<Map<String, Any>>>

    // ========== Settings ==========
    @GET("/api/v1/settings")
    suspend fun getSettings(): ApiResponse<List<Map<String, Any>>>
}
