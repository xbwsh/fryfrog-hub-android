package com.fryfrog.hub.ui.ebooks

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.EbookChapterInfo
import com.fryfrog.hub.data.model.ReadingProgressRequest
import com.fryfrog.hub.data.model.UnifiedEbookChapterInfo
import com.fryfrog.hub.data.remote.ApiClient
import com.fryfrog.hub.data.repository.MediaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class EbookReaderUiState(
    val chapters: List<EbookChapterInfo> = emptyList(),
    val onlineChapters: List<UnifiedEbookChapterInfo> = emptyList(),
    val currentChapterIndex: Int = 0,
    val currentContent: String = "",
    val isLoading: Boolean = true,
    val isOnline: Boolean = false,
    val error: String? = null
)

class EbookReaderViewModel(
    private val ebookId: Long,
    private val isOnline: Boolean = false
) : ViewModel() {

    private val repository = MediaRepository()
    private val _uiState = MutableStateFlow(EbookReaderUiState())
    val uiState: StateFlow<EbookReaderUiState> = _uiState.asStateFlow()

    init {
        loadChaptersAndProgress()
    }

    private fun loadChaptersAndProgress() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null, isOnline = isOnline)
            try {
                if (isOnline) {
                    // 加载在线章节
                    val onlineChaptersResult = repository.getOnlineChapters(ebookId)
                    val onlineChapters = onlineChaptersResult.getOrElse { emptyList() }

                    if (onlineChapters.isNotEmpty()) {
                        _uiState.value = _uiState.value.copy(
                            onlineChapters = onlineChapters,
                            isLoading = false
                        )
                        // 加载第一章
                        loadOnlineChapter(0)
                    } else {
                        _uiState.value = _uiState.value.copy(
                            error = "没有找到章节",
                            isLoading = false
                        )
                    }
                } else {
                    // 加载本地章节
                    val chaptersResponse = ApiClient.getApi().getEbookChapters(ebookId)
                    val progressResponse = try {
                        ApiClient.getApi().getEbookProgress(ebookId)
                    } catch (e: Exception) {
                        null
                    }

                    if (chaptersResponse.success && chaptersResponse.data != null) {
                        val chapters = chaptersResponse.data
                        val savedChapter = progressResponse?.data?.currentPage ?: 0
                        val startIndex = (savedChapter - 1).coerceAtLeast(0)

                        _uiState.value = _uiState.value.copy(
                            chapters = chapters,
                            isLoading = false
                        )

                        val chapterToLoad = if (startIndex > 0 && startIndex < chapters.size) {
                            startIndex
                        } else {
                            0
                        }
                        loadChapter(chapterToLoad)
                    } else {
                        _uiState.value = _uiState.value.copy(
                            error = chaptersResponse.message ?: "加载失败",
                            isLoading = false
                        )
                    }
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    error = e.message ?: "网络错误",
                    isLoading = false
                )
            }
        }
    }

    fun loadChapter(index: Int) {
        if (isOnline) {
            loadOnlineChapter(index)
            return
        }

        if (index < 0 || index >= _uiState.value.chapters.size) return

        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            try {
                val chapterNum = _uiState.value.chapters[index].chapterNum
                val response = ApiClient.getApi().getEbookContent(ebookId, chapterNum)
                if (response.isSuccessful) {
                    val content = response.body()?.string() ?: ""
                    _uiState.value = _uiState.value.copy(
                        currentChapterIndex = index,
                        currentContent = content,
                        isLoading = false
                    )
                    saveProgress(index + 1)
                } else {
                    _uiState.value = _uiState.value.copy(
                        error = "加载失败: ${response.code()}",
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

    private fun loadOnlineChapter(index: Int) {
        val onlineChapters = _uiState.value.onlineChapters
        if (index < 0 || index >= onlineChapters.size) return

        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            try {
                val chapterUrl = onlineChapters[index].chapterUrl ?: throw Exception("章节URL为空")
                val response = ApiClient.getApi().readOnlineChapter(ebookId, chapterUrl)
                if (response.isSuccessful) {
                    val content = response.body()?.string() ?: ""
                    _uiState.value = _uiState.value.copy(
                        currentChapterIndex = index,
                        currentContent = content,
                        isLoading = false
                    )
                } else {
                    _uiState.value = _uiState.value.copy(
                        error = "加载失败: ${response.code()}",
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

    private fun saveProgress(chapterNum: Int) {
        viewModelScope.launch {
            try {
                val totalChapters = _uiState.value.chapters.size
                if (totalChapters > 0) {
                    ApiClient.getApi().saveEbookProgress(
                        ebookId,
                        ReadingProgressRequest(currentPage = chapterNum, totalPages = totalChapters)
                    )
                }
            } catch (e: Exception) {
                // 静默失败，不影响阅读
            }
        }
    }
}

class EbookReaderViewModelFactory(
    private val ebookId: Long,
    private val isOnline: Boolean = false
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        return EbookReaderViewModel(ebookId, isOnline) as T
    }
}
