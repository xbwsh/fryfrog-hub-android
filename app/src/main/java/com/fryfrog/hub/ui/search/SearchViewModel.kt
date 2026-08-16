package com.fryfrog.hub.ui.search

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.SeriesDTO
import com.fryfrog.hub.data.repository.MediaRepository
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

private const val SEARCH_DEBOUNCE_MS = 350L

enum class SearchMode(val labelResId: Int) {
    TITLE(com.fryfrog.hub.R.string.search_by_title),
    DIRECTOR(com.fryfrog.hub.R.string.search_by_director)
}

data class SearchUiState(
    val query: String = "",
    val mode: SearchMode = SearchMode.TITLE,
    val results: List<SeriesDTO> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null
)

class SearchViewModel : ViewModel() {

    private val repository = MediaRepository()

    private val _uiState = MutableStateFlow(SearchUiState())
    val uiState: StateFlow<SearchUiState> = _uiState.asStateFlow()
    private var searchJob: Job? = null

    fun setQuery(query: String) {
        _uiState.value = _uiState.value.copy(query = query)
        searchJob?.cancel()
        searchJob = viewModelScope.launch {
            delay(SEARCH_DEBOUNCE_MS)
            performSearch()
        }
    }

    fun setMode(mode: SearchMode) {
        if (_uiState.value.mode == mode) return
        _uiState.value = _uiState.value.copy(mode = mode)
        searchJob?.cancel()
        searchJob = viewModelScope.launch {
            delay(SEARCH_DEBOUNCE_MS)
            performSearch()
        }
    }

    private suspend fun performSearch() {
        val state = _uiState.value
        val query = state.query.trim()
        if (query.isBlank()) {
            _uiState.value = _uiState.value.copy(results = emptyList(), isLoading = false, error = null)
            return
        }
        _uiState.value = _uiState.value.copy(isLoading = true, error = null)
        val result = when (state.mode) {
            SearchMode.TITLE -> repository.searchVideosByTitle(query)
            SearchMode.DIRECTOR -> repository.searchVideosByDirector(query)
        }
        result.fold(
            onSuccess = { items ->
                _uiState.value = _uiState.value.copy(
                    results = items,
                    isLoading = false
                )
            },
            onFailure = { e ->
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = e.message
                )
            }
        )
    }
}
