package com.fryfrog.hub.ui.videos

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.SeriesDTO
import com.fryfrog.hub.data.repository.MediaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

enum class SortOption(val labelResId: Int) {
    DEFAULT(com.fryfrog.hub.R.string.sort_default),
    RATING_DESC(com.fryfrog.hub.R.string.sort_rating_desc),
    RATING_ASC(com.fryfrog.hub.R.string.sort_rating_asc),
    YEAR_DESC(com.fryfrog.hub.R.string.sort_year_desc),
    YEAR_ASC(com.fryfrog.hub.R.string.sort_year_asc),
    TITLE_ASC(com.fryfrog.hub.R.string.sort_title_asc),
    TITLE_DESC(com.fryfrog.hub.R.string.sort_title_desc)
}

data class VideosUiState(
    val isLoading: Boolean = true,
    val series: List<SeriesDTO> = emptyList(),
    val allSeries: List<SeriesDTO> = emptyList(),
    val error: String? = null,
    val sortOption: SortOption = SortOption.DEFAULT
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
            val series = result.getOrElse { emptyList() }

            _uiState.value = _uiState.value.copy(
                isLoading = false,
                allSeries = series,
                error = result.exceptionOrNull()?.message
            )
            applySort()
        }
    }

    fun setSortOption(option: SortOption) {
        _uiState.value = _uiState.value.copy(sortOption = option)
        applySort()
    }

    private fun applySort() {
        val state = _uiState.value
        val sorted = when (state.sortOption) {
            SortOption.DEFAULT -> state.allSeries
            SortOption.RATING_DESC -> state.allSeries.sortedByDescending { it.rating ?: 0.0 }
            SortOption.RATING_ASC -> state.allSeries.sortedBy { it.rating ?: 0.0 }
            SortOption.YEAR_DESC -> state.allSeries.sortedByDescending { it.year ?: 0 }
            SortOption.YEAR_ASC -> state.allSeries.sortedBy { it.year ?: 0 }
            SortOption.TITLE_ASC -> state.allSeries.sortedBy { it.title.lowercase() }
            SortOption.TITLE_DESC -> state.allSeries.sortedByDescending { it.title.lowercase() }
        }
        _uiState.value = _uiState.value.copy(series = sorted)
    }
}
