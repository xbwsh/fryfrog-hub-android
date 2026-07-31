package com.fryfrog.hub.ui.ebooks

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.BookSource
import com.fryfrog.hub.data.repository.MediaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class BookSourcesUiState(
    val isLoading: Boolean = true,
    val sources: List<BookSource> = emptyList(),
    val error: String? = null,
    val successMessage: String? = null
)

class BookSourcesViewModel : ViewModel() {

    private val repository = MediaRepository()

    private val _uiState = MutableStateFlow(BookSourcesUiState())
    val uiState: StateFlow<BookSourcesUiState> = _uiState.asStateFlow()

    init {
        loadBookSources()
    }

    fun loadBookSources() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            val result = repository.getBookSources()
            _uiState.value = BookSourcesUiState(
                isLoading = false,
                sources = result.getOrElse { emptyList() },
                error = result.exceptionOrNull()?.message
            )
        }
    }

    fun importSources(url: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null, successMessage = null)
            val result = repository.importBookSources(url)
            if (result.isSuccess) {
                val sources = result.getOrNull() ?: emptyList()
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    sources = sources,
                    successMessage = "成功导入 ${sources.size} 个书源"
                )
            } else {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = result.exceptionOrNull()?.message
                )
            }
        }
    }

    fun toggleSource(id: Long, enabled: Boolean) {
        viewModelScope.launch {
            val result = repository.toggleBookSource(id, enabled)
            if (result.isSuccess) {
                loadBookSources()
            } else {
                _uiState.value = _uiState.value.copy(
                    error = result.exceptionOrNull()?.message
                )
            }
        }
    }

    fun deleteSource(id: Long) {
        viewModelScope.launch {
            val result = repository.deleteBookSource(id)
            if (result.isSuccess) {
                loadBookSources()
            } else {
                _uiState.value = _uiState.value.copy(
                    error = result.exceptionOrNull()?.message
                )
            }
        }
    }

    fun clearMessages() {
        _uiState.value = _uiState.value.copy(error = null, successMessage = null)
    }
}
