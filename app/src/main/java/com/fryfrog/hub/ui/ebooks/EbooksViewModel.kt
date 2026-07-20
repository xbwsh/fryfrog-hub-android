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
    val series: List<EbookSeries> = emptyList(),
    val error: String? = null
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
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            val result = repository.getEbookSeries()
            _uiState.value = EbooksUiState(
                isLoading = false,
                series = result.getOrElse { emptyList() },
                error = result.exceptionOrNull()?.message
            )
        }
    }
}
