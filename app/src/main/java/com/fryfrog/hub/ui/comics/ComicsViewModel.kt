package com.fryfrog.hub.ui.comics

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.ComicSeries
import com.fryfrog.hub.data.repository.MediaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ComicsUiState(
    val isLoading: Boolean = true,
    val series: List<ComicSeries> = emptyList(),
    val error: String? = null
)

class ComicsViewModel : ViewModel() {

    private val repository = MediaRepository()

    private val _uiState = MutableStateFlow(ComicsUiState())
    val uiState: StateFlow<ComicsUiState> = _uiState.asStateFlow()

    init {
        loadComics()
    }

    fun loadComics() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            val result = repository.getComicSeries()
            _uiState.value = ComicsUiState(
                isLoading = false,
                series = result.getOrElse { emptyList() },
                error = result.exceptionOrNull()?.message
            )
        }
    }
}
