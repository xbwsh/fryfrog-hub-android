package com.fryfrog.hub.ui.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.*
import com.fryfrog.hub.data.repository.MediaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class HomeUiState(
    val isLoading: Boolean = true,
    val videoSeries: List<SeriesDTO> = emptyList(),
    val musicAlbums: List<AlbumGroup> = emptyList(),
    val comicSeries: List<ComicSeries> = emptyList(),
    val ebookSeries: List<EbookSeries> = emptyList(),
    val error: String? = null
)

class HomeViewModel : ViewModel() {

    private val repository = MediaRepository()

    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    init {
        loadHomeData()
    }

    fun loadHomeData() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            val videoResult = repository.getVideoSeries()
            val musicResult = repository.getMusicByAlbum()
            val comicResult = repository.getComicSeries()
            val ebookResult = repository.getEbookSeries()

            _uiState.value = HomeUiState(
                isLoading = false,
                videoSeries = videoResult.getOrElse { emptyList() },
                musicAlbums = musicResult.getOrElse { emptyList() },
                comicSeries = comicResult.getOrElse { emptyList() },
                ebookSeries = ebookResult.getOrElse { emptyList() },
                error = videoResult.exceptionOrNull()?.message
                    ?: musicResult.exceptionOrNull()?.message
                    ?: comicResult.exceptionOrNull()?.message
                    ?: ebookResult.exceptionOrNull()?.message
            )
        }
    }
}
