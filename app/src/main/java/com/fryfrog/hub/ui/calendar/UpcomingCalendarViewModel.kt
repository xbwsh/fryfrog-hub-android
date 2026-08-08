package com.fryfrog.hub.ui.calendar

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.SeriesCalendarItem
import com.fryfrog.hub.data.repository.MediaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class UpcomingCalendarUiState(
    val isLoading: Boolean = false,
    val items: List<SeriesCalendarItem> = emptyList(),
    val error: String? = null
)

class UpcomingCalendarViewModel : ViewModel() {

    private val repository = MediaRepository()

    private val _uiState = MutableStateFlow(UpcomingCalendarUiState())
    val uiState: StateFlow<UpcomingCalendarUiState> = _uiState.asStateFlow()

    init {
        load()
    }

    fun load() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            val result = repository.getSeriesCalendar()
            result.fold(
                onSuccess = { items ->
                    _uiState.value = _uiState.value.copy(isLoading = false, items = items)
                },
                onFailure = { e ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = e.message ?: "Unknown error"
                    )
                }
            )
        }
    }
}
