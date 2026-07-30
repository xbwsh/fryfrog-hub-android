package com.fryfrog.hub.ui.videos

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.SeriesDTO
import com.fryfrog.hub.data.model.TmdbSearchResult
import com.fryfrog.hub.data.model.VideoActor
import com.fryfrog.hub.data.model.WatchProgressDTO
import com.fryfrog.hub.data.remote.ApiClient
import com.fryfrog.hub.data.repository.MediaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

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
            _uiState.value = _uiState.value.copy(isBindingTmdb = true)
            val result = repository.bindTmdb(videoId, tmdbId, mediaType)
            result.fold(
                onSuccess = {
                    _uiState.value = _uiState.value.copy(
                        isBindingTmdb = false,
                        snackbarMessage = "绑定成功，正在返回列表…",
                        tmdbSearchResults = emptyList(),
                        shouldNavigateBack = true
                    )
                },
                onFailure = { e ->
                    _uiState.value = _uiState.value.copy(
                        isBindingTmdb = false,
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
            val result = repository.refreshTmdb(videoId)
            result.fold(
                onSuccess = {
                    _uiState.value = _uiState.value.copy(
                        isRefreshingTmdb = false,
                        snackbarMessage = "刷新刮削已启动，正在返回列表…",
                        shouldNavigateBack = true
                    )
                },
                onFailure = { e ->
                    _uiState.value = _uiState.value.copy(
                        isRefreshingTmdb = false,
                        snackbarMessage = "刷新失败: ${e.message}"
                    )
                }
            )
        }
    }

    fun clearSnackbarMessage() {
        _uiState.value = _uiState.value.copy(snackbarMessage = null)
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
