package com.fryfrog.hub.ui.comics

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.ComicPageInfo
import com.fryfrog.hub.data.model.ReadingProgressRequest
import com.fryfrog.hub.data.remote.ApiClient
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ComicReaderUiState(
    val pages: List<ComicPageInfo> = emptyList(),
    val currentPage: Int = 0,
    val totalPages: Int = 0,
    val isLoading: Boolean = true,
    val error: String? = null
)

class ComicReaderViewModel(private val comicId: Long) : ViewModel() {

    private val _uiState = MutableStateFlow(ComicReaderUiState())
    val uiState: StateFlow<ComicReaderUiState> = _uiState.asStateFlow()

    private val baseUrl get() = ApiClient.getBaseUrl()

    fun getPageUrl(pageNum: Int): String {
        return "$baseUrl/api/v1/comic/$comicId/pages/$pageNum"
    }

    init {
        loadPagesAndProgress()
    }

    private fun loadPagesAndProgress() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            try {
                // 并行加载页面列表和进度
                val pagesResponse = ApiClient.getApi().getComicPages(comicId)
                val progressResponse = try {
                    ApiClient.getApi().getComicProgress(comicId)
                } catch (e: Exception) {
                    null
                }

                if (pagesResponse.success && pagesResponse.data != null) {
                    val pages = pagesResponse.data
                    val savedPage = progressResponse?.data?.currentPage ?: 0
                    // API返回的currentPage是1-based，转换为0-based索引
                    val startIndex = (savedPage - 1).coerceAtLeast(0)

                    _uiState.value = _uiState.value.copy(
                        pages = pages,
                        totalPages = pages.size,
                        currentPage = startIndex,
                        isLoading = false
                    )
                } else {
                    _uiState.value = _uiState.value.copy(
                        error = pagesResponse.message ?: "加载失败",
                        isLoading = false
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    error = e.message ?: "网络错误",
                    isLoading = false
                )
            }
        }
    }

    fun setCurrentPage(page: Int) {
        _uiState.value = _uiState.value.copy(currentPage = page)
        saveProgress(page + 1)
    }

    private fun saveProgress(currentPage: Int) {
        viewModelScope.launch {
            try {
                val totalPages = _uiState.value.totalPages
                if (totalPages > 0) {
                    ApiClient.getApi().saveComicProgress(
                        comicId,
                        ReadingProgressRequest(currentPage = currentPage, totalPages = totalPages)
                    )
                }
            } catch (e: Exception) {
                // 静默失败，不影响阅读
            }
        }
    }
}

class ComicReaderViewModelFactory(private val comicId: Long) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        return ComicReaderViewModel(comicId) as T
    }
}
