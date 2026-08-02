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
    val libraryGroups: List<LibraryGroup> = emptyList(),
    val allVideos: List<SeriesDTO> = emptyList(),
    val viewMode: String = "grouped",
    val error: String? = null
)

class HomeViewModel : ViewModel() {

    private val repository = MediaRepository()

    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()
    private var isAdultContentHidden: Boolean = true

    init {
        loadHomeData()
    }

    fun setAdultContentHidden(hidden: Boolean) {
        if (isAdultContentHidden != hidden) {
            isAdultContentHidden = hidden
            loadHomeData()
        }
    }

    fun setViewMode(mode: String) {
        _uiState.value = _uiState.value.copy(viewMode = mode)
    }

    fun loadHomeData() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            val result = repository.getVideoSeriesGroupedByLibrary()

            _uiState.value = if (result.isSuccess) {
                var groups = result.getOrNull() ?: emptyList()

                // 隐私模式过滤
                if (isAdultContentHidden) {
                    groups = groups.map { group ->
                        group.copy(
                            series = group.series.filter { it.isAdult != true },
                            standaloneVideos = group.standaloneVideos.filter { it.isAdult != true }
                        )
                    }.filter { it.series.isNotEmpty() || it.standaloneVideos.isNotEmpty() }
                }

                // 展平所有视频用于总览模式
                val flatVideos = groups.flatMap { it.series + it.standaloneVideos }

                HomeUiState(
                    isLoading = false,
                    libraryGroups = groups,
                    allVideos = flatVideos,
                    viewMode = _uiState.value.viewMode
                )
            } else {
                HomeUiState(
                    isLoading = false,
                    error = result.exceptionOrNull()?.message,
                    viewMode = _uiState.value.viewMode
                )
            }
        }
    }
}
