package com.fryfrog.hub.ui.favorites

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.SeriesDTO
import com.fryfrog.hub.data.repository.MediaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class FavoritesUiState(
    val isLoading: Boolean = false,
    val items: List<SeriesDTO> = emptyList(),
    val error: String? = null
)

class FavoritesViewModel : ViewModel() {

    private val repository = MediaRepository()

    private val _uiState = MutableStateFlow(FavoritesUiState())
    val uiState: StateFlow<FavoritesUiState> = _uiState.asStateFlow()

    init {
        load()
    }

    fun load() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            // 系列收藏 + 视频（独立电影）收藏合并展示
            val seriesResult = repository.getSeriesFavorites()
            val videoResult = repository.getVideoFavorites()
            val merged = buildList {
                addAll(seriesResult.getOrNull().orEmpty())
                addAll(videoResult.getOrNull().orEmpty())
            }.distinctBy { it.id }
            _uiState.value = _uiState.value.copy(
                isLoading = false,
                items = merged,
                error = seriesResult.exceptionOrNull()?.message
                    ?: videoResult.exceptionOrNull()?.message
            )
        }
    }
}
