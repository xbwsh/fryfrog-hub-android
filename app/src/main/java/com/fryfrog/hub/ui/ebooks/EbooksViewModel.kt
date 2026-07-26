package com.fryfrog.hub.ui.ebooks

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.EbookSeries
import com.fryfrog.hub.data.repository.MediaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class EbooksUiState(
    val isLoading: Boolean = true,
    val isLoadingMore: Boolean = false,
    val series: List<EbookSeries> = emptyList(),
    val error: String? = null,
    val currentPage: Int = 0,
    val totalPages: Int = 1
)

class EbooksViewModel : ViewModel() {

    private val repository = MediaRepository()

    private val _uiState = MutableStateFlow(EbooksUiState())
    val uiState: StateFlow<EbooksUiState> = _uiState.asStateFlow()

    init {
        loadEbooks()
    }

    fun loadEbooks() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(
                isLoading = true,
                error = null,
                currentPage = 0,
                totalPages = 1,
                series = emptyList()
            )
            val result = repository.getEbookSeries(page = 0)
            val pageData = result.getOrNull()
            _uiState.value = EbooksUiState(
                isLoading = false,
                series = pageData?.content ?: emptyList(),
                currentPage = pageData?.page ?: 0,
                totalPages = pageData?.totalPages ?: 1,
                error = result.exceptionOrNull()?.message
            )
        }
    }

    fun loadNextPage() {
        val state = _uiState.value
        if (state.isLoadingMore || state.currentPage >= state.totalPages - 1) return

        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoadingMore = true)

            val nextPage = state.currentPage + 1
            val result = repository.getEbookSeries(page = nextPage)
            val pageData = result.getOrNull()

            if (pageData != null) {
                _uiState.value = _uiState.value.copy(
                    isLoadingMore = false,
                    series = _uiState.value.series + pageData.content,
                    currentPage = pageData.page,
                    totalPages = pageData.totalPages
                )
            } else {
                _uiState.value = _uiState.value.copy(
                    isLoadingMore = false,
                    error = result.exceptionOrNull()?.message
                )
            }
        }
    }
}
