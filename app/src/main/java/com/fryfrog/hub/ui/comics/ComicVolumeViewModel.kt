package com.fryfrog.hub.ui.comics

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.ComicDTO
import com.fryfrog.hub.data.remote.ApiClient
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ComicVolumeUiState(
    val comic: ComicDTO? = null,
    val isLoading: Boolean = true,
    val error: String? = null
)

class ComicVolumeViewModel(private val comicId: Long) : ViewModel() {

    private val _uiState = MutableStateFlow(ComicVolumeUiState())
    val uiState: StateFlow<ComicVolumeUiState> = _uiState.asStateFlow()

    private val baseUrl get() = ApiClient.getBaseUrl()

    private fun fixUrl(url: String?): String? {
        if (url == null) return null
        if (url.startsWith("http")) return url
        return "$baseUrl$url"
    }

    init {
        loadComic()
    }

    private fun loadComic() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            try {
                val response = ApiClient.getApi().getComicDetail(comicId)
                if (response.success && response.data != null) {
                    val comic = response.data.copy(
                        coverUrl = fixUrl(response.data.coverUrl)
                    )
                    _uiState.value = _uiState.value.copy(
                        comic = comic,
                        isLoading = false
                    )
                } else {
                    _uiState.value = _uiState.value.copy(
                        error = response.message ?: "加载失败",
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
}

class ComicVolumeViewModelFactory(private val comicId: Long) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        return ComicVolumeViewModel(comicId) as T
    }
}
