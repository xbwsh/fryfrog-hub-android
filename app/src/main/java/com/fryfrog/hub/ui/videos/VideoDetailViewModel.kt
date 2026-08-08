package com.fryfrog.hub.ui.videos

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.FrameCandidate
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

    private fun loadProgress() {
        viewModelScope.launch {
            try {
                val episodes = _uiState.value.series?.episodes ?: return@launch
                if (episodes.isEmpty()) return@launch
                val api = ApiClient.getApi()

                // Load progress for first episode to determine initial state
                val firstEp = episodes.first()
                val response = api.getVideoProgress(firstEp.id)
                if (response.success && response.data != null) {
                    _episodeProgressMap[firstEp.id] = response.data
                    _uiState.value = _uiState.value.copy(progress = response.data)
                }

                // Load progress for remaining episodes (background)
                for (ep in episodes.drop(1)) {
                    val epResponse = api.getVideoProgress(ep.id)
                    if (epResponse.success && epResponse.data != null) {
                        _episodeProgressMap[ep.id] = epResponse.data
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("VideoDetailVM", "Failed to load progress", e)
            }
        }
    }

    fun loadEpisodeProgress(episodeId: Long) {
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
                val api = ApiClient.getApi()
                val newPos = if (currentProgress.completed) 0.0 else currentProgress.positionSeconds
                val request = com.fryfrog.hub.data.model.WatchProgressRequest(position = newPos)
                val response = api.saveVideoProgress(videoId, request)
                if (response.success) {
                    _uiState.value = _uiState.value.copy(progress = response.data)
                }
            } catch (e: Exception) {
                android.util.Log.e("VideoDetailVM", "Failed to toggle watched", e)
            }
            onComplete?.invoke()
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
