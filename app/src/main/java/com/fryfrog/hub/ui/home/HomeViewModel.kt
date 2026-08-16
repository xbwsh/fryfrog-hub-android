package com.fryfrog.hub.ui.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.*
import com.fryfrog.hub.data.repository.MediaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

// 首页分类筛选
object MediaFilter {
    const val ALL = "all"
    const val MOVIE = "movie"
    const val TV = "tv"
    const val OTHER = "other"

    fun matches(series: SeriesDTO, filter: String): Boolean = when (filter) {
        MOVIE -> series.mediaType == "movie"
        TV -> series.mediaType == "tv"
        OTHER -> series.mediaType != "movie" && series.mediaType != "tv"
        else -> true
    }
}

data class HomeUiState(
    val isLoading: Boolean = true,
    val libraryGroups: List<LibraryGroup> = emptyList(),
    val allVideos: List<SeriesDTO> = emptyList(),
    val viewMode: String = "grouped",
    val mediaFilter: String = MediaFilter.ALL,
    // 各分类条目数（基于隐私过滤后的全部数据，不随当前筛选变化）
    val filterCounts: Map<String, Int> = emptyMap(),
    val error: String? = null
)

class HomeViewModel : ViewModel() {

    private val repository = MediaRepository()

    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()
    private var isAdultContentHidden: Boolean = true
    // 隐私过滤后的完整数据（分类筛选在此基础上进行，避免累积过滤）
    private var rawLibraryGroups: List<LibraryGroup> = emptyList()

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

    fun setMediaFilter(filter: String) {
        if (_uiState.value.mediaFilter == filter) return
        _uiState.value = _uiState.value.copy(mediaFilter = filter)
        applyMediaFilter()
    }

    private fun applyMediaFilter() {
        val filter = _uiState.value.mediaFilter
        val groups = rawLibraryGroups.map { group ->
            group.copy(
                series = group.series.filter { MediaFilter.matches(it, filter) },
                standaloneVideos = group.standaloneVideos.filter { MediaFilter.matches(it, filter) }
            )
        }.filter { it.series.isNotEmpty() || it.standaloneVideos.isNotEmpty() }
        _uiState.value = _uiState.value.copy(
            libraryGroups = groups,
            allVideos = groups.flatMap { it.series + it.standaloneVideos }
        )
    }

    // 统计各分类条目数（全部/电影/电视剧/其他），用于首页筛选卡片展示
    private fun computeFilterCounts(groups: List<LibraryGroup>): Map<String, Int> {
        val all = groups.flatMap { it.series + it.standaloneVideos }
        return mapOf(
            MediaFilter.ALL to all.size,
            MediaFilter.MOVIE to all.count { MediaFilter.matches(it, MediaFilter.MOVIE) },
            MediaFilter.TV to all.count { MediaFilter.matches(it, MediaFilter.TV) },
            MediaFilter.OTHER to all.count { MediaFilter.matches(it, MediaFilter.OTHER) }
        )
    }

    fun loadHomeData() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            val result = repository.getVideoSeriesGroupedByLibrary()

            _uiState.value = if (result.isSuccess) {
                var groups = result.getOrNull() ?: emptyList()

                // 隐私模式过滤：isAdult 标记或包含成人内容集的系列都隐藏
                if (isAdultContentHidden) {
                    groups = groups.map { group ->
                        group.copy(
                            series = group.series.filter { it.isAdult != true && it.hasAdultEpisodes != true },
                            standaloneVideos = group.standaloneVideos.filter { it.isAdult != true }
                        )
                    }.filter { it.series.isNotEmpty() || it.standaloneVideos.isNotEmpty() }
                }

                rawLibraryGroups = groups
                val counts = computeFilterCounts(groups)
                val filter = _uiState.value.mediaFilter
                val filteredGroups = groups.map { group ->
                    group.copy(
                        series = group.series.filter { MediaFilter.matches(it, filter) },
                        standaloneVideos = group.standaloneVideos.filter { MediaFilter.matches(it, filter) }
                    )
                }.filter { it.series.isNotEmpty() || it.standaloneVideos.isNotEmpty() }

                // 展平所有视频用于总览模式
                val flatVideos = filteredGroups.flatMap { it.series + it.standaloneVideos }

                HomeUiState(
                    isLoading = false,
                    libraryGroups = filteredGroups,
                    allVideos = flatVideos,
                    viewMode = _uiState.value.viewMode,
                    mediaFilter = filter,
                    filterCounts = counts
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
