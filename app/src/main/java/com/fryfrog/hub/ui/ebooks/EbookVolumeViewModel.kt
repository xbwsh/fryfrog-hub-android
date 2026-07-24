package com.fryfrog.hub.ui.ebooks

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.EbookDTO
import com.fryfrog.hub.data.remote.ApiClient
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class EbookVolumeUiState(
    val ebook: EbookDTO? = null,
    val isLoading: Boolean = true,
    val error: String? = null
)

class EbookVolumeViewModel(private val ebookId: Long) : ViewModel() {

    private val _uiState = MutableStateFlow(EbookVolumeUiState())
    val uiState: StateFlow<EbookVolumeUiState> = _uiState.asStateFlow()

    private val baseUrl get() = ApiClient.getBaseUrl()

    private fun fixUrl(url: String?): String? {
        if (url == null) return null
        if (url.startsWith("http")) return url
        return "$baseUrl$url"
    }

    init {
        loadEbook()
    }

    private fun loadEbook() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            try {
                val response = ApiClient.getApi().getEbookDetail(ebookId)
                if (response.success && response.data != null) {
                    val ebook = response.data.copy(
                        coverUrl = fixUrl(response.data.coverUrl)
                    )
                    _uiState.value = _uiState.value.copy(
                        ebook = ebook,
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

class EbookVolumeViewModelFactory(private val ebookId: Long) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        return EbookVolumeViewModel(ebookId) as T
    }
}
