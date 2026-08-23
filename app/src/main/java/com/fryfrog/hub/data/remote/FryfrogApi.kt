package com.fryfrog.hub.data.remote

import com.fryfrog.hub.data.model.*
import okhttp3.ResponseBody
import retrofit2.Response
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

    @GET("/api/v1/video/favorites")
    suspend fun getVideoFavorites(
        @Query("page") page: Int = 0,
        @Query("size") size: Int = 20
    ): ApiResponse<PageResponse<VideoDTO>>

    @PUT("/api/v1/video/{id}/favorite")
    suspend fun setVideoFavorite(@Path("id") id: Long, @Query("status") status: Boolean): ApiResponse<VideoDTO>

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

    @DELETE("/api/v1/video/{id}/progress")
    suspend fun deleteVideoProgress(@Path("id") id: Long): ApiResponse<Map<String, Any>>

    // 标记已看/未看（看完与否由后端统一维护）
    @PUT("/api/v1/video/{id}/watched")
    suspend fun updateWatched(@Path("id") id: Long, @Body body: UpdateWatchedRequest): ApiResponse<WatchProgressDTO>

    // ========== Video Search ==========
    @GET("/api/v1/video/search/title")
    suspend fun searchByTitle(
        @Query("q") query: String,
        @Query("page") page: Int = 0,
        @Query("size") size: Int = 20
    ): ApiResponse<PageResponse<VideoDTO>>

    @GET("/api/v1/video/search/director")
    suspend fun searchByDirector(
        @Query("q") query: String,
        @Query("page") page: Int = 0,
        @Query("size") size: Int = 20
    ): ApiResponse<PageResponse<VideoDTO>>

    // ========== TMDB Scraping ==========
    @GET("/api/v1/video/tmdb/search")
    suspend fun searchTmdb(@Query("q") query: String): ApiResponse<List<TmdbSearchResult>>

    @POST("/api/v1/video/{id}/tmdb/bind")
    suspend fun bindTmdb(@Path("id") id: Long, @Body request: TmdbBindRequest): ApiResponse<Map<String, Any>>

    @POST("/api/v1/video/{id}/tmdb/unbind")
    suspend fun unbindTmdb(@Path("id") id: Long): ApiResponse<Map<String, Any>>

    @POST("/api/v1/video/{id}/tmdb/refresh")
    suspend fun refreshTmdb(@Path("id") id: Long): ApiResponse<Map<String, Any>>

    // 按资源库重新刮削：解绑指定库所有视频后按库类型重新搜索绑定（取代旧的 supplement 接口）
    @POST("/api/v1/video/tmdb/rescrape-library/{libraryId}")
    suspend fun rescrapeByLibrary(@Path("libraryId") libraryId: Long): ApiResponse<String>

    @GET("/api/v1/video/scrape/progress")
    suspend fun getScrapeProgress(@Query("module") module: String? = null): ApiResponse<ScrapeProgress>

    // ========== Frame Cover ==========
    @POST("/api/v1/video/{id}/frames")
    suspend fun generateFrames(@Path("id") id: Long): ApiResponse<GenerateFramesResponse>

    @POST("/api/v1/video/{id}/frames/select")
    suspend fun selectFrame(@Path("id") id: Long, @Body body: SelectFrameRequest): ApiResponse<SelectFrameResponse>

    // 从单集截帧设置系列横屏背景图
    @POST("/api/v1/video/series/{id}/frames/select")
    suspend fun selectSeriesFanart(@Path("id") id: Long, @Body body: SeriesFrameSelectRequest): ApiResponse<Map<String, Any>>

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
    suspend fun setSeriesFavorite(@Path("id") id: Long, @Query("status") status: Boolean): ApiResponse<SeriesDTO>

    @GET("/api/v1/video/series/favorites")
    suspend fun getSeriesFavorites(): ApiResponse<List<SeriesDTO>>

    // ========== Auth（多用户） ==========
    @POST("/api/v1/auth/login")
    suspend fun login(@Body body: Map<String, String>): LoginResponse

    // 注销当前 token（失败不阻塞本地登出）
    @POST("/api/v1/auth/logout")
    suspend fun logout(): ApiResponse<Map<String, Any>>

    @GET("/api/v1/auth/status")
    suspend fun authStatus(): ApiResponse<Map<String, Any>>

    // ========== Users ==========
    @GET("/api/v1/users/me")
    suspend fun getCurrentUser(): ApiResponse<UserDTO>

    @GET("/api/v1/users/me/preferences")
    suspend fun myPreferences(): ApiResponse<Map<String, String>>

    @PUT("/api/v1/users/me/preferences")
    suspend fun updateMyPreferences(@Body body: UserPreferenceUpdateRequest): ApiResponse<Map<String, String>>

    @PUT("/api/v1/users/me/password")
    suspend fun changeMyPassword(@Body body: ChangePasswordRequest): ApiResponse<Map<String, Any>>

    @GET("/api/v1/users")
    suspend fun getUsers(): ApiResponse<List<UserDTO>>

    @POST("/api/v1/users")
    suspend fun createUser(@Body body: UserCreateRequest): ApiResponse<UserDTO>

    @GET("/api/v1/users/{id}")
    suspend fun getUser(@Path("id") id: Long): ApiResponse<UserDTO>

    @PUT("/api/v1/users/{id}")
    suspend fun updateUser(@Path("id") id: Long, @Body body: UserUpdateRequest): ApiResponse<UserDTO>

    @DELETE("/api/v1/users/{id}")
    suspend fun deleteUser(@Path("id") id: Long): ApiResponse<Map<String, Any>>

    @PUT("/api/v1/users/{id}/password")
    suspend fun resetUserPassword(@Path("id") id: Long, @Body body: ChangePasswordRequest): ApiResponse<Map<String, Any>>

    @GET("/api/v1/users/{id}/libraries")
    suspend fun getUserLibraries(@Path("id") id: Long): ApiResponse<List<Long>>

    @PUT("/api/v1/users/{id}/libraries")
    suspend fun setUserLibraries(@Path("id") id: Long, @Body body: UserLibraryUpdateRequest): ApiResponse<List<Long>>

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

    // 启用/禁用资源库
    @PUT("/api/v1/media-libraries/{id}/toggle")
    suspend fun toggleMediaLibrary(@Path("id") id: Long): ApiResponse<MediaLibrary>

    @GET("/api/v1/media-libraries/{id}/pipeline-progress")
    suspend fun getPipelineProgress(@Path("id") id: Long): ApiResponse<PipelineProgress>

    // 扫描进度查询（不传 libraryId 返回全部库）
    @GET("/api/v1/media-libraries/scan/progress")
    suspend fun getScanProgress(@Query("libraryId") libraryId: Long? = null): ApiResponse<List<ScrapeProgress>>

    @POST("/api/v1/media-libraries/scan")
    suspend fun scanAllMediaLibraries(): ApiResponse<Map<String, Any>>

    @GET("/api/v1/media-libraries/browse")
    suspend fun browseDirectory(@Query("path") path: String? = null): ApiResponse<List<Map<String, Any>>>

    // ========== Music ==========
    // 音乐首页：按当前用户可见媒体库分组返回专辑与歌手
    @GET("/api/v1/music/home")
    suspend fun getMusicHome(): ApiResponse<List<MusicLibraryGroupDTO>>

    @GET("/api/v1/music/artists")
    suspend fun getMusicArtists(): ApiResponse<List<MusicArtistDTO>>

    // 歌手详情（含专辑列表）
    @GET("/api/v1/music/artists/{id}")
    suspend fun getMusicArtist(@Path("id") id: Long): ApiResponse<MusicArtistDTO>

    @GET("/api/v1/music/albums")
    suspend fun getMusicAlbums(): ApiResponse<List<MusicAlbumDTO>>

    // 专辑详情（含曲目）
    @GET("/api/v1/music/albums/{id}")
    suspend fun getMusicAlbum(@Path("id") id: Long): ApiResponse<MusicAlbumDTO>

    // 搜索单曲：q=标题/歌手/专辑关键词，genre=流派过滤，limit 默认 50
    @GET("/api/v1/music/songs")
    suspend fun searchMusicSongs(
        @Query("q") q: String? = null,
        @Query("genre") genre: String? = null,
        @Query("limit") limit: Int = 50
    ): ApiResponse<List<MusicSongDTO>>

    @GET("/api/v1/music/songs/{id}")
    suspend fun getMusicSong(@Path("id") id: Long): ApiResponse<MusicSongDTO>

    // 歌词为原始文本（优先内嵌，否则同目录 .lrc），流式获取
    @GET("/api/v1/music/songs/{id}/lyrics")
    suspend fun getMusicLyrics(@Path("id") id: Long): Response<ResponseBody>

    @GET("/api/v1/music/genres")
    suspend fun getMusicGenres(): ApiResponse<List<String>>

    // 收藏/评分：type = songs / albums / artists
    @PUT("/api/v1/music/{type}/{id}/star")
    suspend fun setMusicStar(
        @Path("type") type: String,
        @Path("id") id: Long,
        @Query("status") status: Boolean
    ): ApiResponse<Map<String, Any>>

    // rating 1-5，0 清除
    @PUT("/api/v1/music/{type}/{id}/rating")
    suspend fun setMusicRating(
        @Path("type") type: String,
        @Path("id") id: Long,
        @Query("rating") rating: Int
    ): ApiResponse<Map<String, Any>>

    // ===== 播放列表 =====
    @GET("/api/v1/music/playlists")
    suspend fun getMusicPlaylists(): ApiResponse<List<MusicPlaylist>>

    @POST("/api/v1/music/playlists")
    suspend fun createMusicPlaylist(@Body body: MusicPlaylistRequest): ApiResponse<MusicPlaylist>

    // 详情返回 playlist + 曲目，结构为 Map
    @GET("/api/v1/music/playlists/{id}")
    suspend fun getMusicPlaylistDetail(@Path("id") id: Long): ApiResponse<Map<String, Any>>

    @PUT("/api/v1/music/playlists/{id}")
    suspend fun updateMusicPlaylist(
        @Path("id") id: Long,
        @Body body: MusicPlaylistUpdateRequest
    ): ApiResponse<MusicPlaylist>

    @DELETE("/api/v1/music/playlists/{id}")
    suspend fun deleteMusicPlaylist(@Path("id") id: Long): ApiResponse<Map<String, Any>>

    // ===== 播放队列 / Scrobble / 书签 =====
    @GET("/api/v1/music/play-queue")
    suspend fun getMusicPlayQueue(): ApiResponse<MusicPlayQueue>

    @PUT("/api/v1/music/play-queue")
    suspend fun saveMusicPlayQueue(@Body body: MusicPlayQueueRequest): ApiResponse<MusicPlayQueue>

    @POST("/api/v1/music/scrobble")
    suspend fun scrobbleMusic(@Body body: MusicScrobbleRequest): ApiResponse<Map<String, Any>>

    @GET("/api/v1/music/bookmarks")
    suspend fun getMusicBookmarks(): ApiResponse<List<MusicBookmark>>

    @POST("/api/v1/music/bookmarks")
    suspend fun createMusicBookmark(@Body body: MusicBookmarkRequest): ApiResponse<MusicBookmark>

    @DELETE("/api/v1/music/bookmarks/{songId}")
    suspend fun deleteMusicBookmark(@Path("songId") songId: Long): ApiResponse<Map<String, Any>>

    // ===== 管理（异步执行，进度走 pipeline-progress 轮询） =====
    @POST("/api/v1/music/scan")
    suspend fun scanMusicLibraries(@Query("libraryId") libraryId: Long? = null): ApiResponse<Map<String, Any>>

    // 整理音乐文件：dryRun 默认 true 仅预览
    @POST("/api/v1/music/organize")
    suspend fun organizeMusicLibrary(
        @Query("libraryId") libraryId: Long,
        @Query("dryRun") dryRun: Boolean = true
    ): ApiResponse<Map<String, Any>>

    // ========== Settings ==========
    @GET("/api/v1/settings")
    suspend fun getSettings(): ApiResponse<List<SystemSetting>>

    @GET("/api/v1/settings/{key}")
    suspend fun getSetting(@Path("key") key: String): ApiResponse<SystemSetting>

    @PUT("/api/v1/settings/{key}")
    suspend fun updateSetting(@Path("key") key: String, @Body body: SettingUpdateRequest): ApiResponse<SystemSetting>

    // ========== Logs ==========
    @GET("/api/v1/logs")
    suspend fun listLogs(): ApiResponse<List<Map<String, Any>>>

    // 日志为二进制文件，流式下载
    @Streaming
    @GET("/api/v1/logs/{fileName}")
    suspend fun exportLog(@Path("fileName") fileName: String): Response<ResponseBody>
}
