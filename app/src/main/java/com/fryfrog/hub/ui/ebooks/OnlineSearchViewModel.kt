package com.fryfrog.hub.ui.ebooks

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.BookSource
import com.fryfrog.hub.data.model.OnlineBookResult
import com.fryfrog.hub.data.repository.MediaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class OnlineSearchUiState(
    val isLoading: Boolean = false,
    val results: List<OnlineBookResult> = emptyList(),
    val sources: List<BookSource> = emptyList(),
    val selectedSourceId: Long? = null,
    val error: String? = null,
    val addedBookUrl: String? = null
)

class OnlineSearchViewModel : ViewModel() {

    private val repository = MediaRepository()

    private val _uiState = MutableStateFlow(OnlineSearchUiState())
    val uiState: StateFlow<OnlineSearchUiState> = _uiState.asStateFlow()

    init {
        loadSources()
    }

    private fun loadSources() {
        viewModelScope.launch {
            val result = repository.getBookSources()
            if (result.isSuccess) {
                _uiState.value = _uiState.value.copy(
                    sources = result.getOrNull() ?: emptyList()
                )
            }
        }
    }

    fun search(keyword: String) {
        if (keyword.isBlank()) return

        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(
                isLoading = true,
                error = null,
                results = emptyList()
            )
            val result = repository.searchOnlineBooks(keyword, _uiState.value.selectedSourceId)
            _uiState.value = _uiState.value.copy(
                isLoading = false,
                results = result.getOrElse { emptyList() },
                error = result.exceptionOrNull()?.message
            )
        }
    }

    fun selectSource(sourceId: Long?) {
        _uiState.value = _uiState.value.copy(selectedSourceId = sourceId)
    }

    fun addToShelf(book: OnlineBookResult) {
        viewModelScope.launch {
            val request = com.fryfrog.hub.data.model.AddToShelfRequest(
                bookUrl = book.bookUrl,
                sourceId = book.sourceId,
                bookInfo = book
            )
            val result = repository.addToShelfOnline(request)
            if (result.isSuccess) {
                _uiState.value = _uiState.value.copy(addedBookUrl = book.bookUrl)
            } else {
                _uiState.value = _uiState.value.copy(
                    error = result.exceptionOrNull()?.message
                )
            }
        }
    }

    fun clearMessages() {
        _uiState.value = _uiState.value.copy(error = null, addedBookUrl = null)
    }
}
