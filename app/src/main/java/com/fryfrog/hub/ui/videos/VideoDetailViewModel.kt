package com.fryfrog.hub.ui.videos

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.SeriesDTO
import com.fryfrog.hub.data.model.VideoActor
import com.fryfrog.hub.data.model.WatchProgressDTO
import com.fryfrog.hub.data.remote.ApiClient
import com.fryfrog.hub.data.repository.MediaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class VideoDetailUiState(
    val isLoading: Boolean = true,
    val series: SeriesDTO? = null,
    val actors: List<VideoActor> = emptyList(),
    val error: String? = null,
    val progress: WatchProgressDTO? = null
)

class VideoDetailViewModel(
    private val seriesId: Long,
    private val type: String? = null
) : ViewModel() {

    private val repository = MediaRepository()

    private val _uiState = MutableStateFlow(VideoDetailUiState())
    val uiState: StateFlow<VideoDetailUiState> = _uiState.asStateFlow()

    init {
        android.util.Log.d("VideoDetailVM", "Loading series ID: $seriesId type: $type")
        loadVideoDetail()
    }

    fun loadVideoDetail() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            val seriesResult = repository.getVideoSeriesDetail(seriesId, type)
            val actorsResult = repository.getVideoActors(seriesId)

            android.util.Log.d("VideoDetailVM", "Series result: ${seriesResult.isSuccess}, Actors result: ${actorsResult.isSuccess}")

            _uiState.value = VideoDetailUiState(
                isLoading = false,
                series = seriesResult.getOrNull(),
                actors = actorsResult.getOrElse { emptyList() },
                error = seriesResult.exceptionOrNull()?.message
                    ?: actorsResult.exceptionOrNull()?.message
            )

            // Load progress for first episode
            loadProgress()
        }
    }

    private fun loadProgress() {
        viewModelScope.launch {
            try {
                val firstEpisodeId = _uiState.value.series?.episodes?.firstOrNull()?.id ?: return@launch
                val api = ApiClient.getApi()
                val response = api.getVideoProgress(firstEpisodeId)
                if (response.success) {
                    _uiState.value = _uiState.value.copy(progress = response.data)
                }
            } catch (e: Exception) {
                android.util.Log.e("VideoDetailVM", "Failed to load progress", e)
            }
        }
    }
}
