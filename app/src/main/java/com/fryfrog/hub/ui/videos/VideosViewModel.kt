package com.fryfrog.hub.ui.videos

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.SeriesDTO
import com.fryfrog.hub.data.repository.MediaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.launch

enum class SortOption(val labelResId: Int) {
    DEFAULT(com.fryfrog.hub.R.string.sort_default),
    RATING_DESC(com.fryfrog.hub.R.string.sort_rating_desc),
    RATING_ASC(com.fryfrog.hub.R.string.sort_rating_asc),
    YEAR_DESC(com.fryfrog.hub.R.string.sort_year_desc),
    YEAR_ASC(com.fryfrog.hub.R.string.sort_year_asc),
    TITLE_ASC(com.fryfrog.hub.R.string.sort_title_asc),
    TITLE_DESC(com.fryfrog.hub.R.string.sort_title_desc)
}

data class VideosUiState(
    val isLoading: Boolean = true,
    val isLoadingMore: Boolean = false,
    val series: List<SeriesDTO> = emptyList(),
    val allSeries: List<SeriesDTO> = emptyList(),
    val error: String? = null,
    val sortOption: SortOption = SortOption.DEFAULT,
    val searchQuery: String = "",
    val currentPage: Int = 0,
    val totalPages: Int = 1,
    val scrapeMessage: String? = null
)

class VideosViewModel : ViewModel() {

    private val repository = MediaRepository()

    private val _uiState = MutableStateFlow(VideosUiState())
    val uiState: StateFlow<VideosUiState> = _uiState.asStateFlow()
    private val paginationMutex = Mutex()
    private var loadJob: Job? = null
    private var loadMoreJob: Job? = null
    private var searchLoadJob: Job? = null

    init {
        loadVideos()
    }

    fun loadVideos() {
        loadJob?.cancel()
        loadMoreJob?.cancel()
        searchLoadJob?.cancel()
        loadJob = viewModelScope.launch {
            paginationMutex.withLock {
            _uiState.value = _uiState.value.copy(
                isLoading = true,
                error = null,
                currentPage = 0,
                totalPages = 1,
                allSeries = emptyList()
            )

            val result = repository.getVideoSeries(page = 0)
            val pageData = result.getOrNull()

            _uiState.value = _uiState.value.copy(
                isLoading = false,
                allSeries = pageData?.content ?: emptyList(),
                currentPage = pageData?.page ?: 0,
                totalPages = pageData?.totalPages?.coerceAtLeast(1) ?: 1,
                error = result.exceptionOrNull()?.message
            )
            applySort()
            }
        }
    }

    fun loadNextPage() {
        if (loadMoreJob?.isActive == true) return

        loadMoreJob = viewModelScope.launch {
            paginationMutex.withLock {
                val state = _uiState.value
                if (state.isLoading || state.isLoadingMore || state.currentPage >= state.totalPages - 1) return@withLock

                _uiState.value = state.copy(isLoadingMore = true, error = null)
                val result = repository.getVideoSeries(page = state.currentPage + 1)
                val pageData = result.getOrNull()

                if (pageData != null) {
                    val merged = (_uiState.value.allSeries + pageData.content)
                        .distinctBy { "${it.id}_${it.type}" }
                    _uiState.value = _uiState.value.copy(
                        isLoadingMore = false,
                        allSeries = merged,
                        currentPage = pageData.page,
                        totalPages = pageData.totalPages.coerceAtLeast(1)
                    )
                    applySort()
                } else {
                    _uiState.value = _uiState.value.copy(
                        isLoadingMore = false,
                        error = result.exceptionOrNull()?.message
                    )
                }
            }
        }
    }

    fun setSortOption(option: SortOption) {
        _uiState.value = _uiState.value.copy(sortOption = option)
        applySort()
    }

    fun setSearchQuery(query: String) {
        _uiState.value = _uiState.value.copy(searchQuery = query)
        applySortAndFilter()

        searchLoadJob?.cancel()
        if (query.isNotBlank()) {
            searchLoadJob = viewModelScope.launch {
                delay(300)
                while (true) {
                    val state = _uiState.value
                    if (state.error != null || state.currentPage >= state.totalPages - 1) break
                    loadNextPageAndWait()
                }
            }
        }
    }

    private suspend fun loadNextPageAndWait() {
        paginationMutex.withLock {
            val state = _uiState.value
            if (state.isLoading || state.currentPage >= state.totalPages - 1) return@withLock

            _uiState.value = state.copy(isLoadingMore = true, error = null)
            val result = repository.getVideoSeries(page = state.currentPage + 1)
            val pageData = result.getOrNull()

            if (pageData != null) {
                val merged = (_uiState.value.allSeries + pageData.content)
                    .distinctBy { "${it.id}_${it.type}" }
                _uiState.value = _uiState.value.copy(
                    isLoadingMore = false,
                    allSeries = merged,
                    currentPage = pageData.page,
                    totalPages = pageData.totalPages.coerceAtLeast(1)
                )
                applySortAndFilter()
            } else {
                _uiState.value = _uiState.value.copy(
                    isLoadingMore = false,
                    error = result.exceptionOrNull()?.message
                )
            }
        }
    }

    private fun applySort() {
        applySortAndFilter()
    }

    private fun applySortAndFilter() {
        val state = _uiState.value
        val query = state.searchQuery.trim()
        val filtered = if (query.isEmpty()) {
            state.allSeries
        } else {
            state.allSeries.filter {
                it.title.contains(query, ignoreCase = true) ||
                    it.originalTitle?.contains(query, ignoreCase = true) == true
            }
        }
        val sorted = when (state.sortOption) {
            SortOption.DEFAULT -> filtered
            SortOption.RATING_DESC -> filtered.sortedByDescending { it.rating ?: 0.0 }
            SortOption.RATING_ASC -> filtered.sortedBy { it.rating ?: 0.0 }
            SortOption.YEAR_DESC -> filtered.sortedByDescending { it.year ?: 0 }
            SortOption.YEAR_ASC -> filtered.sortedBy { it.year ?: 0 }
            SortOption.TITLE_ASC -> filtered.sortedBy { it.title.lowercase() }
            SortOption.TITLE_DESC -> filtered.sortedByDescending { it.title.lowercase() }
        }
        _uiState.value = _uiState.value.copy(series = sorted)
    }

    fun scrapeAdultOnly() {
        viewModelScope.launch {
            try {
                val api = com.fryfrog.hub.data.remote.ApiClient.getApi()
                val response = api.scrapeAdultOnly()
                if (response.success) {
                    val updated = response.data?.get("updated") as? Number ?: 0
                    _uiState.value = _uiState.value.copy(
                        scrapeMessage = "Updated $updated items"
                    )
                    loadVideos()
                } else {
                    _uiState.value = _uiState.value.copy(
                        error = response.message ?: "Failed to scrape adult"
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    error = e.message ?: "Unknown error"
                )
            }
        }
    }

    fun clearScrapeMessage() {
        _uiState.value = _uiState.value.copy(scrapeMessage = null)
    }
}
