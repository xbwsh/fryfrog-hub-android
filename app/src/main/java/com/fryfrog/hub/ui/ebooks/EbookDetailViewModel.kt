package com.fryfrog.hub.ui.ebooks

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.EbookSeries
import com.fryfrog.hub.data.model.MediaCharacter
import com.fryfrog.hub.data.repository.MediaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class EbookDetailUiState(
    val isLoading: Boolean = true,
    val series: EbookSeries? = null,
    val characters: List<MediaCharacter> = emptyList(),
    val error: String? = null
)

class EbookDetailViewModel(private val seriesId: Long) : ViewModel() {

    private val repository = MediaRepository()

    private val _uiState = MutableStateFlow(EbookDetailUiState())
    val uiState: StateFlow<EbookDetailUiState> = _uiState.asStateFlow()

    init {
        loadData()
    }

    private fun loadData() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            val seriesResult = repository.getEbookSeries()
            val series = seriesResult.getOrElse { emptyList() }.find { it.seriesId == seriesId }

            val characters = if (seriesId > 0) {
                repository.getEbookCharacters(seriesId).getOrElse { emptyList() }
            } else emptyList()

            _uiState.value = EbookDetailUiState(
                isLoading = false,
                series = series,
                characters = characters,
                error = if (series == null) "Series not found" else seriesResult.exceptionOrNull()?.message
            )
        }
    }
}
