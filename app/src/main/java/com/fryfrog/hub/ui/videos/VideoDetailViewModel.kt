package com.fryfrog.hub.ui.videos

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.SeriesDTO
import com.fryfrog.hub.data.model.VideoActor
import com.fryfrog.hub.data.repository.MediaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class VideoDetailUiState(
    val isLoading: Boolean = true,
    val series: SeriesDTO? = null,
    val actors: List<VideoActor> = emptyList(),
    val error: String? = null
)

class VideoDetailViewModel(
    private val seriesId: Long
) : ViewModel() {

    private val repository = MediaRepository()

    private val _uiState = MutableStateFlow(VideoDetailUiState())
    val uiState: StateFlow<VideoDetailUiState> = _uiState.asStateFlow()

    init {
        android.util.Log.d("VideoDetailVM", "Loading series ID: $seriesId")
        loadVideoDetail()
    }

    fun loadVideoDetail() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            val seriesResult = repository.getVideoSeriesDetail(seriesId)
            val actorsResult = repository.getVideoActors(seriesId)

            android.util.Log.d("VideoDetailVM", "Series result: ${seriesResult.isSuccess}, Actors result: ${actorsResult.isSuccess}")

            _uiState.value = VideoDetailUiState(
                isLoading = false,
                series = seriesResult.getOrNull(),
                actors = actorsResult.getOrElse { emptyList() },
                error = seriesResult.exceptionOrNull()?.message
                    ?: actorsResult.exceptionOrNull()?.message
            )
        }
    }
}
