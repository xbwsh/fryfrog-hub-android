package com.fryfrog.hub.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.SystemSetting
import com.fryfrog.hub.data.repository.MediaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class SystemSettingsUiState(
    val settings: List<SystemSetting> = emptyList(),
    val isLoading: Boolean = false,
    val snackbarResId: Int? = null,
    val snackbarArg: String? = null
)

class SystemSettingsViewModel : ViewModel() {

    private val repository = MediaRepository()

    private val _uiState = MutableStateFlow(SystemSettingsUiState())
    val uiState: StateFlow<SystemSettingsUiState> = _uiState.asStateFlow()

    init {
        load()
    }

    fun load() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            val result = repository.getSettings()
            _uiState.value = _uiState.value.copy(
                settings = result.getOrNull().orEmpty(),
                isLoading = false
            )
            result.exceptionOrNull()?.let { e ->
                _uiState.value = _uiState.value.copy(
                    snackbarResId = R.string.load_failed,
                    snackbarArg = e.message
                )
            }
        }
    }

    fun updateSetting(key: String, value: String, onSuccess: () -> Unit = {}) {
        viewModelScope.launch {
            val result = repository.updateSetting(key, value)
            result.fold(
                onSuccess = {
                    _uiState.value = _uiState.value.copy(snackbarResId = R.string.setting_saved)
                    load()
                    onSuccess()
                },
                onFailure = { e ->
                    _uiState.value = _uiState.value.copy(
                        snackbarResId = R.string.save_failed,
                        snackbarArg = e.message
                    )
                }
            )
        }
    }

    fun clearSnackbar() {
        _uiState.value = _uiState.value.copy(snackbarResId = null, snackbarArg = null)
    }
}
