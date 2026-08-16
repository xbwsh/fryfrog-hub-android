package com.fryfrog.hub.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.UserDTO
import com.fryfrog.hub.data.repository.MediaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class MeUiState(
    val currentUser: UserDTO? = null,
    val isLoadingUser: Boolean = false,
    val isChangingPassword: Boolean = false,
    val snackbarResId: Int? = null,
    val snackbarArg: String? = null
)

class MeViewModel : ViewModel() {

    private val repository = MediaRepository()

    private val _uiState = MutableStateFlow(MeUiState())
    val uiState: StateFlow<MeUiState> = _uiState.asStateFlow()

    init {
        loadCurrentUser()
    }

    fun loadCurrentUser() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoadingUser = true)
            val result = repository.getCurrentUser()
            _uiState.value = _uiState.value.copy(
                currentUser = result.getOrNull(),
                isLoadingUser = false
            )
            result.exceptionOrNull()?.let { e ->
                // 获取当前用户失败不弹错误（可能是旧后端无此接口），静默降级
                android.util.Log.w("MeViewModel", "getCurrentUser failed", e)
            }
        }
    }

    fun changePassword(oldPassword: String, newPassword: String, onSuccess: () -> Unit = {}) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isChangingPassword = true)
            val result = repository.changeMyPassword(oldPassword, newPassword)
            result.fold(
                onSuccess = {
                    _uiState.value = _uiState.value.copy(
                        isChangingPassword = false,
                        snackbarResId = R.string.password_updated
                    )
                    onSuccess()
                },
                onFailure = { e ->
                    _uiState.value = _uiState.value.copy(
                        isChangingPassword = false,
                        snackbarResId = R.string.password_change_failed,
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
