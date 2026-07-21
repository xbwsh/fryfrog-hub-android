package com.fryfrog.hub.ui.comics

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.ComicSeries
import com.fryfrog.hub.data.model.MediaCharacter
import com.fryfrog.hub.data.repository.MediaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ComicDetailUiState(
    val isLoading: Boolean = true,
    val series: ComicSeries? = null,
    val characters: List<MediaCharacter> = emptyList(),
    val error: String? = null
)

class ComicDetailViewModel(private val seriesId: Long) : ViewModel() {

    private val repository = MediaRepository()

    private val _uiState = MutableStateFlow(ComicDetailUiState())
    val uiState: StateFlow<ComicDetailUiState> = _uiState.asStateFlow()

    init {
        loadData()
    }

    private fun loadData() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            val seriesResult = repository.getComicSeries()
            val allSeries = seriesResult.getOrElse { emptyList() }

            // 调试日志
            android.util.Log.d("ComicDetailVM", "Looking for seriesId=$seriesId")
            android.util.Log.d("ComicDetailVM", "Available series: ${allSeries.map { "id=${it.seriesId},name=${it.name}" }}")

            val series = allSeries.find { it.seriesId == seriesId }

            android.util.Log.d("ComicDetailVM", "Found series: ${series?.name}")

            val characters = if (series != null) {
                val firstComicId = series.comics?.firstOrNull()?.id
                android.util.Log.d("ComicDetailVM", "Fetching characters for firstComicId=$firstComicId (seriesId=$seriesId)")
                if (firstComicId != null && firstComicId > 0) {
                    repository.getComicCharacters(firstComicId).getOrElse { emptyList() }
                } else emptyList()
            } else emptyList()

            android.util.Log.d("ComicDetailVM", "Characters count: ${characters.size}")

            _uiState.value = ComicDetailUiState(
                isLoading = false,
                series = series,
                characters = characters,
                error = if (series == null) "Series not found" else seriesResult.exceptionOrNull()?.message
            )
        }
    }
}
