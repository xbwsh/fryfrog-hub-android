package com.fryfrog.hub.ui.videos

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.FrameCandidate
import com.fryfrog.hub.data.model.LogoOption
import com.fryfrog.hub.data.model.ScrapeProgress
import com.fryfrog.hub.data.model.SeriesDTO
import com.fryfrog.hub.data.model.TmdbSearchResult
import com.fryfrog.hub.data.model.UpdateMetadataRequest
import com.fryfrog.hub.data.model.VideoActor
import com.fryfrog.hub.data.model.WatchProgressDTO
import com.fryfrog.hub.data.remote.ApiClient
import com.fryfrog.hub.data.repository.MediaRepository
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

private const val BIND_POLLING_INTERVAL_MS = 1500L
private const val BIND_POLLING_TIMEOUT_MS = 5 * 60 * 1000L
private const val BIND_COMPLETE_PAUSE_MS = 800L

data class VideoDetailUiState(
    val isLoading: Boolean = true,
    val series: SeriesDTO? = null,
    val actors: List<VideoActor> = emptyList(),
    val error: String? = null,
    val progress: WatchProgressDTO? = null,
    val tmdbSearchResults: List<TmdbSearchResult> = emptyList(),
    val isSearchingTmdb: Boolean = false,
    val isBindingTmdb: Boolean = false,
    val isUnbindingTmdb: Boolean = false,
    val isRefreshingTmdb: Boolean = false,
    val isRefreshingSeasonCovers: Boolean = false,
    val isRefreshingLogo: Boolean = false,
    val logoOptions: List<LogoOption> = emptyList(),
    val isLoadingLogoOptions: Boolean = false,
    val isSettingLogo: Boolean = false,
    val bindProgress: ScrapeProgress? = null,
    val frameCandidates: List<FrameCandidate> = emptyList(),
    val isGeneratingFrames: Boolean = false,
    val isSubmittingFrame: Boolean = false,
    val frameError: String? = null,
    val isSavingMetadata: Boolean = false,
    val snackbarMessage: String? = null,
    val shouldNavigateBack: Boolean = false
)

class VideoDetailViewModel(
    private val seriesId: Long,
    private val type: String? = null
) : ViewModel() {

    private val repository = MediaRepository()

    private val _uiState = MutableStateFlow(VideoDetailUiState())
    val uiState: StateFlow<VideoDetailUiState> = _uiState.asStateFlow()
    private var tmdbSearchJob: Job? = null

    init {
        android.util.Log.d("VideoDetailVM", "Loading series ID: $seriesId type: $type")
        loadVideoDetail()
    }

    fun loadVideoDetail() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            val seriesResult = repository.getVideoSeriesDetail(seriesId, type)

            // 演员接口期望 videos 表的主键，取第一个视频的 id
            val videoId = seriesResult.getOrNull()?.episodes?.firstOrNull()?.id
            android.util.Log.d("VideoDetailVM", "loadVideoDetail: seriesId=$seriesId, videoId=$videoId")

            val actorsResult = if (videoId != null) {
                repository.getVideoActors(videoId)
            } else {
                repository.getVideoActors(seriesId)
            }

            android.util.Log.d("VideoDetailVM", "Series result: ${seriesResult.isSuccess}, Actors result: ${actorsResult.isSuccess}")
            actorsResult.getOrNull()?.forEach { actor ->
                android.util.Log.d("VideoDetailVM", "Actor: ${actor.name}, imageUrl=${actor.imageUrl}")
            }

            _uiState.value = VideoDetailUiState(
                isLoading = false,
                series = seriesResult.getOrNull(),
                actors = actorsResult.getOrElse { emptyList() },
                error = seriesResult.exceptionOrNull()?.message
                    ?: actorsResult.exceptionOrNull()?.message
            )

            loadProgress()
        }
    }

    private val _episodeProgressMap = androidx.compose.runtime.mutableStateMapOf<Long, com.fryfrog.hub.data.model.WatchProgressDTO>()
    val episodeProgress: Map<Long, com.fryfrog.hub.data.model.WatchProgressDTO> get() = _episodeProgressMap

    /**
     * 从 SeriesDTO 中内嵌的 watchPosition / watchProgressPercent / watched 构建
     * 轻量 WatchProgressDTO，不再逐集调 N+1 getVideoProgress。
     * 仅对第一集（当前选中集）保留一次精确 getVideoProgress 调用以获取 updatedAt。
     */
    private fun buildProgressFromDto(video: com.fryfrog.hub.data.model.VideoDTO): WatchProgressDTO {
        val positionSeconds = video.watchPosition ?: 0.0
        val durationSeconds = (video.durationMinutes ?: 0) * 60.0
        val progressPercent = video.watchProgressPercent
            ?: if (durationSeconds > 0) (positionSeconds / durationSeconds * 100).coerceIn(0.0, 100.0) else 0.0
        return WatchProgressDTO(
            videoId = video.id,
            positionSeconds = positionSeconds,
            durationSeconds = durationSeconds,
            completed = video.watched ?: (progressPercent >= 95.0),
            progressPercent = progressPercent,
            updatedAt = null
        )
    }

    private fun loadProgress() {
        viewModelScope.launch {
            try {
                val episodes = _uiState.value.series?.episodes ?: return@launch
                if (episodes.isEmpty()) return@launch

                // 从 DTO 内嵌字段构建所有集的进度；已有精确进度（播放中/刚操作过）不被旧 DTO 覆盖
                for (ep in episodes) {
                    if (_episodeProgressMap[ep.id] == null) {
                        _episodeProgressMap[ep.id] = buildProgressFromDto(ep)
                    }
                }
                // 设置第一集的 UI progress（控制播放按钮文案）
                _uiState.value = _uiState.value.copy(progress = _episodeProgressMap[episodes.first().id])
            } catch (e: Exception) {
                android.util.Log.e("VideoDetailVM", "Failed to load progress", e)
            }
        }
    }

    fun loadEpisodeProgress(episodeId: Long) {
        // 先从已有映射中快速获取
        val cached = _episodeProgressMap[episodeId]
        if (cached != null) {
            _uiState.value = _uiState.value.copy(progress = cached)
        }
        // 同时从后端精确获取（更新 updatedAt 等）
        viewModelScope.launch {
            try {
                val api = ApiClient.getApi()
                val response = api.getVideoProgress(episodeId)
                if (response.success && response.data != null) {
                    _episodeProgressMap[episodeId] = response.data
                    _uiState.value = _uiState.value.copy(progress = response.data)
                }
            } catch (e: Exception) {
                android.util.Log.e("VideoDetailVM", "Failed to load episode progress", e)
            }
        }
    }

    fun searchTmdb(query: String) {
        if (query.isBlank()) return
        tmdbSearchJob?.cancel()
        tmdbSearchJob = viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isSearchingTmdb = true)
            val result = repository.searchTmdb(query)
            result.fold(
                onSuccess = { results ->
                    _uiState.value = _uiState.value.copy(
                        tmdbSearchResults = results,
                        isSearchingTmdb = false
                    )
                },
                onFailure = { e ->
                    _uiState.value = _uiState.value.copy(
                        isSearchingTmdb = false,
                        snackbarMessage = "搜索失败: ${e.message}"
                    )
                }
            )
        }
    }

    fun bindTmdb(tmdbId: Long, mediaType: String) {
        val videoId = _uiState.value.series?.episodes?.firstOrNull()?.id ?: return
        android.util.Log.d("VideoDetailVM", "bindTmdb: videoId=$videoId, tmdbId=$tmdbId, mediaType=$mediaType")
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isBindingTmdb = true, tmdbSearchResults = emptyList())
            // 立即显示占位进度条，POST 期间（含后端同步处理）用户可见进度
            showPlaceholderBindProgress(videoId)
            val result = repository.bindTmdb(videoId, tmdbId, mediaType)
            result.fold(
                onSuccess = {
                    // 后端异步执行，立即返回 started，轮询进度等待完成
                    pollBindProgress(videoId)
                },
                onFailure = { e ->
                    _uiState.value = _uiState.value.copy(
                        isBindingTmdb = false,
                        bindProgress = null,
                        snackbarMessage = "绑定失败: ${e.message}"
                    )
                }
            )
        }
    }

    fun unbindTmdb() {
        val videoId = _uiState.value.series?.episodes?.firstOrNull()?.id ?: return
        android.util.Log.d("VideoDetailVM", "unbindTmdb: videoId=$videoId, seriesId=${_uiState.value.series?.id}, tmdbId=${_uiState.value.series?.tmdbId}")
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isUnbindingTmdb = true)
            val result = repository.unbindTmdb(videoId)
            result.fold(
                onSuccess = {
                    _uiState.value = _uiState.value.copy(
                        isUnbindingTmdb = false,
                        snackbarMessage = "解绑成功，正在返回列表…",
                        shouldNavigateBack = true
                    )
                },
                onFailure = { e ->
                    _uiState.value = _uiState.value.copy(
                        isUnbindingTmdb = false,
                        snackbarMessage = "解绑失败: ${e.message}"
                    )
                }
            )
        }
    }

    fun refreshTmdb() {
        val videoId = _uiState.value.series?.episodes?.firstOrNull()?.id ?: return
        android.util.Log.d("VideoDetailVM", "refreshTmdb: videoId=$videoId, seriesId=${_uiState.value.series?.id}, tmdbId=${_uiState.value.series?.tmdbId}")
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isRefreshingTmdb = true)
            // 立即显示占位进度条
            showPlaceholderBindProgress(videoId)
            val result = repository.refreshTmdb(videoId)
            result.fold(
                onSuccess = {
                    // 后端异步执行，立即返回 started，轮询进度等待完成
                    pollBindProgress(videoId)
                },
                onFailure = { e ->
                    _uiState.value = _uiState.value.copy(
                        isRefreshingTmdb = false,
                        bindProgress = null,
                        snackbarMessage = "刷新失败: ${e.message}"
                    )
                }
            )
        }
    }

    fun refreshSeasonCovers() {
        val seriesId = _uiState.value.series?.id ?: return
        android.util.Log.d("VideoDetailVM", "refreshSeasonCovers: seriesId=$seriesId")
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isRefreshingSeasonCovers = true)
            val result = repository.refreshSeasonCovers(seriesId)
            result.fold(
                onSuccess = { data ->
                    val seasonPosters = (data["refreshedSeasonPosters"] as? Number)?.toInt() ?: 0
                    val episodeCovers = (data["refreshedEpisodeCovers"] as? Number)?.toInt() ?: 0
                    _uiState.value = _uiState.value.copy(
                        isRefreshingSeasonCovers = false,
                        snackbarMessage = "已刷新 $seasonPosters 个季海报，$episodeCovers 个集封面"
                    )
                    loadVideoDetail()
                },
                onFailure = { e ->
                    _uiState.value = _uiState.value.copy(
                        isRefreshingSeasonCovers = false,
                        snackbarMessage = "刷新季海报失败: ${e.message}"
                    )
                }
            )
        }
    }

    fun refreshLogo() {
        val series = _uiState.value.series ?: return
        val isSeries = series.mediaType == "tv"
        android.util.Log.d("VideoDetailVM", "refreshLogo: seriesId=${series.id}, isSeries=$isSeries")
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isRefreshingLogo = true)
            val result = if (isSeries) {
                repository.refreshSeriesLogo(series.id)
            } else {
                val videoId = series.episodes?.firstOrNull()?.id ?: run {
                    _uiState.value = _uiState.value.copy(
                        isRefreshingLogo = false,
                        snackbarMessage = "补全 Logo 失败: 未找到对应视频"
                    )
                    return@launch
                }
                repository.refreshVideoLogo(videoId)
            }
            result.fold(
                onSuccess = { data ->
                    _uiState.value = _uiState.value.copy(
                        isRefreshingLogo = false,
                        // downloaded 只表示本次是否下载成功，false = TMDB 无 logo 或获取失败
                        snackbarMessage = if (data.downloaded) "补全成功" else "该条目没有找到 Logo"
                    )
                },
                onFailure = { e ->
                    _uiState.value = _uiState.value.copy(
                        isRefreshingLogo = false,
                        snackbarMessage = "补全 Logo 失败: ${e.message}"
                    )
                }
            )
        }
    }

    // ===== 设置 Logo（查询选项 → 预览 → 选择 → 设置）=====

    // 语言优先级：中文 > 日文 > 英文 > 其他
    private fun languagePriority(code: String?): Int = when (code?.lowercase()) {
        "zh" -> 0
        "ja" -> 1
        "en" -> 2
        else -> 3
    }

    private val logoOptionComparator = compareBy<LogoOption>(
        { languagePriority(it.iso6391) },
        { -(it.width?.times(it.height ?: 0) ?: 0) },
        { -(it.voteCount ?: 0) }
    )

    fun loadLogoOptions() {
        val series = _uiState.value.series ?: return
        val isSeries = series.mediaType == "tv"
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoadingLogoOptions = true)
            val result = if (isSeries) {
                repository.getSeriesLogoOptions(series.id)
            } else {
                val videoId = series.episodes?.firstOrNull()?.id
                if (videoId == null) {
                    _uiState.value = _uiState.value.copy(
                        isLoadingLogoOptions = false,
                        snackbarMessage = "获取 Logo 选项失败: 未找到对应视频"
                    )
                    return@launch
                }
                repository.getVideoLogoOptions(videoId)
            }
            result.fold(
                onSuccess = { options ->
                    _uiState.value = _uiState.value.copy(
                        // 排序：中文 > 日文 > 英文 > 其他语言，再按分辨率、票数降序
                        logoOptions = options.sortedWith(logoOptionComparator),
                        isLoadingLogoOptions = false
                    )
                },
                onFailure = { e ->
                    _uiState.value = _uiState.value.copy(
                        logoOptions = emptyList(),
                        isLoadingLogoOptions = false,
                        snackbarMessage = "获取 Logo 选项失败: ${e.message}"
                    )
                }
            )
        }
    }

    fun setLogo(option: LogoOption, onSuccess: () -> Unit = {}) {
        val series = _uiState.value.series ?: return
        val isSeries = series.mediaType == "tv"
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isSettingLogo = true)
            val result = if (isSeries) {
                repository.setSeriesLogo(series.id, option.filePath)
            } else {
                val videoId = series.episodes?.firstOrNull()?.id ?: run {
                    _uiState.value = _uiState.value.copy(
                        isSettingLogo = false,
                        snackbarMessage = "设置 Logo 失败: 未找到对应视频"
                    )
                    return@launch
                }
                repository.setVideoLogo(videoId, option.filePath)
            }
            result.fold(
                onSuccess = { data ->
                    _uiState.value = _uiState.value.copy(
                        isSettingLogo = false,
                        logoOptions = emptyList(),
                        snackbarMessage = if (data.downloaded) "标志设置成功" else "设置失败，请重试"
                    )
                    // 刷新详情拿到新的 logoUrl
                    loadVideoDetail()
                    onSuccess()
                },
                onFailure = { e ->
                    _uiState.value = _uiState.value.copy(
                        isSettingLogo = false,
                        snackbarMessage = "设置 Logo 失败: ${e.message}"
                    )
                }
            )
        }
    }

    // ===== 绑定/刷新进度轮询（module: bind:{videoId}）=====

    private fun showPlaceholderBindProgress(videoId: Long) {
        _uiState.value = _uiState.value.copy(
            bindProgress = ScrapeProgress(
                module = "bind:$videoId",
                stage = "bind",
                running = true,
                total = 0,
                completed = 0,
                failed = 0,
                skipped = 0,
                pending = 0,
                percent = 0.0,
                currentItem = null,
                startedAt = null,
                updatedAt = null
            )
        )
    }

    private var bindPollingJob: Job? = null

    private fun pollBindProgress(videoId: Long) {
        bindPollingJob?.cancel()
        val startedAt = System.currentTimeMillis()
        bindPollingJob = viewModelScope.launch {
            while (true) {
                // 兜底：5 分钟未结束强制停止并返回列表
                if (System.currentTimeMillis() - startedAt > BIND_POLLING_TIMEOUT_MS) {
                    _uiState.value = _uiState.value.copy(
                        isBindingTmdb = false,
                        isRefreshingTmdb = false,
                        bindProgress = null,
                        shouldNavigateBack = true
                    )
                    break
                }
                try {
                    val api = ApiClient.getApi()
                    val progress = api.getScrapeProgress("bind:$videoId").data
                    if (progress != null) {
                        _uiState.value = _uiState.value.copy(bindProgress = progress)
                        if (!progress.running) {
                            val failed = progress.stage == "error"
                            // 完成态短暂停留，让用户看到最终进度
                            delay(BIND_COMPLETE_PAUSE_MS)
                            _uiState.value = _uiState.value.copy(
                                isBindingTmdb = false,
                                isRefreshingTmdb = false,
                                bindProgress = null,
                                snackbarMessage = if (failed) "绑定/刷新失败" else "完成，正在返回列表…",
                                shouldNavigateBack = !failed
                            )
                            break
                        }
                    }
                } catch (e: Exception) {
                    // 网络波动时继续轮询
                }
                delay(BIND_POLLING_INTERVAL_MS)
            }
        }
    }

    fun clearSnackbarMessage() {
        _uiState.value = _uiState.value.copy(snackbarMessage = null)
    }

    // ===== 收藏（剧集走系列接口，独立电影走视频接口）=====

    fun toggleFavorite() {
        val series = _uiState.value.series ?: return
        val isSeries = series.mediaType == "tv"
        val current = series.favorite ?: series.episodes?.firstOrNull()?.favorite ?: false
        val newStatus = !current
        viewModelScope.launch {
            val result = if (isSeries) {
                repository.setSeriesFavorite(series.id, newStatus)
            } else {
                val videoId = series.episodes?.firstOrNull()?.id ?: return@launch
                repository.setVideoFavorite(videoId, newStatus)
            }
            result.fold(
                onSuccess = {
                    _uiState.value = _uiState.value.copy(
                        series = _uiState.value.series?.let { s ->
                            if (isSeries) {
                                s.copy(favorite = newStatus)
                            } else {
                                s.copy(
                                    favorite = newStatus,
                                    episodes = s.episodes?.mapIndexed { index, e ->
                                        if (index == 0) e.copy(favorite = newStatus) else e
                                    }
                                )
                            }
                        },
                        snackbarMessage = if (newStatus) "已收藏" else "已取消收藏"
                    )
                },
                onFailure = { e ->
                    _uiState.value = _uiState.value.copy(
                        snackbarMessage = "操作失败: ${e.message}"
                    )
                }
            )
        }
    }

    // ===== 编辑元数据 =====

    fun updateMetadata(isSeries: Boolean, body: UpdateMetadataRequest) {
        val seriesId = _uiState.value.series?.id ?: return
        val videoId = _uiState.value.series?.episodes?.firstOrNull()?.id ?: return
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isSavingMetadata = true)
            val result = if (isSeries) {
                repository.updateSeriesMetadata(seriesId, body)
            } else {
                repository.updateVideoMetadata(videoId, body)
            }
            result.fold(
                onSuccess = {
                    _uiState.value = _uiState.value.copy(
                        isSavingMetadata = false,
                        snackbarMessage = "已保存"
                    )
                    loadVideoDetail()
                },
                onFailure = { e ->
                    _uiState.value = _uiState.value.copy(
                        isSavingMetadata = false,
                        snackbarMessage = "保存失败: ${e.message}"
                    )
                }
            )
        }
    }

    // ===== 封面候选帧 =====

    fun generateFrames(videoId: Long) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isGeneratingFrames = true, frameError = null)
            val result = repository.generateFrames(videoId)
            result.fold(
                onSuccess = { data ->
                    _uiState.value = _uiState.value.copy(
                        frameCandidates = data.candidates.orEmpty(),
                        isGeneratingFrames = false
                    )
                },
                onFailure = { e ->
                    _uiState.value = _uiState.value.copy(
                        isGeneratingFrames = false,
                        frameError = e.message ?: "Failed to generate frames"
                    )
                }
            )
        }
    }

    fun selectFrame(videoId: Long, index: Int, type: String, onSuccess: () -> Unit = {}) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isSubmittingFrame = true)
            val result = repository.selectFrame(videoId, index, type)
            result.fold(
                onSuccess = {
                    _uiState.value = _uiState.value.copy(isSubmittingFrame = false)
                    loadVideoDetail()
                    onSuccess()
                },
                onFailure = { e ->
                    _uiState.value = _uiState.value.copy(
                        isSubmittingFrame = false,
                        frameError = e.message ?: "Failed to select frame"
                    )
                }
            )
        }
    }

    fun refreshProgress() {
        loadProgress()
    }

    fun toggleWatched(onComplete: (() -> Unit)? = null) {
        val currentProgress = _uiState.value.progress ?: run { onComplete?.invoke(); return }
        viewModelScope.launch {
            try {
                val videoId = _uiState.value.series?.episodes?.firstOrNull()?.id ?: return@launch
                val newCompleted = !currentProgress.completed
                val result = repository.setWatched(videoId, newCompleted)
                result.fold(
                    onSuccess = { updatedProgress ->
                        _episodeProgressMap[videoId] = updatedProgress
                        _uiState.value = _uiState.value.copy(progress = updatedProgress)
                    },
                    onFailure = { e ->
                        android.util.Log.e("VideoDetailVM", "Failed to toggle watched", e)
                    }
                )
            } catch (e: Exception) {
                android.util.Log.e("VideoDetailVM", "Failed to toggle watched", e)
            }
            onComplete?.invoke()
        }
    }

    /**
     * 从头播放：标记未看 + 清除服务端进度，随后进入播放器（forceRestart）。
     * 失败不阻塞播放（进度清除失败仅记录日志）。
     */
    fun playFromStart(videoId: Long, onNavigate: (Long) -> Unit) {
        viewModelScope.launch {
            repository.setWatched(videoId, false)
                .onFailure { e -> android.util.Log.e("VideoDetailVM", "playFromStart: setWatched failed", e) }
            repository.deleteVideoProgress(videoId)
                .onFailure { e -> android.util.Log.e("VideoDetailVM", "playFromStart: deleteProgress failed", e) }
            // 本地立即置为未看状态，避免返回详情时被旧 DTO 值覆盖
            val fresh = WatchProgressDTO(videoId, 0.0, 0.0, completed = false, progressPercent = 0.0, updatedAt = null)
            _episodeProgressMap[videoId] = fresh
            _uiState.value = _uiState.value.copy(progress = fresh)
            onNavigate(videoId)
        }
    }

    fun clearNavigateBack() {
        _uiState.value = _uiState.value.copy(shouldNavigateBack = false)
    }

    fun clearTmdbSearchResults() {
        tmdbSearchJob?.cancel()
        _uiState.value = _uiState.value.copy(
            tmdbSearchResults = emptyList(),
            isSearchingTmdb = false
        )
    }
}
