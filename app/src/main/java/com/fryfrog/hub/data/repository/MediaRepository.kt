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
            fanartUrl = fixUrl(it.fanartUrl),
            logoUrl = fixUrl(it.logoUrl)
        ) })
    }

    suspend fun getVideoSeriesGroupedByLibrary(): Result<List<LibraryGroup>> = safeApiCall {
        val response = api.getVideoSeriesGroupedByLibrary()
        response.data?.map { group ->
            group.copy(
                series = group.series.map { it.copy(
                    coverUrl = fixUrl(it.coverUrl),
                    fanartUrl = fixUrl(it.fanartUrl),
                    logoUrl = fixUrl(it.logoUrl)
                ) },
                standaloneVideos = group.standaloneVideos.map { it.copy(
                    coverUrl = fixUrl(it.coverUrl),
                    fanartUrl = fixUrl(it.fanartUrl),
                    logoUrl = fixUrl(it.logoUrl)
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
                logoUrl = fixUrl(series.logoUrl),
                seasons = series.seasons?.map { season ->
                    season.copy(coverUrl = fixUrl(season.coverUrl))
                },
                episodes = (flatEpisodes ?: series.episodes)?.map { it.copy(
                    coverUrl = fixUrl(it.coverUrl),
                    fanartUrl = fixUrl(it.fanartUrl),
                    logoUrl = fixUrl(it.logoUrl)
                ) }
            )
        } ?: throw Exception("Series not found")
    }

    suspend fun refreshSeasonCovers(seriesId: Long): Result<Map<String, Any>> = safeApiCall {
        android.util.Log.d("MediaRepository", "refreshSeasonCovers: seriesId=$seriesId")
        api.refreshSeasonCovers(seriesId).data ?: emptyMap()
    }

    suspend fun refreshAllSeasonCovers(): Result<Map<String, Any>> = safeApiCall {
        android.util.Log.d("MediaRepository", "refreshAllSeasonCovers")
        api.refreshAllSeasonCovers().data ?: emptyMap()
    }

    suspend fun refreshAllActors(): Result<RefreshAllActorsResponse> = safeApiCall {
        android.util.Log.d("MediaRepository", "refreshAllActors")
        api.refreshAllActors().data ?: throw Exception("No data")
    }

    suspend fun refreshSeriesLogo(seriesId: Long): Result<RefreshLogoResponse> = safeApiCall {
        android.util.Log.d("MediaRepository", "refreshSeriesLogo: seriesId=$seriesId")
        val data = api.refreshSeriesLogo(seriesId).data ?: throw Exception("No data")
        data.copy(logoUrl = fixUrl(data.logoUrl))
    }

    suspend fun refreshVideoLogo(videoId: Long): Result<RefreshLogoResponse> = safeApiCall {
        android.util.Log.d("MediaRepository", "refreshVideoLogo: videoId=$videoId")
        val data = api.refreshVideoLogo(videoId).data ?: throw Exception("No data")
        data.copy(logoUrl = fixUrl(data.logoUrl))
    }

    suspend fun refreshAllLogos(): Result<RefreshAllLogosResponse> = safeApiCall {
        android.util.Log.d("MediaRepository", "refreshAllLogos")
        api.refreshAllLogos().data ?: throw Exception("No data")
    }

    suspend fun refreshAllResolutions(): Result<RefreshAllResolutionsResponse> = safeApiCall {
        android.util.Log.d("MediaRepository", "refreshAllResolutions")
        api.refreshAllResolutions().data ?: throw Exception("No data")
    }

    suspend fun getSeriesLogoOptions(seriesId: Long): Result<List<LogoOption>> = safeApiCall {
        android.util.Log.d("MediaRepository", "getSeriesLogoOptions: seriesId=$seriesId")
        api.getSeriesLogoOptions(seriesId).data?.map { it.copy(url = fixUrl(it.url)) } ?: emptyList()
    }

    suspend fun setSeriesLogo(seriesId: Long, filePath: String): Result<RefreshLogoResponse> = safeApiCall {
        android.util.Log.d("MediaRepository", "setSeriesLogo: seriesId=$seriesId, filePath=$filePath")
        val data = api.setSeriesLogo(seriesId, LogoSetRequest(filePath)).data ?: throw Exception("No data")
        data.copy(logoUrl = fixUrl(data.logoUrl))
    }

    suspend fun getVideoLogoOptions(videoId: Long): Result<List<LogoOption>> = safeApiCall {
        android.util.Log.d("MediaRepository", "getVideoLogoOptions: videoId=$videoId")
        api.getVideoLogoOptions(videoId).data?.map { it.copy(url = fixUrl(it.url)) } ?: emptyList()
    }

    suspend fun setVideoLogo(videoId: Long, filePath: String): Result<RefreshLogoResponse> = safeApiCall {
        android.util.Log.d("MediaRepository", "setVideoLogo: videoId=$videoId, filePath=$filePath")
        val data = api.setVideoLogo(videoId, LogoSetRequest(filePath)).data ?: throw Exception("No data")
        data.copy(logoUrl = fixUrl(data.logoUrl))
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

    // 搜索结果/收藏中的单视频映射为列表卡片用的轻量系列条目（独立电影 id 即视频ID）
    private fun videoToSeries(video: VideoDTO): SeriesDTO = SeriesDTO(
        id = video.id,
        type = if (video.isSeries == true) "series" else "standalone",
        title = video.title,
        coverUrl = fixUrl(video.coverUrl),
        fanartUrl = fixUrl(video.fanartUrl),
        logoUrl = fixUrl(video.logoUrl),
        originalTitle = video.originalTitle,
        overview = video.overview,
        mediaType = video.mediaType,
        tmdbId = video.tmdbId,
        rating = video.rating,
        year = video.year,
        releaseDate = video.releaseDate,
        seasonNumber = video.seasonNumber,
        numberOfSeasons = null,
        totalEpisodes = null,
        status = video.status,
        isAdult = video.isAdult,
        favorite = video.favorite,
        originalFileName = null,
        episodeCount = null,
        seasons = null,
        episodes = null
    )

    suspend fun getVideoFavorites(): Result<List<SeriesDTO>> = safeApiCall {
        api.getVideoFavorites().data?.content?.map(::videoToSeries) ?: emptyList()
    }

    // 按标题/导演搜索视频
    suspend fun searchVideosByTitle(query: String, page: Int = 0, size: Int = 50): Result<List<SeriesDTO>> = safeApiCall {
        api.searchByTitle(query, page, size).data?.content?.map(::videoToSeries) ?: emptyList()
    }

    suspend fun searchVideosByDirector(query: String, page: Int = 0, size: Int = 50): Result<List<SeriesDTO>> = safeApiCall {
        api.searchByDirector(query, page, size).data?.content?.map(::videoToSeries) ?: emptyList()
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

    // 按资源库重新刮削（解绑后按库类型重新绑定，异步执行）
    suspend fun rescrapeLibrary(libraryId: Long): Result<String> = safeApiCall {
        android.util.Log.d("MediaRepository", "rescrapeLibrary: libraryId=$libraryId")
        api.rescrapeByLibrary(libraryId).data ?: throw Exception("No data")
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

    suspend fun setSeriesFavorite(seriesId: Long, status: Boolean): Result<SeriesDTO> = safeApiCall {
        api.setSeriesFavorite(seriesId, status).data ?: throw Exception("Failed to set favorite")
    }

    suspend fun getSeriesFavorites(): Result<List<SeriesDTO>> = safeApiCall {
        api.getSeriesFavorites().data?.map { it.copy(
            coverUrl = fixUrl(it.coverUrl),
            fanartUrl = fixUrl(it.fanartUrl),
            logoUrl = fixUrl(it.logoUrl)
        ) } ?: emptyList()
    }

    // ===== 媒体库 =====

    suspend fun getMediaLibraries(): Result<List<MediaLibrary>> = safeApiCall {
        api.getMediaLibraries().data ?: emptyList()
    }

    suspend fun setVideoFavorite(videoId: Long, status: Boolean): Result<VideoDTO> = safeApiCall {
        api.setVideoFavorite(videoId, status).data ?: throw Exception("Failed to set favorite")
    }

    // ===== 观看状态 =====

    // 标记已看/未看
    suspend fun setWatched(videoId: Long, completed: Boolean): Result<WatchProgressDTO> = safeApiCall {
        api.updateWatched(videoId, UpdateWatchedRequest(completed)).data
            ?: throw Exception("Failed to update watched")
    }

    // 清除观看进度（从头观看时使用）
    suspend fun deleteVideoProgress(videoId: Long): Result<Unit> = safeApiCall {
        api.deleteVideoProgress(videoId).let { response ->
            if (!response.success) throw Exception(response.message ?: "Failed to delete progress")
        }
    }

    // ===== 账号（多用户） =====

    // 注销当前 token（失败不阻塞本地登出）
    suspend fun logout(): Boolean = try {
        api.logout()
        true
    } catch (e: CancellationException) {
        throw e
    } catch (e: Exception) {
        android.util.Log.e("MediaRepository", "logout failed", e)
        false
    }

    suspend fun getCurrentUser(): Result<UserDTO> = safeApiCall {
        api.getCurrentUser().data ?: throw Exception("Failed to get current user")
    }

    suspend fun changeMyPassword(oldPassword: String, newPassword: String): Result<Unit> = safeApiCall {
        val response = api.changeMyPassword(ChangePasswordRequest(oldPassword, newPassword))
        if (!response.success) throw Exception(response.message ?: "Failed to change password")
    }

    // ===== 用户管理（管理员） =====

    suspend fun getUsers(): Result<List<UserDTO>> = safeApiCall {
        api.getUsers().data ?: emptyList()
    }

    suspend fun createUser(body: UserCreateRequest): Result<UserDTO> = safeApiCall {
        api.createUser(body).data ?: throw Exception("Failed to create user")
    }

    suspend fun updateUser(id: Long, body: UserUpdateRequest): Result<UserDTO> = safeApiCall {
        api.updateUser(id, body).data ?: throw Exception("Failed to update user")
    }

    suspend fun deleteUser(id: Long): Result<Unit> = safeApiCall {
        val response = api.deleteUser(id)
        if (!response.success) throw Exception(response.message ?: "Failed to delete user")
    }

    suspend fun resetUserPassword(id: Long, newPassword: String): Result<Unit> = safeApiCall {
        val response = api.resetUserPassword(id, ChangePasswordRequest("", newPassword))
        if (!response.success) throw Exception(response.message ?: "Failed to reset password")
    }

    suspend fun getUserLibraries(id: Long): Result<List<Long>> = safeApiCall {
        api.getUserLibraries(id).data ?: emptyList()
    }

    suspend fun setUserLibraries(id: Long, libraryIds: List<Long>): Result<List<Long>> = safeApiCall {
        api.setUserLibraries(id, UserLibraryUpdateRequest(libraryIds)).data ?: emptyList()
    }

    // ===== 系统设置 =====

    suspend fun getSettings(): Result<List<SystemSetting>> = safeApiCall {
        api.getSettings().data ?: emptyList()
    }

    suspend fun updateSetting(key: String, value: String): Result<SystemSetting> = safeApiCall {
        api.updateSetting(key, SettingUpdateRequest(value)).data ?: throw Exception("Failed to update setting")
    }

    // ===== 日志 =====

    suspend fun listLogs(): Result<List<Map<String, Any>>> = safeApiCall {
        api.listLogs().data ?: emptyList()
    }

    suspend fun downloadLog(fileName: String, sink: java.io.OutputStream): Result<Unit> = safeApiCall {
        val response = api.exportLog(fileName)
        if (!response.isSuccessful) throw Exception("Failed to download log: ${response.code()}")
        response.body()?.byteStream()?.use { input ->
            sink.use { output -> input.copyTo(output) }
        } ?: throw Exception("Empty log body")
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
