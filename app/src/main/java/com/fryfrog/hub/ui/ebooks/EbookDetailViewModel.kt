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
            val allSeries = seriesResult.getOrNull()?.content ?: emptyList()
            
            // 先尝试按 seriesId 查找
            var series = allSeries.find { it.seriesId == seriesId }
            
            // 如果没找到，尝试作为 bookId 查找（未刮削的电子书）
            if (series == null) {
                val book = allSeries.flatMap { it.books ?: emptyList() }.find { it.id == seriesId }
                if (book != null) {
                    // 创建一个临时的 series 对象
                    series = EbookSeries(
                        seriesId = null,
                        name = book.title,
                        coverUrl = book.coverUrl,
                        author = book.author,
                        hasCover = book.coverUrl != null,
                        volumeCount = 1,
                        seriesSummary = book.summary,
                        books = listOf(book)
                    )
                }
            }

            val characters = if (series != null) {
                val firstBookId = series.books?.firstOrNull()?.id
                if (firstBookId != null && firstBookId > 0) {
                    repository.getEbookCharacters(firstBookId).getOrElse { emptyList() }
                } else emptyList()
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
