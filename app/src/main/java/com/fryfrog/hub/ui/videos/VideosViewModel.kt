package com.fryfrog.hub.ui.videos

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.SeriesDTO
import com.fryfrog.hub.data.repository.MediaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class VideosUiState(
    val isLoading: Boolean = true,
    val series: List<SeriesDTO> = emptyList(),
    val error: String? = null
)

class VideosViewModel : ViewModel() {

    private val repository = MediaRepository()

    private val _uiState = MutableStateFlow(VideosUiState())
    val uiState: StateFlow<VideosUiState> = _uiState.asStateFlow()

    init {
        loadVideos()
    }

    fun loadVideos() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            val result = repository.getVideoSeries()

            _uiState.value = VideosUiState(
                isLoading = false,
                series = result.getOrElse { emptyList() },
                error = result.exceptionOrNull()?.message
            )
        }
    }
}
